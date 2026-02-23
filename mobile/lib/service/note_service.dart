import 'dart:convert';

import 'package:pocketmind/core/constants.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/data/repositories/isar_note_repository.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'package:pocketmind/util/image_storage_helper.dart';
import 'package:pocketmind/service/metadata_manager.dart';
import 'package:pocketmind/api/note_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

final String noteServiceTag = 'NoteService';

class RetryEligibilityResult {
  final List<String> retryableUrls;
  final List<String> reachedMaxRetryUrls;

  const RetryEligibilityResult({
    required this.retryableUrls,
    required this.reachedMaxRetryUrls,
  });
}

/// 本地 Note 业务服务层
class NoteService {
  final IsarNoteRepository _noteRepository;
  final MetadataManager _metadataManager;
  final SharedPreferences _prefs;
  final NoteApiService? _noteApiService;
  final ImageStorageHelper _imageHelper = ImageStorageHelper();

  NoteService(
    this._noteRepository,
    this._metadataManager,
    this._prefs, [
    this._noteApiService,
  ]);

  /// 新增笔记
  ///
  /// 如果保存失败，将抛出异常
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
    PMlog.d(
      noteServiceTag,
      'Adding note: title: $title, categoryId: $categoryId',
    );

    // 创建 Note 模型
    final note = Note()
      ..title = title
      ..content = content
      ..url = url
      ..categoryId = categoryId
      ..time = DateTime.now()
      ..tags = tags
      ..previewImageUrl = previewImageUrl
      ..previewTitle = previewTitle
      ..previewDescription = previewDescription
      ..aiSummary = aiSummary
      ..updatedAt = 0;

    final savedId = await _noteRepository.save(note, updateTimestamp: true);

    // todo 暂且不放在这边获取
    // // 如果包含 URL，触发异步元数据抓取
    // if (url != null && url.isNotEmpty) {
    //   // 异步执行，不阻塞保存操作
    //   Future.microtask(() async {
    //     try {
    //       final savedNote = await _noteRepository.getById(savedId);
    //       if (savedNote != null) {
    //         await enrichNoteWithMetadata(savedNote);
    //       }
    //     } catch (e) {
    //       PMlog.e(noteServiceTag, 'Background enrichment failed: $e');
    //     }
    //   });
    // }

    return savedId;
  }

  /// 更新笔记
  ///
  /// 如果保存失败，将抛出异常
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
    String? pendingAiQuestion,
    int? updatedAt,
    bool updateTimestamp = true,
  }) async {
    PMlog.d(
      noteServiceTag,
      'Updating note: id: $id, title: $title, updateTimestamp: $updateTimestamp',
    );

    final existingNote = await _noteRepository.getById(id);
    if (existingNote == null) {
      throw Exception('Note not found: $id');
    }

    // 更新字段（只更新提供的字段）
    existingNote.title = title ?? existingNote.title;
    existingNote.content = content ?? existingNote.content;
    existingNote.url = url ?? existingNote.url;
    existingNote.categoryId = categoryId ?? existingNote.categoryId;
    if (tags != null) existingNote.tags = tags;
    existingNote.previewImageUrl =
        previewImageUrl ?? existingNote.previewImageUrl;
    existingNote.previewTitle = previewTitle ?? existingNote.previewTitle;
    existingNote.previewDescription =
        previewDescription ?? existingNote.previewDescription;
    existingNote.previewContent = previewContent ?? existingNote.previewContent;
    if (aiSummary != null) existingNote.aiSummary = aiSummary;
    if (pendingAiQuestion != null)
      existingNote.pendingAiQuestion = pendingAiQuestion;
    existingNote.updatedAt = updatedAt ?? existingNote.updatedAt;

    final savedId = await _noteRepository.save(
      existingNote,
      updateTimestamp: updateTimestamp,
    );

    return savedId;
  }

  /// 根据笔记id获取笔记
  Future<Note?> getNoteById(int noteId) async {
    return await _noteRepository.getById(noteId);
  }

  /// 获取所有笔记
  Future<List<Note>> getAllNotes() async {
    return await _noteRepository.getAll();
  }

  /// 监听并且获取所有笔记
  Stream<List<Note>> watchAllNotes() {
    return _noteRepository.watchAll();
  }

  /// 监听categories变化并且获取笔记
  Stream<List<Note>> watchCategoryNotes(int category) {
    return _noteRepository.watchByCategory(category);
  }

  /// 删除笔记及其关联资源（如本地图片）
  Future<void> deleteNote(int noteId) async {
    final note = await _noteRepository.getById(noteId);
    if (note != null) {
      await deleteFullNote(note);
    }
  }

  /// 删除完整笔记对象及其关联资源
  Future<void> deleteFullNote(Note note) async {
    // 1. 处理关联资源（如本地图片）
    final url = note.url;
    if (url != null && url.isNotEmpty && _isLocalImage(url)) {
      await _imageHelper.deleteImage(url);
    }

    // 删除预览图片（单张）
    if (note.previewImageUrl != null && _isLocalImage(note.previewImageUrl!)) {
      await _imageHelper.deleteImage(note.previewImageUrl!);
    }

    // 2. 从数据库删除
    if (note.id != null) {
      await _noteRepository.delete(note.id!);
      PMlog.d(noteServiceTag, 'Note deleted: ${note.id}');
    }
  }

  bool _isLocalImage(String path) {
    // 简单的本地路径判断逻辑，可以根据实际情况完善
    return path.contains('pocket_images/');
  }

  Future<void> deleteAllNoteByCategoryId(int categoryId) async {
    // TODO: 如果需要删除分类下所有笔记，也需要循环处理图片删除
    await _noteRepository.deleteAllByCategoryId(categoryId);
  }

  /// 根据 title 查询笔记
  Future<List<Note>> findNotesWithTitle(String query) async {
    return await _noteRepository.findByTitle(query);
  }

  /// 根据 content 查询笔记
  Future<List<Note>> findNotesWithContent(String query) async {
    return await _noteRepository.findByContent(query);
  }

  /// 根据 categoryId 查询笔记
  Future<List<Note>> findNotesWithCategory(int categoryId) async {
    return await _noteRepository.findByCategoryId(categoryId);
  }

  /// 根据 tag 查询笔记
  Future<List<Note>> findNotesWithTag(String query) async {
    return await _noteRepository.findByTag(query);
  }

  /// 全部匹配查询
  Stream<List<Note>> findNotesWithQuery(String query) {
    return _noteRepository.findByQuery(query);
  }

  /// 根据 url 查询笔记
  Future<List<Note>> findNotesWithUrls(List<String> urls) async {
    return await _noteRepository.findByUrls(urls);
  }

  // /// 丰富笔记元数据（链接预览）
  // ///
  // /// 自动抓取链接预览信息，本地化图片，并更新数据库
  // /// 如果抓取失败或数据不完整，返回原笔记对象
  // Future<Note> enrichNoteWithMetadata(Note note) async {
  //   final url = note.url;
  //   // 1. 基础校验：必须有 URL，且未处理过（或者强制刷新）
  //   if (url == null ||
  //       url.isEmpty ||
  //       (note.previewImageUrl != null && note.previewImageUrl!.isNotEmpty) ||
  //       (note.previewTitle != null && note.previewTitle!.isNotEmpty)) {
  //     return note;
  //   }
  //
  //   PMlog.d(noteServiceTag, '开始获取链接元数据: $url');
  //
  //   try {
  //     // 2. 调用 MetadataManager 获取并处理数据
  //     final results = await _metadataManager.fetchAndProcessMetadata([url]);
  //     final metadata = results[url];
  //
  //     if (metadata != null && metadata.isValid) {
  //       // 3. 更新数据库
  //       note.previewImageUrl = metadata.imageUrl;
  //       note.previewTitle = metadata.title;
  //       note.previewDescription = metadata.displayDescription;
  //
  //       if (metadata.previewContent != null &&
  //           metadata.previewContent!.trim().isNotEmpty) {
  //         note.previewContent = metadata.previewContent;
  //       }
  //       if (metadata.aiSummary != null &&
  //           metadata.aiSummary!.trim().isNotEmpty) {
  //         note.aiSummary = metadata.aiSummary;
  //       }
  //       if (metadata.resourceStatus != null) {
  //         note.resourceStatus = metadata.resourceStatus;
  //       }
  //
  //       await _noteRepository.save(note);
  //       PMlog.d(noteServiceTag, '元数据已更新: ${note.id}');
  //     }
  //     return note;
  //   } catch (e) {
  //     PMlog.e(noteServiceTag, '丰富笔记元数据失败: $e');
  //     return note;
  //   }
  // }

  /// 传入 note 从后端拉取资源正文/摘要
  ///
  /// - 仅当 url 存在且 previewContent 为空时尝试
  /// - 成功：写入 previewContent/aiSummary/resourceStatus，并落库
  /// - 失败：返回原笔记对象
  // Future<Note> fetchAndPersistResourceContentIfNeeded(Note note) async {
  //   final url = note.url;
  //   if (url == null || url.isEmpty) return note;
  //   if (note.previewContent != null && note.previewContent!.trim().isNotEmpty) {
  //     return note;
  //   }
  //
  //   try {
  //     final noteMetadata = await _metadataManager.fetchAndProcessMetadata([
  //       url,
  //     ]);
  //     if (noteMetadata.isEmpty) return note;
  //
  //     PMlog.d(noteServiceTag, '开始保存后端返回的note数据');
  //     note.title = noteMetadata[url]?.title ?? note.title;
  //     note.resourceStatus = noteMetadata[url]?.resourceStatus;
  //     note.previewContent = noteMetadata[url]?.previewContent;
  //     note.aiSummary = noteMetadata[url]?.aiSummary;
  //
  //     // todo 这边需要统一使用一个入口，但是 现在 id 和 uuid 还没区分开，先放着
  //     await _noteRepository.save(note);
  //     return note;
  //   } catch (e) {
  //     PMlog.e(noteServiceTag, '从后端获取资源内容失败: $e');
  //     return note;
  //   }
  // }

  // todo 确认一下 riverpod 最佳实践在这里是不是这样写最好
  /// 处理待回调的 URL
  ///
  /// 检查 SharedPreferences 中的 needCallBackUrl 列表
  /// 对每个 URL 尝试查找对应的 Note 并向后端资源内容
  /// 如果笔记有待处理的 AI 问题，获取 content 成功后会调用 AI 分析
  /// 统一的待处理 URL 调度入口（分享后触发、App 启动/回前台触发都走这里）
  ///
  /// [userQuestion] 为可选参数：分享页带问题进入时透传给后台抓取任务；
  /// 主应用恢复流程可不传，保持默认抓取行为。
  Future<void> processPendingUrls({String? userQuestion}) async {
    // 重新获取 SharedPreferences 实例，确保数据是最新的
    // 因为 Android 的 SharedPreferences 在不同进程（主应用和分享扩展）之间不会自动同步内存缓存。
    await _prefs.reload();
    final urls = (_prefs.getStringList(AppConstants.keyNeedCallbackUrl) ?? [])
        .where((url) => url.trim().isNotEmpty)
        .toSet()
        .toList();

    if (urls.length !=
        (_prefs.getStringList(AppConstants.keyNeedCallbackUrl) ?? []).length) {
      await _prefs.setStringList(AppConstants.keyNeedCallbackUrl, urls);
    }

    if (urls.isEmpty) {
      PMlog.d(noteServiceTag, 'urls 为空不处理');
      return;
    }

    final eligibility = await evaluateRetryEligibility(urls);
    final permanentlyFailedUrls = eligibility.reachedMaxRetryUrls;
    final retryableUrls = eligibility.retryableUrls;

    if (permanentlyFailedUrls.isNotEmpty) {
      await markUrlsAsFailedAndStopRetry(permanentlyFailedUrls);
      Workmanager().registerOneOffTask(
        'url_scraper_retry_exhausted_${DateTime.now().millisecondsSinceEpoch}',
        AppConstants.taskNotifyRetryExhausted,
        inputData: {AppConstants.taskInputUrls: permanentlyFailedUrls},
        initialDelay: Duration(seconds: 0),
      );
      PMlog.w(
        noteServiceTag,
        '检测到超过重试上限 URL，已直接标记失败并停止重试: $permanentlyFailedUrls',
      );
    }

    if (retryableUrls.isEmpty) {
      PMlog.d(noteServiceTag, '无可重试 URL，跳过任务注册');
      return;
    }

    await markUrlsAsScraping(retryableUrls);

    PMlog.d(noteServiceTag, '后台开始处理 URLs: $retryableUrls');
    await scheduleScrapeTask(
      urls: retryableUrls,
      userQuestion: userQuestion,
      taskUniqueName: 'url_scraper',
      initialDelay: Duration.zero,
    );
  }

  /// 统一注册抓取后台任务。
  ///
  /// 该方法是所有 URL 抓取任务的唯一调度入口，避免多处直接注册 `scrapeAndSave`。
  Future<void> scheduleScrapeTask({
    required List<String> urls,
    required String taskUniqueName,
    String? userQuestion,
    Duration initialDelay = Duration.zero,
  }) async {
    if (urls.isEmpty) return;
    await Workmanager().registerOneOffTask(
      taskUniqueName,
      AppConstants.taskScrapeAndSave,
      inputData: {
        AppConstants.taskInputUrls: urls,
        AppConstants.taskInputUserQuestion: userQuestion,
      },
      initialDelay: initialDelay,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  /// 评估候选 URL 的重试资格。
  ///
  /// 规则：
  /// 1. 仅 `needCallBackUrl` 中仍待处理的 URL 才有资格重试；
  /// 2. 达到最大重试次数的 URL 归入 `reachedMaxRetryUrls`；
  /// 3. 其余 URL 归入 `retryableUrls`。
  Future<RetryEligibilityResult> evaluateRetryEligibility(
    Iterable<String> candidateUrls,
  ) async {
    await _prefs.reload();

    final pendingUrls =
        (_prefs.getStringList(AppConstants.keyNeedCallbackUrl) ?? [])
            .map((url) => url.trim())
            .where((url) => url.isNotEmpty)
            .toSet();

    final retryCountMap = await _loadRetryCountMap();
    final reachedMaxRetryUrls = <String>[];
    final retryableUrls = <String>[];

    final normalizedCandidates = candidateUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet();

    for (final url in normalizedCandidates) {
      if (!pendingUrls.contains(url)) {
        continue;
      }

      final retryCount = retryCountMap[url] ?? 0;
      if (retryCount >= AppConstants.maxShareUrlRetryCount) {
        reachedMaxRetryUrls.add(url);
      } else {
        retryableUrls.add(url);
      }
    }

    return RetryEligibilityResult(
      retryableUrls: retryableUrls,
      reachedMaxRetryUrls: reachedMaxRetryUrls,
    );
  }

  /// 将 URL 放入待处理队列（幂等去重）。
  ///
  /// 返回值：
  /// - `true`: 本次是首次加入；
  /// - `false`: 队列中已存在该 URL（忽略重复分享）。
  Future<bool> enqueuePendingUrlIfAbsent(String url) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) return false;

    await _prefs.reload();
    final urls = (_prefs.getStringList(AppConstants.keyNeedCallbackUrl) ?? [])
        .where((item) => item.trim().isNotEmpty)
        .toSet();

    final hasExisting = urls.contains(normalizedUrl);
    if (!hasExisting) {
      urls.add(normalizedUrl);
      await _prefs.setStringList(
        AppConstants.keyNeedCallbackUrl,
        urls.toList(),
      );
      PMlog.d(noteServiceTag, 'URL 已加入待处理队列: $normalizedUrl');
    } else {
      PMlog.d(noteServiceTag, 'URL 已存在待处理队列，忽略重复加入: $normalizedUrl');
    }

    return !hasExisting;
  }

  /// 从待处理队列移除 URL，并同步清理对应重试计数。
  ///
  /// 用于：
  /// - 抓取成功后清理；
  /// - 手动忽略/终态失败后清理。
  Future<void> removePendingUrls(Iterable<String> urls) async {
    final normalizedToRemove = urls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet();
    if (normalizedToRemove.isEmpty) return;

    await _prefs.reload();
    final currentUrls =
        (_prefs.getStringList(AppConstants.keyNeedCallbackUrl) ?? [])
            .where((url) => url.trim().isNotEmpty)
            .toSet();
    currentUrls.removeAll(normalizedToRemove);
    await _prefs.setStringList(
      AppConstants.keyNeedCallbackUrl,
      currentUrls.toList(),
    );

    await clearRetryCountForUrls(normalizedToRemove);
  }

  /// 失败 URL 的重试次数 +1，并返回“本次达到上限”的 URL 列表。
  ///
  /// 该方法只负责计数，不负责落库失败状态。
  Future<List<String>> increaseRetryCountForUrls(Iterable<String> urls) async {
    final normalizedUrls = urls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();
    if (normalizedUrls.isEmpty) return [];

    final retryCountMap = await _loadRetryCountMap();
    final reachedMaxUrls = <String>[];

    for (final url in normalizedUrls) {
      final current = retryCountMap[url] ?? 0;
      final next = current + 1;
      retryCountMap[url] = next;
      if (next >= AppConstants.maxShareUrlRetryCount) {
        reachedMaxUrls.add(url);
      }
    }

    await _saveRetryCountMap(retryCountMap);
    return reachedMaxUrls;
  }

  /// 统一写入资源抓取状态并持久化。
  ///
  /// 作为 `resourceStatus` 变更的单一入口，避免各层重复直接写字段。
  Future<void> persistResourceStatus(Note note, String status) async {
    note.resourceStatus = status;
    await _noteRepository.save(note);
  }

  /// 将 URL 对应笔记显式标记为抓取中。
  ///
  /// 用于在后台任务真正执行前先更新 UI，避免短暂显示为普通卡片。
  Future<void> markUrlsAsScraping(Iterable<String> urls) async {
    final normalizedUrls = urls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();
    if (normalizedUrls.isEmpty) return;

    final notes = await findNotesWithUrls(normalizedUrls);
    for (final note in notes) {
      await persistResourceStatus(note, AppConstants.resourceStatusScraping);
    }
  }

  /// 清理指定 URL 的重试计数。
  ///
  /// 当 URL 成功、取消或进入终态失败后调用，防止历史计数污染。
  Future<void> clearRetryCountForUrls(Iterable<String> urls) async {
    final normalizedUrls = urls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet();
    if (normalizedUrls.isEmpty) return;

    final retryCountMap = await _loadRetryCountMap();
    var changed = false;
    for (final url in normalizedUrls) {
      changed = retryCountMap.remove(url) != null || changed;
    }
    if (changed) {
      await _saveRetryCountMap(retryCountMap);
    }
  }

  /// 将 URL 对应的 Note 标记为 `FAILED`，并停止后续重试。
  ///
  /// 执行内容：
  /// 1. 落库 `resourceStatus=FAILED`；
  /// 2. 从待处理队列移除；
  /// 3. 清理重试计数。
  Future<void> markUrlsAsFailedAndStopRetry(Iterable<String> urls) async {
    final normalizedUrls = urls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();

    if (normalizedUrls.isEmpty) return;

    final notes = await findNotesWithUrls(normalizedUrls);
    for (final note in notes) {
      await persistResourceStatus(note, AppConstants.resourceStatusFailed);
    }

    await removePendingUrls(normalizedUrls);
    await clearRetryCountForUrls(normalizedUrls);
  }

  /// 读取 URL 重试计数字典（SharedPreferences JSON）。
  ///
  /// 返回格式：`Map<url, retryCount>`。
  Future<Map<String, int>> _loadRetryCountMap() async {
    final rawJson = _prefs.getString(AppConstants.keyShareUrlRetryCountMap);
    if (rawJson == null || rawJson.isEmpty) {
      return <String, int>{};
    }

    try {
      final decoded = json.decode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        return <String, int>{};
      }

      final result = <String, int>{};
      decoded.forEach((key, value) {
        final normalizedUrl = key.trim();
        if (normalizedUrl.isEmpty) return;
        if (value is int) {
          result[normalizedUrl] = value;
        } else if (value is num) {
          result[normalizedUrl] = value.toInt();
        }
      });
      return result;
    } catch (e) {
      PMlog.e(noteServiceTag, '解析重试计数失败，已回退为空: $e');
      return <String, int>{};
    }
  }

  /// 持久化 URL 重试计数字典。
  ///
  /// 当字典为空时删除对应 key，避免无意义存储。
  Future<void> _saveRetryCountMap(Map<String, int> retryCountMap) async {
    if (retryCountMap.isEmpty) {
      await _prefs.remove(AppConstants.keyShareUrlRetryCountMap);
      return;
    }
    await _prefs.setString(
      AppConstants.keyShareUrlRetryCountMap,
      json.encode(retryCountMap),
    );
  }
}
