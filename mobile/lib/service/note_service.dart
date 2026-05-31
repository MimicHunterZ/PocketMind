import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/core/constants.dart';
import 'package:pocketmind/data/repositories/isar_note_repository.dart';
import 'package:pocketmind/sync/local_write_coordinator.dart';
import 'package:pocketmind/sync/resource_status_state_machine.dart';
import 'package:pocketmind/sync/sync_engine.dart';
import 'package:pocketmind/util/image_storage_helper.dart';
import 'package:pocketmind/util/logger_service.dart';

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
///
/// ## 抓取调度
/// 端侧 PENDING 抓取统一收敛到 ResourceFetchScheduler，本类不再维护
/// 任何 URL 队列或重试计数；执行细节落在 ScrapeAttempt 表。
class NoteService {
  final IsarNoteRepository _noteRepository;
  final LocalWriteCoordinator _writeCoordinator;
  final SyncEngine? _syncEngine;
  final ImageStorageHelper _imageHelper = ImageStorageHelper();

  NoteService({
    required IsarNoteRepository noteRepository,
    required LocalWriteCoordinator writeCoordinator,
    SyncEngine? syncEngine,
  }) : _noteRepository = noteRepository,
       _writeCoordinator = writeCoordinator,
       _syncEngine = syncEngine;

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
          ? ResourceStatusStateMachine.reduce(
              current: null,
              event: ResourceStatusEvent.localCreatedWithUrl,
            )
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
      ..aiSummary = aiSummary ?? existingNote.aiSummary;

    // resourceStatus 变更必须经过状态机决策，防止 CRAWLED 终态被降级
    if (resourceStatus != null &&
        resourceStatus != existingNote.resourceStatus) {
      existingNote.resourceStatus = ResourceStatusStateMachine.reduce(
            current: existingNote.resourceStatus,
            event: ResourceStatusEvent.serverSnapshot,
            incoming: resourceStatus,
          ) ??
          existingNote.resourceStatus;
    }
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

  /// 按 UUID 查找笔记。
  Future<Note?> findNoteByUuid(String uuid) async =>
      _noteRepository.findByUuid(uuid);

  Future<List<Note>> findNotesWithUrls(List<String> urls) async =>
      _noteRepository.findByUrls(urls);

  /// 后台衍生字段写入统一入口：
  /// - 持久化 Note
  /// - 追加 mutation 进入同步队列
  /// - 可选触发同步
  ///
  /// 供抓取、轮询、后台任务等非 UI 入口使用，避免旁路写导致跨端不一致。
  Future<int> persistDerivedNoteForSync(
    Note note, {
    bool triggerSync = true,
  }) async {
    final savedId = await _writeCoordinator.writeNote(note);
    if (triggerSync) {
      _syncEngine?.kick();
    }
    return savedId;
  }

  /// 手动触发一次同步（供 UI 操作入口调用）。
  void triggerSyncNow() {
    _syncEngine?.kick();
  }

  /// 应用资源状态事件。
  ///
  /// - 当 [syncAcrossDevices] 为 true：走统一写入口并入队 mutation。
  /// - 否则仅本地更新 resourceStatus（不修改 updatedAt）。
  Future<void> applyResourceStatusEvent(
    Note note,
    ResourceStatusEvent event, {
    String? incomingStatus,
    bool syncAcrossDevices = false,
    bool triggerSync = true,
  }) async {
    final nextStatus = ResourceStatusStateMachine.reduce(
      current: note.resourceStatus,
      event: event,
      incoming: incomingStatus,
    );

    if (nextStatus == note.resourceStatus || nextStatus == null) {
      return;
    }

    note.resourceStatus = nextStatus;

    if (syncAcrossDevices) {
      await persistDerivedNoteForSync(note, triggerSync: triggerSync);
      return;
    }

    await _noteRepository.updateResourceStatus(note, nextStatus);
  }

  /// 用户强制完成 loading 预览。
  ///
  /// 跨设备语义：将状态写为 FAILED 并入队同步，
  /// 后台若后续成功可再升级为 CRAWLED。
  Future<void> forceCompleteByUser(Note note) async {
    await applyResourceStatusEvent(
      note,
      ResourceStatusEvent.userForceComplete,
      syncAcrossDevices: true,
      triggerSync: true,
    );
  }

  // ─────────────────────────── 工具方法 ───────────────────────────

  bool _isLocalImage(String path) => path.contains('pocket_images/');
}
