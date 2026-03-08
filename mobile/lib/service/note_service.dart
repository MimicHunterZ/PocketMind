import 'dart:convert';

import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/core/constants.dart';
import 'package:pocketmind/data/repositories/isar_note_repository.dart';
import 'package:pocketmind/sync/local_write_coordinator.dart';
import 'package:pocketmind/sync/sync_engine.dart';
import 'package:pocketmind/util/image_storage_helper.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

final String noteServiceTag = 'NoteService';

/// 笔记业务服务层 —— 用户操作的统一入口。
///
/// ## 写路径
/// 所有写操作（create / update / delete）通过 [LocalWriteCoordinator]
/// 在单个 Isar 事务中原子完成「业务表写入 + MutationEntry 追加」，
/// 完成后向 [SyncEngine] 发送 kick 信号（不阻塞）。
///
/// ## 读路径
/// 读操作直接委托 [IsarNoteRepository] 的 Watch 流，
/// UI 层通过 Riverpod StreamProvider 订阅，断网时自动展示历史数据。
class NoteService {
  final IsarNoteRepository _noteRepository;
  final LocalWriteCoordinator _writeCoordinator;
  final SyncEngine? _syncEngine;
  final SharedPreferences? _prefs;
  final ImageStorageHelper _imageHelper = ImageStorageHelper();

  NoteService({
    required IsarNoteRepository noteRepository,
    required LocalWriteCoordinator writeCoordinator,
    SyncEngine? syncEngine,
    SharedPreferences? prefs,
  }) : _noteRepository = noteRepository,
       _writeCoordinator = writeCoordinator,
       _syncEngine = syncEngine,
       _prefs = prefs;

  /// 获取 SharedPreferences 实例（优先用构造注入，降级懒加载）
  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  // ─────────────────────────── 写操作 ───────────────────────────

  /// 新增笔记。
  ///
  /// 若包含 URL，会将 resourceStatus 置为 PENDING，
  /// 由 [ResourceFetchScheduler] 在有网时自动触发端侧抓取。
  Future<int> addNote({
    String? title,
    String? content,
    String? url,
    int categoryId = AppConstants.homeCategoryId,
    List<String> tags = const [],
    String? previewImageUrl,
    String? previewTitle,
    String? previewDescription,
    String? aiSummary,
  }) async {
    PMlog.d(noteServiceTag, '新增笔记: title=$title, categoryId=$categoryId');

    final note = Note()
      ..title = title
      ..content = content
      ..url = url
      ..categoryId = categoryId
      ..tags = tags
      ..previewImageUrl = previewImageUrl
      ..previewTitle = previewTitle
      ..previewDescription = previewDescription
      ..aiSummary = aiSummary
      ..resourceStatus = (url != null && url.isNotEmpty)
          ? AppConstants.resourceStatusPending
          : null;

    final savedId = await _writeCoordinator.writeNote(note);
    _syncEngine?.kick();
    return savedId;
  }

  /// 更新笔记。
  ///
  /// 只更新非 null 参数对应的字段，其余字段保持原值。
  Future<int> updateNote({
    required int id,
    String? title,
    String? content,
    String? url,
    int? categoryId,
    List<String>? tags,
    String? previewImageUrl,
    String? previewTitle,
    String? previewContent,
    String? previewDescription,
    String? aiSummary,
    String? resourceStatus,
  }) async {
    PMlog.d(noteServiceTag, '更新笔记: id=$id, title=$title');

    final existingNote = await _noteRepository.getById(id);
    if (existingNote == null) throw Exception('Note not found: $id');

    existingNote
      ..title = title ?? existingNote.title
      ..content = content ?? existingNote.content
      ..url = url ?? existingNote.url
      ..categoryId = categoryId ?? existingNote.categoryId
      ..previewImageUrl = previewImageUrl ?? existingNote.previewImageUrl
      ..previewTitle = previewTitle ?? existingNote.previewTitle
      ..previewDescription =
          previewDescription ?? existingNote.previewDescription
      ..previewContent = previewContent ?? existingNote.previewContent
      ..resourceStatus = resourceStatus ?? existingNote.resourceStatus
      ..aiSummary = aiSummary ?? existingNote.aiSummary;
    if (tags != null) existingNote.tags = tags;

    final savedId = await _writeCoordinator.writeNote(existingNote);
    _syncEngine?.kick();
    return savedId;
  }

  /// 删除笔记（软删除 + 清理本地图片资源）。
  Future<void> deleteNote(int noteId) async {
    final note = await _noteRepository.getById(noteId);
    if (note != null) await deleteFullNote(note);
  }

  /// 删除完整笔记对象及其关联资源
  Future<void> deleteFullNote(Note note) async {
    await _deleteLocalAssetsIfNeeded(note);

    await _writeCoordinator.softDeleteNote(note);
    _syncEngine?.kick();
    PMlog.d(noteServiceTag, '笔记已删除: ${note.id}');
  }

  Future<void> deleteAllNoteByCategoryId(int categoryId) async {
    final notes = await _noteRepository.findByCategoryId(categoryId);
    for (final note in notes) {
      await _deleteLocalAssetsIfNeeded(note);
      await _writeCoordinator.softDeleteNote(note);
    }
    _syncEngine?.kick();
  }

  Future<void> _deleteLocalAssetsIfNeeded(Note note) async {
    final url = note.url;
    if (url != null && url.isNotEmpty && _isLocalImage(url)) {
      await _imageHelper.deleteImage(url);
    }

    final previewImageUrl = note.previewImageUrl;
    if (previewImageUrl != null && _isLocalImage(previewImageUrl)) {
      await _imageHelper.deleteImage(previewImageUrl);
    }
  }

  // ─────────────────────────── 读操作 ───────────────────────────

  Future<Note?> getNoteById(int noteId) async =>
      _noteRepository.getById(noteId);

  Future<List<Note>> getAllNotes() async => _noteRepository.getAll();

  Stream<List<Note>> watchAllNotes() => _noteRepository.watchAll();

  Stream<List<Note>> watchCategoryNotes(int category) =>
      _noteRepository.watchByCategory(category);

  Future<List<Note>> findNotesWithTitle(String query) async =>
      _noteRepository.findByTitle(query);

  Future<List<Note>> findNotesWithContent(String query) async =>
      _noteRepository.findByContent(query);

  Future<List<Note>> findNotesWithCategory(int categoryId) async =>
      _noteRepository.findByCategoryId(categoryId);

  Future<List<Note>> findNotesWithTag(String query) async =>
      _noteRepository.findByTag(query);

  Stream<List<Note>> findNotesWithQuery(String query) =>
      _noteRepository.findByQuery(query);

  Future<List<Note>> findNotesWithUrls(List<String> urls) async =>
      _noteRepository.findByUrls(urls);

  /// 持久化 resourceStatus 字段（不更新 updatedAt，由 [ResourceFetchScheduler] 调用）。
  Future<void> persistResourceStatus(Note note, String status) async {
    await _noteRepository.updateResourceStatus(note, status);
  }

  // ─────────────────── 分享 URL 队列管理（Workmanager 流程）───────────────────

  /// 幂等地将 [url] 加入待抓取队列（SharedPreferences [AppConstants.keyNeedCallbackUrl]）。
  ///
  /// 返回 true 表示新加入，false 表示已存在。
  Future<bool> enqueuePendingUrlIfAbsent(String url) async {
    final prefs = await _getPrefs();
    final existing = prefs.getStringList(AppConstants.keyNeedCallbackUrl) ?? [];
    if (existing.contains(url)) {
      PMlog.d(noteServiceTag, 'URL 已在队列中，跳过: $url');
      return false;
    }
    existing.add(url);
    await prefs.setStringList(AppConstants.keyNeedCallbackUrl, existing);
    PMlog.d(noteServiceTag, '已入队: $url（当前队列 ${existing.length} 条）');
    return true;
  }

  /// 读取待处理 URL 队列，评估重试资格后向 Workmanager 注册抓取任务。
  Future<void> processPendingUrls({String? userQuestion}) async {
    final prefs = await _getPrefs();
    final pending = prefs.getStringList(AppConstants.keyNeedCallbackUrl) ?? [];
    if (pending.isEmpty) {
      PMlog.d(noteServiceTag, 'processPendingUrls: 队列为空，无需调度');
      return;
    }

    PMlog.d(noteServiceTag, 'processPendingUrls: 待处理 ${pending.length} 条 URL');
    final eligibility = await evaluateRetryEligibility(pending);

    // 已达上限的 URL 标记失败
    if (eligibility.reachedMaxRetryUrls.isNotEmpty) {
      await markUrlsAsFailedAndStopRetry(eligibility.reachedMaxRetryUrls);
      PMlog.w(
        noteServiceTag,
        '已达最大重试次数，标记失败: ${eligibility.reachedMaxRetryUrls}',
      );
    }

    if (eligibility.retryableUrls.isEmpty) {
      PMlog.d(noteServiceTag, 'processPendingUrls: 无可重试 URL');
      return;
    }

    await scheduleScrapeTask(
      urls: eligibility.retryableUrls,
      taskUniqueName:
          '${AppConstants.taskScrapeAndSave}_${DateTime.now().millisecondsSinceEpoch}',
      userQuestion: userQuestion,
    );
  }

  /// 将 [urls] 从待处理队列中移除。
  Future<void> removePendingUrls(List<String> urls) async {
    if (urls.isEmpty) return;
    final prefs = await _getPrefs();
    final existing = prefs.getStringList(AppConstants.keyNeedCallbackUrl) ?? [];
    existing.removeWhere(urls.contains);
    await prefs.setStringList(AppConstants.keyNeedCallbackUrl, existing);
    PMlog.d(noteServiceTag, '已从队列移除 ${urls.length} 条 URL');
  }

  /// 将 [urls] 移出队列并停止重试（终态）。
  Future<void> markUrlsAsFailedAndStopRetry(List<String> urls) async {
    await removePendingUrls(urls);
    // 同时清除计数，避免僵尸数据
    if (urls.isNotEmpty) {
      final prefs = await _getPrefs();
      final mapJson =
          prefs.getString(AppConstants.keyShareUrlRetryCountMap) ?? '{}';
      final countMap = Map<String, dynamic>.from(jsonDecode(mapJson) as Map);
      for (final url in urls) {
        countMap.remove(url);
      }
      await prefs.setString(
        AppConstants.keyShareUrlRetryCountMap,
        jsonEncode(countMap),
      );
    }
    PMlog.w(noteServiceTag, '标记失败停止重试: $urls');
  }

  /// 增加 [urls] 的重试计数，返回本次达到最大重试次数的 URL 列表。
  Future<List<String>> increaseRetryCountForUrls(List<String> urls) async {
    if (urls.isEmpty) return [];
    final prefs = await _getPrefs();
    final mapJson =
        prefs.getString(AppConstants.keyShareUrlRetryCountMap) ?? '{}';
    final countMap = Map<String, dynamic>.from(jsonDecode(mapJson) as Map);
    final maxReached = <String>[];
    for (final url in urls) {
      final current = (countMap[url] as num?)?.toInt() ?? 0;
      final next = current + 1;
      countMap[url] = next;
      if (next >= AppConstants.maxShareUrlRetryCount) maxReached.add(url);
    }
    await prefs.setString(
      AppConstants.keyShareUrlRetryCountMap,
      jsonEncode(countMap),
    );
    return maxReached;
  }

  /// 评估 [urls] 中哪些仍可重试，哪些已达上限。
  Future<RetryEligibility> evaluateRetryEligibility(List<String> urls) async {
    if (urls.isEmpty) {
      return const RetryEligibility(retryableUrls: [], reachedMaxRetryUrls: []);
    }
    final prefs = await _getPrefs();
    final mapJson =
        prefs.getString(AppConstants.keyShareUrlRetryCountMap) ?? '{}';
    final countMap = Map<String, dynamic>.from(jsonDecode(mapJson) as Map);
    final retryable = <String>[];
    final maxRetried = <String>[];
    for (final url in urls) {
      final count = (countMap[url] as num?)?.toInt() ?? 0;
      if (count >= AppConstants.maxShareUrlRetryCount) {
        maxRetried.add(url);
      } else {
        retryable.add(url);
      }
    }
    return RetryEligibility(
      retryableUrls: retryable,
      reachedMaxRetryUrls: maxRetried,
    );
  }

  /// 将 [urls] 标记为「抓取中」（从待处理队列移除，由 scrapeAndSave 任务接管）。
  Future<void> markUrlsAsScraping(List<String> urls) async {
    await removePendingUrls(urls);
    PMlog.d(noteServiceTag, '标记为抓取中: $urls');
  }

  /// 向 Workmanager 注册一次性抓取任务。
  Future<void> scheduleScrapeTask({
    required List<String> urls,
    required String taskUniqueName,
    String? userQuestion,
    Duration initialDelay = Duration.zero,
  }) async {
    PMlog.d(noteServiceTag, '注册 Workmanager 任务: $taskUniqueName, urls=$urls');
    await Workmanager().registerOneOffTask(
      taskUniqueName,
      AppConstants.taskScrapeAndSave,
      initialDelay: initialDelay,
      inputData: {
        AppConstants.taskInputUrls: urls,
        if (userQuestion != null)
          AppConstants.taskInputUserQuestion: userQuestion,
      },
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  // ─────────────────────────── 工具方法 ───────────────────────────

  bool _isLocalImage(String path) => path.contains('pocket_images/');
}

/// 重试资格评估结果
class RetryEligibility {
  final List<String> retryableUrls;
  final List<String> reachedMaxRetryUrls;

  const RetryEligibility({
    required this.retryableUrls,
    required this.reachedMaxRetryUrls,
  });
}
