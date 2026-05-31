import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:pocketmind/api/api_constants.dart';
import 'package:pocketmind/api/asset_api_service.dart';
import 'package:pocketmind/api/note_api_service.dart';
import 'package:pocketmind/api/models/note_metadata.dart';
import 'package:pocketmind/core/constants.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/model/note_asset.dart';
import 'package:pocketmind/model/scrape_attempt.dart';
import 'package:pocketmind/service/metadata_manager.dart';
import 'package:pocketmind/service/note_service.dart';
import 'package:pocketmind/service/notification_service.dart';
import 'package:pocketmind/sync/process_id.dart';
import 'package:pocketmind/sync/resource_status_state_machine.dart';
import 'package:pocketmind/sync/scrape_attempt_state.dart';
import 'package:pocketmind/util/image_storage_helper.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// 资源抓取调度器 —— 端侧 PENDING 笔记的唯一抓取入口。
///
/// 设计与并发安全分析详见
/// `docs/architecture/mobile/resource-fetch-pipeline.md`。
///
/// 关键约定（任何修改请先回去更新文档）：
///   - 领域 [Note.resourceStatus] 是派生字段，仅由本类的 finalize 阶段写入；
///   - 执行细节（lease / 重试计数 / 历史）落在 [ScrapeAttempt] 表；
///   - claim/finalize 全部在 Isar `writeTxn` 内 CAS，跨 isolate 安全；
///   - "慢 worker"由 finalize 时的 `claimedBy` 校验拦截。
class ResourceFetchScheduler {
  static const String _tag = 'ResourceFetchScheduler';

  final Isar _isar;
  final NoteService _noteService;
  final MetadataManager _metadataManager;
  final NoteApiService? _noteApiService;
  final AssetApiService? _assetApiService;
  final NotificationService? _notificationService;
  final SharedPreferences? _prefs;

  Future<void>? _inFlight;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  ResourceFetchScheduler({
    required Isar isar,
    required NoteService noteService,
    required MetadataManager metadataManager,
    NoteApiService? noteApiService,
    AssetApiService? assetApiService,
    NotificationService? notificationService,
    SharedPreferences? prefs,
  }) : _isar = isar,
       _noteService = noteService,
       _metadataManager = metadataManager,
       _noteApiService = noteApiService,
       _assetApiService = assetApiService,
       _notificationService = notificationService,
       _prefs = prefs;

  // ─────────────────────────── 生命周期 ───────────────────────────

  /// 主 App 显式调用一次：订阅网络恢复事件 + 启动时立即扫描一次。
  ///
  /// **不要**从 Workmanager 后台 isolate 调用（dispatcher 应该只调
  /// `runNow`）。在后台 isolate 里多调一发 unawaited(runNow()) 会和
  /// dispatcher 自己 `await runNow()` 的那发互相抢锁，导致 dispatcher
  /// 假装等了一下就返回 → Android 杀 isolate → 真正的扫描被半路砍断。
  void start() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (hasNetwork) {
        PMlog.d(_tag, '网络恢复，触发扫描');
        unawaited(runNow());
      }
    });
    unawaited(runNow());
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  // ─────────────────────────── 入口 ───────────────────────────

  /// 触发一轮扫描；幂等，重复调用安全。
  ///
  /// 已有扫描在跑时**合流到同一 Future**——所有调用方都会等到那一轮跑完，
  /// 而不是静默跳过。这样 Workmanager 的 `await runNow()` 不会假等，
  /// dispatcher 不会提前返回，isolate 不会被 Android 提前杀。
  Future<void> runNow({String? userQuestion}) {
    if (_inFlight != null) {
      PMlog.d(_tag, '复用进行中的扫描');
      return _inFlight!;
    }
    PMlog.d(_tag, '触发扫描 (userQuestion=${userQuestion != null})');
    final f = _runOnce(userQuestion: userQuestion);
    _inFlight = f.whenComplete(() => _inFlight = null);
    return _inFlight!;
  }

  Future<void> _runOnce({String? userQuestion}) async {
    try {
      // 入口先把上一次跑挂了的 AI 提交补一波，best-effort，与 scrape 重试
      // 计数完全无关；后端长期不可用时它会无限重试但永远不上 3 次失败通知。
      await _drainPendingAiSubmissions();

      // 启动扫描前先把所有"PENDING 但还没作业"的 note 补一条 queued，
      // 处理"老 note 没经过新流程入队"或"作业被异常清空"的兜底场景。
      final orphanCount = await enqueueOrphanedPendingNotes();
      if (orphanCount > 0) {
        PMlog.d(_tag, 'orphan 兜底入队 $orphanCount 条 PENDING note');
      }

      var processed = 0;
      while (true) {
        final claimed = await claimNext();
        if (claimed == null) {
          PMlog.d(_tag, '本轮无可领取的作业，扫描结束 (processed=$processed)');
          break;
        }
        PMlog.d(_tag, '领取作业 attemptId=$claimed，开始处理');
        await _process(claimed, userQuestion: userQuestion);
        processed++;
      }
    } catch (e, st) {
      PMlog.e(_tag, '扫描循环异常: $e\n$st');
      rethrow;
    }
  }

  /// 给指定 noteUuid 入队一条 ScrapeAttempt。
  ///
  /// 幂等：
  ///   - Note 不存在 / 已删 / 已 CRAWLED 时不入队；
  ///   - 已存在 queued 或 running 作业时不重复入队。
  ///
  /// 在分享落地后立即调用，让作业先于 Workmanager 任务存在；后台 Worker
  /// 起来扫表也能直接捡到。
  Future<void> enqueueIfAbsent(String noteUuid) async {
    await _isar.writeTxn(() async {
      await _enqueueIfAbsentInTxn(noteUuid);
    });
  }

  /// 用户从通知 / UI 显式请求重试一组 noteUuid。
  ///
  /// 把对应 Note 经状态机 `userRequestedRetry` 复活回 PENDING，并入队
  /// 一条新的 ScrapeAttempt。CRAWLED 终态的 note 会被状态机拒绝。
  Future<void> retryNotes(List<String> noteUuids) async {
    if (noteUuids.isEmpty) return;
    await _isar.writeTxn(() async {
      for (final uuid in noteUuids) {
        final note = await _isar.notes.where().uuidEqualTo(uuid).findFirst();
        if (note == null || note.isDeleted) continue;
        if (note.resourceStatus == AppConstants.resourceStatusCrawled) continue;

        final next = ResourceStatusStateMachine.reduce(
          current: note.resourceStatus,
          event: ResourceStatusEvent.userRequestedRetry,
        );
        if (next != null && next != note.resourceStatus) {
          note.resourceStatus = next;
          await _isar.notes.put(note);
        }
        await _enqueueIfAbsentInTxn(uuid);
      }
    });
  }

  /// 用户从通知"忽略"按钮，把一组 note 直接置 FAILED。
  ///
  /// 同时取消尚未结束的对应作业。
  Future<void> dismissNotes(List<String> noteUuids) async {
    if (noteUuids.isEmpty) return;
    await _isar.writeTxn(() async {
      for (final uuid in noteUuids) {
        final note = await _isar.notes.where().uuidEqualTo(uuid).findFirst();
        if (note == null) continue;
        // 取消对应活跃作业
        final live = await _isar.scrapeAttempts
            .filter()
            .noteUuidEqualTo(uuid)
            .anyOf(
              ScrapeAttemptState.live,
              (q, s) => q.stateEqualTo(s),
            )
            .findAll();
        final now = DateTime.now();
        for (final att in live) {
          att.state = AppConstants.scrapeAttemptStateCancelled;
          att.errorCode = AppConstants.scrapeErrorCancelled;
          att.finishedAt = now;
          await _isar.scrapeAttempts.put(att);
        }
        // Note 推进到 FAILED 终态（CRAWLED 不会被改）
        final next = ResourceStatusStateMachine.reduce(
          current: note.resourceStatus,
          event: ResourceStatusEvent.attemptTerminallyFailed,
        );
        if (next != null && next != note.resourceStatus) {
          note.resourceStatus = next;
          await _isar.notes.put(note);
        }
      }
    });
  }

  // ─────────────────────────── 内部 ───────────────────────────

  /// 在 [_isar.writeTxn] 内执行 enqueue 去重（外层调用方负责包事务）。
  ///
  /// [enqueuedAt] 可选，缺省 = now。软失败重入队时传 `now + backoff` 让
  /// claimNext 在退避时间内不会捡到这条新作业。
  Future<void> _enqueueIfAbsentInTxn(
    String noteUuid, {
    DateTime? enqueuedAt,
  }) async {
    final note = await _isar.notes.where().uuidEqualTo(noteUuid).findFirst();
    if (note == null || note.isDeleted) return;
    if (note.resourceStatus == AppConstants.resourceStatusCrawled) return;

    final exists = await _isar.scrapeAttempts
        .filter()
        .noteUuidEqualTo(noteUuid)
        .anyOf(
          ScrapeAttemptState.live,
          (q, s) => q.stateEqualTo(s),
        )
        .findFirst();
    if (exists != null) return;

    final attempts = await _isar.scrapeAttempts
        .filter()
        .noteUuidEqualTo(noteUuid)
        .findAll();
    final nextNumber =
        attempts.fold<int>(0, (m, a) => a.attemptNumber > m ? a.attemptNumber : m) +
            1;

    await _isar.scrapeAttempts.put(
      ScrapeAttempt()
        ..noteUuid = noteUuid
        ..state = AppConstants.scrapeAttemptStateQueued
        ..attemptNumber = nextNumber
        ..enqueuedAt = enqueuedAt ?? DateTime.now(),
    );
  }

  /// 启动一轮前的兜底：把所有 PENDING 但没有活跃作业的 note 补一条 queued。
  ///
  /// 返回本次实际**新增**的作业条数（已经有活跃作业的会跳过）。
  @visibleForTesting
  Future<int> enqueueOrphanedPendingNotes() async {
    final pendingNotes = await _isar.notes
        .filter()
        .resourceStatusEqualTo(AppConstants.resourceStatusPending)
        .isDeletedEqualTo(false)
        .urlIsNotNull()
        .findAll();
    if (pendingNotes.isEmpty) return 0;

    var inserted = 0;
    await _isar.writeTxn(() async {
      for (final note in pendingNotes) {
        final url = note.url;
        if (url == null || url.isEmpty) continue;
        final uuid = note.uuid;
        if (uuid == null) continue;
        final before = await _isar.scrapeAttempts
            .filter()
            .noteUuidEqualTo(uuid)
            .anyOf(
              ScrapeAttemptState.live,
              (q, s) => q.stateEqualTo(s),
            )
            .count();
        await _enqueueIfAbsentInTxn(uuid);
        final after = await _isar.scrapeAttempts
            .filter()
            .noteUuidEqualTo(uuid)
            .anyOf(
              ScrapeAttemptState.live,
              (q, s) => q.stateEqualTo(s),
            )
            .count();
        if (after > before) inserted++;
      }
    });
    return inserted;
  }

  /// CAS 领走下一条作业；返回被领走的 attemptId（无可领时返回 null）。
  ///
  /// 候选集 = queued ∪ (running 且 claimedAt < now - lease)。
  /// 悬挂 running 行被领走时，会同步留下一条 errorCode='crashed' 的历史
  /// 记录作为前一次执行的"墓志铭"，再把当前行升为 attemptNumber+1 的新执行。
  @visibleForTesting
  Future<int?> claimNext() async {
    return _isar.writeTxn(() async {
      final now = DateTime.now();
      final leaseDeadline = now.subtract(AppConstants.scrapeLease);

      // Isar 不支持纯 OR + filter 的高效复合，分两次查询取最早入队那条。
      // queued 候选只取 enqueuedAt <= now 的（排除退避中的软失败重入队）。
      final queuedRow = await _isar.scrapeAttempts
          .filter()
          .stateEqualTo(AppConstants.scrapeAttemptStateQueued)
          .enqueuedAtLessThan(now, include: true)
          .sortByEnqueuedAt()
          .findFirst();
      final stuckRow = await _isar.scrapeAttempts
          .filter()
          .stateEqualTo(AppConstants.scrapeAttemptStateRunning)
          .claimedAtLessThan(leaseDeadline)
          .sortByEnqueuedAt()
          .findFirst();

      final ScrapeAttempt? row = _earliestOf(queuedRow, stuckRow);
      if (row == null) return null;

      if (row.state == AppConstants.scrapeAttemptStateRunning) {
        // 立墓志铭：先复制一条 failed=crashed 历史
        await _isar.scrapeAttempts.put(
          ScrapeAttempt()
            ..noteUuid = row.noteUuid
            ..state = AppConstants.scrapeAttemptStateFailed
            ..attemptNumber = row.attemptNumber
            ..enqueuedAt = row.enqueuedAt
            ..claimedAt = row.claimedAt
            ..claimedBy = row.claimedBy
            ..finishedAt = now
            ..errorCode = AppConstants.scrapeErrorCrashed
            ..errorMessage = 'lease 过期，前一个 worker 推断为崩溃',
        );
        // 当前行升级为新一次尝试
        row.attemptNumber += 1;
      }

      row.state = AppConstants.scrapeAttemptStateRunning;
      row.claimedAt = now;
      row.claimedBy = ProcessId.current;
      row.finishedAt = null;
      row.errorCode = null;
      row.errorMessage = null;
      await _isar.scrapeAttempts.put(row);
      return row.id;
    });
  }

  ScrapeAttempt? _earliestOf(ScrapeAttempt? a, ScrapeAttempt? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.enqueuedAt.isBefore(b.enqueuedAt) ? a : b;
  }

  /// 处理一条作业的完整流水线。
  ///
  /// 三段拆分：
  ///   - **Phase 1（必须本地成功）**：抓 metadata。失败 → scrape 失败，
  ///     按 attemptNumber 与退避重新入队 / 落终态。
  ///   - **Phase 2（best-effort 后端动作）**：图片上传 + AI 分析提交。
  ///     失败**不影响 scrape 成功语义**，本地预览已经可用；只把 noteUuid
  ///     入 `keyPendingAiSubmission` 列表，下次 runNow 入口自动 drain。
  ///   - **Phase 3（finalize）**：写 attempt 终态 succeeded + Note → CRAWLED。
  Future<void> _process(int attemptId, {String? userQuestion}) async {
    final attempt = await _isar.scrapeAttempts.get(attemptId);
    if (attempt == null) return;
    final note = await _isar.notes
        .where()
        .uuidEqualTo(attempt.noteUuid)
        .findFirst();

    if (note == null || note.isDeleted) {
      await finalize(
        attemptId,
        state: AppConstants.scrapeAttemptStateCancelled,
        errorCode: AppConstants.scrapeErrorCancelled,
      );
      return;
    }

    final url = note.url;
    if (url == null || url.isEmpty) {
      await finalize(
        attemptId,
        state: AppConstants.scrapeAttemptStateCancelled,
        errorCode: AppConstants.scrapeErrorCancelled,
        errorMessage: 'note 没有可抓取的 url',
      );
      return;
    }

    // ─────── Phase 1：本地 metadata（必须成功） ───────
    final NoteMetadata? meta;
    try {
      final metaResults = await _metadataManager.fetchAndProcessMetadata([url]);
      meta = metaResults[url];
      final fetchedPreview = meta?.previewContent ?? meta?.previewDescription;

      if (meta != null) {
        note.previewTitle ??= meta.title;
        if (note.previewContent == null &&
            fetchedPreview != null &&
            fetchedPreview.isNotEmpty) {
          note.previewContent = fetchedPreview;
        }
        if (note.previewImageUrl == null && meta.imageUrls.isNotEmpty) {
          note.previewImageUrl = meta.imageUrls.first;
        }
        note.previewDescription ??= meta.previewDescription;
      }
    } catch (e, st) {
      PMlog.e(_tag, 'Phase 1 metadata 抓取失败: url=$url, e=$e\n$st');
      await _handleScrapeFailure(attempt, note, url, e);
      return;
    }

    // ─────── Phase 2：后端动作（best-effort，不影响 scrape 状态） ───────
    final isPlatformScraper = meta?.source == MetadataSource.platformScraper;

    if (isPlatformScraper && meta != null && meta.imageUrls.isNotEmpty) {
      try {
        await ImageStorageHelper().init();
        await _uploadImagesAndPersistAssets(note, meta.imageUrls);
      } catch (e, st) {
        // 单图失败已被 _uploadImagesAndPersistAssets 内部吞掉，这里只兜
        // 真正抛上来的异常（极少）。本地资产仍然保留，后端缺图下次再补。
        PMlog.w(_tag, 'Phase 2 图片上传整体异常 (吞掉): $e\n$st');
      }
    }

    if (_noteApiService != null) {
      try {
        await _noteApiService.submitAnalysis(
          uuid: note.uuid!,
          url: url,
          previewTitle: note.previewTitle,
          previewContent: _nonEmptyText(note.previewContent),
          userQuestion: userQuestion,
        );
        await _enqueueAiAnalysis(note.uuid!);
      } catch (e, st) {
        PMlog.w(
          _tag,
          'Phase 2 AI 提交失败 (本地爬取仍记成功，下次 runNow 重试): '
          'noteUuid=${note.uuid}, e=$e\n$st',
        );
        await _markPendingAiSubmission(note.uuid!);
      }
    }

    // ─────── Phase 3：持久化 + finalize → CRAWLED ───────
    await _noteService.persistDerivedNoteForSync(note);

    final accepted = await finalize(
      attemptId,
      state: AppConstants.scrapeAttemptStateSucceeded,
    );
    if (accepted) {
      PMlog.d(_tag, '抓取成功: ${note.uuid}');
    }
  }

  /// Phase 1 失败统一收口：CAS finalize + 按退避重入队 / 终态通知。
  Future<void> _handleScrapeFailure(
    ScrapeAttempt attempt,
    Note note,
    String url,
    Object error,
  ) async {
    final terminal = attempt.attemptNumber >= AppConstants.maxScrapeAttempts;
    final errorCode = _classifyError(error);

    final accepted = await finalize(
      attempt.id!,
      state: AppConstants.scrapeAttemptStateFailed,
      errorCode: errorCode,
      errorMessage: error.toString(),
      terminal: terminal,
    );

    // 慢 worker 已被收编时不再补 queued / 通知
    if (!accepted) return;

    if (!terminal) {
      // 取退避：attemptNumber=1 失败时下一发是 attempt 2，使用 schedule[0]
      // attemptNumber=2 失败时下一发是 attempt 3，使用 schedule[1]
      final idx = attempt.attemptNumber - 1;
      final backoff = idx >= 0 && idx < AppConstants.scrapeBackoffSchedule.length
          ? AppConstants.scrapeBackoffSchedule[idx]
          : Duration.zero;
      final nextEnqueueAt = DateTime.now().add(backoff);

      await _isar.writeTxn(() async {
        await _enqueueIfAbsentInTxn(note.uuid!, enqueuedAt: nextEnqueueAt);
      });
      PMlog.w(
        _tag,
        '软失败,${backoff.inSeconds}s 后重试: $url '
        '(attempt=${attempt.attemptNumber}, backoff=${backoff.inMinutes}min)',
      );
    } else {
      PMlog.w(_tag, '终态失败: $url');
      await _notifyTerminalFailure(noteUuid: note.uuid!, url: url);
    }
  }

  /// CAS 写回 finalize。返回 true 表示写入被采纳；false 表示已被另一个
  /// worker 接管（claimedBy 不一致或 state 不再是 running），结果丢弃。
  ///
  /// [terminal] 仅在 [state]=='failed' 时有意义：true → Note → FAILED；
  /// false → 仅写 attempt，Note 继续保持 PENDING（外层会补一条 queued）。
  @visibleForTesting
  Future<bool> finalize(
    int attemptId, {
    required String state,
    String? errorCode,
    String? errorMessage,
    bool terminal = false,
  }) async {
    return _isar.writeTxn(() async {
      final row = await _isar.scrapeAttempts.get(attemptId);
      if (row == null) return false;
      // running 是合法前置；其他状态意味着我已被收编 / 已结束
      if (row.state != AppConstants.scrapeAttemptStateRunning) return false;
      if (row.claimedBy != ProcessId.current) return false;

      row.state = state;
      row.errorCode = errorCode;
      row.errorMessage = errorMessage;
      row.finishedAt = DateTime.now();
      await _isar.scrapeAttempts.put(row);

      // 同步推进 Note.resourceStatus
      final note = await _isar.notes
          .where()
          .uuidEqualTo(row.noteUuid)
          .findFirst();
      if (note == null) return true;
      if (note.resourceStatus == AppConstants.resourceStatusCrawled) return true;

      ResourceStatusEvent? event;
      if (state == AppConstants.scrapeAttemptStateSucceeded) {
        event = ResourceStatusEvent.attemptSucceeded;
      } else if (state == AppConstants.scrapeAttemptStateFailed && terminal) {
        event = ResourceStatusEvent.attemptTerminallyFailed;
      }
      if (event != null) {
        final next = ResourceStatusStateMachine.reduce(
          current: note.resourceStatus,
          event: event,
        );
        if (next != null && next != note.resourceStatus) {
          note.resourceStatus = next;
          await _isar.notes.put(note);
        }
      }
      return true;
    });
  }

  String _classifyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('cookie')) return AppConstants.scrapeErrorCookieExpired;
    if (msg.contains('socket') ||
        msg.contains('timeout') ||
        msg.contains('network') ||
        msg.contains('connection')) {
      return AppConstants.scrapeErrorNetwork;
    }
    if (msg.contains('parse') || msg.contains('format')) {
      return AppConstants.scrapeErrorParse;
    }
    if (msg.contains('quota') || msg.contains('rate')) {
      return AppConstants.scrapeErrorQuota;
    }
    return AppConstants.scrapeErrorUnknown;
  }

  // ─────────────────────────── 图片 / AI / 通知 ───────────────────────────

  Future<void> _uploadImagesAndPersistAssets(
    Note note,
    List<String> relativePaths,
  ) async {
    if (_assetApiService == null) {
      PMlog.d(_tag, '未注入 AssetApiService,跳过图片上传');
      return;
    }
    int sortOrder = 0;
    for (final relativePath in relativePaths) {
      try {
        final file = ImageStorageHelper().getFileByRelativePath(relativePath);
        if (!await file.exists()) continue;
        try {
          final res = await _assetApiService.uploadImage(
            file,
            noteUuid: note.uuid!,
            sortOrder: sortOrder,
          );
          await _upsertImageNoteAsset(
            noteUuid: note.uuid!,
            relativePath: relativePath,
            sortOrder: sortOrder,
            fileSize: res.size,
            mime: res.mime,
            serverAssetUuid: res.uuid,
            serverUrl: '${ApiConstants.assetsImages}/${res.uuid}',
            metadataJson: jsonEncode({
              'width': res.width,
              'height': res.height,
            }),
          );
        } catch (e) {
          final fileSize = await file.length();
          await _upsertImageNoteAsset(
            noteUuid: note.uuid!,
            relativePath: relativePath,
            sortOrder: sortOrder,
            fileSize: fileSize,
            mime: _guessImageMime(relativePath),
          );
          PMlog.w(_tag, '上传失败,保留本地资产: $relativePath, e=$e');
        }
        sortOrder++;
      } catch (e) {
        PMlog.e(_tag, '图片资产持久化异常: $relativePath, e=$e');
      }
    }
  }

  Future<void> _upsertImageNoteAsset({
    required String noteUuid,
    required String relativePath,
    required int sortOrder,
    required int fileSize,
    required String mime,
    String? serverAssetUuid,
    String? serverUrl,
    String? metadataJson,
  }) async {
    await _isar.writeTxn(() async {
      final existing = await _isar.noteAssets
          .filter()
          .noteUuidEqualTo(noteUuid)
          .and()
          .localPathEqualTo(relativePath)
          .findFirst();

      final asset = existing ?? NoteAsset();
      asset.noteUuid = noteUuid;
      asset.assetUuid =
          serverAssetUuid ??
          (existing != null ? existing.assetUuid : 'local-${const Uuid().v4()}');
      asset.type = 'image';
      asset.mime = mime;
      asset.fileSize = fileSize;
      asset.sortOrder = sortOrder;
      asset.localPath = relativePath;
      asset.serverUrl = serverUrl ?? asset.serverUrl;
      asset.metadataJson = metadataJson ?? asset.metadataJson;
      if (existing == null) {
        asset.createdAt = DateTime.now();
      }
      await _isar.noteAssets.put(asset);
    });
  }

  Future<void> _enqueueAiAnalysis(String noteUuid) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.reload();
    final pending = List<String>.from(
      prefs.getStringList(AppConstants.keyPendingAiAnalysis) ?? [],
    );
    if (!pending.contains(noteUuid)) {
      pending.add(noteUuid);
      await prefs.setStringList(AppConstants.keyPendingAiAnalysis, pending);
      PMlog.d(_tag, '已入队 AI 待轮询: $noteUuid');
    }
  }

  /// 把 AI 提交失败的 noteUuid 写入 [AppConstants.keyPendingAiSubmission]
  /// 列表（去重），等下次 runNow 入口 drain 重试。
  Future<void> _markPendingAiSubmission(String noteUuid) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.reload();
    final pending = List<String>.from(
      prefs.getStringList(AppConstants.keyPendingAiSubmission) ?? [],
    );
    if (!pending.contains(noteUuid)) {
      pending.add(noteUuid);
      await prefs.setStringList(
        AppConstants.keyPendingAiSubmission,
        pending,
      );
      PMlog.d(_tag, '已记录 AI 待重提交: $noteUuid');
    }
  }

  /// 在 runNow 入口被调用：把 [AppConstants.keyPendingAiSubmission] 列表里
  /// 等待重试的 noteUuid 全部 best-effort 重新提交一次。
  ///
  /// - 成功 → 从列表移除，并把它进 keyPendingAiAnalysis 让轮询拉结果
  /// - 仍失败 → 留在列表里，下一次再试
  /// - Note 已删 / 已 CRAWLED 但 noteApi 不可用 → 留在列表里，等下次
  ///
  /// 这条路径不计入 ScrapeAttempt 的重试计数，**永远不会**触发"3 次失败"通知。
  Future<void> _drainPendingAiSubmissions() async {
    if (_noteApiService == null) return;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.reload();
    final pending = List<String>.from(
      prefs.getStringList(AppConstants.keyPendingAiSubmission) ?? [],
    );
    if (pending.isEmpty) return;

    PMlog.d(_tag, '开始 drain 待重提交 AI: ${pending.length} 条');
    final remaining = <String>[];
    for (final uuid in pending) {
      final note = await _isar.notes.where().uuidEqualTo(uuid).findFirst();
      if (note == null || note.isDeleted) continue; // 丢弃已不存在的
      final url = note.url;
      if (url == null || url.isEmpty) continue;

      try {
        await _noteApiService.submitAnalysis(
          uuid: uuid,
          url: url,
          previewTitle: note.previewTitle,
          previewContent: _nonEmptyText(note.previewContent),
        );
        await _enqueueAiAnalysis(uuid);
        PMlog.d(_tag, 'AI 重提交成功: $uuid');
      } catch (e) {
        PMlog.w(_tag, 'AI 重提交仍失败,留待下次: $uuid, e=$e');
        remaining.add(uuid);
      }
    }
    await prefs.setStringList(
      AppConstants.keyPendingAiSubmission,
      remaining,
    );
  }

  Future<void> _notifyTerminalFailure({
    required String noteUuid,
    required String url,
  }) async {
    final svc = _notificationService;
    if (svc == null) return;
    await svc.showScrapeResultNotification(
      resultType: ScrapeResultType.failed,
      failedCount: 1,
      failedUrls: [url],
      failedNoteUuids: [noteUuid],
      errorMessage: '已尝试${AppConstants.maxScrapeAttempts}次抓取均失败,对应网页目前无法正常爬取~',
    );
  }

  String? _nonEmptyText(String? text) {
    if (text == null) return null;
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _guessImageMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
