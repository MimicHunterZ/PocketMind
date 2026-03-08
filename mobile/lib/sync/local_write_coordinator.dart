import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:pocketmind/model/category.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/sync/model/mutation_entry.dart';
import 'package:uuid/uuid.dart';

/// 本地写入协调器 —— 所有业务写操作的唯一合法入口。
///
/// 核心约束：
/// - [writeNote] / [writeCategory] / [deleteNote] 等方法内部用
///   单个 [Isar.writeTxn] 原子执行「业务表写入 + MutationEntry 追加」两步，
///   保证两者同生同死（事务中断则两者均不写入）。
/// - 任何绕过此类直接操作 Repository 的写操作视为架构违规。
///
/// 调用方（如 NoteService）完成调用后，向 SyncEngine 发送 kick 信号
/// 驱动后台 Push，但不 await，不影响 UI 响应速度。
class LocalWriteCoordinator {
  final Isar _isar;
  static const _uuid = Uuid();

  LocalWriteCoordinator(this._isar);

  /// 方便命名构造器与依赖注入兼容
  factory LocalWriteCoordinator.create(Isar isar) =>
      LocalWriteCoordinator(isar);

  // ─────────────────────────── Note ───────────────────────────

  /// 创建或更新笔记，并追加对应的 MutationEntry。
  ///
  /// - 若 [note.uuid] 为空，自动生成 UUID。
  /// - 始终更新 [note.updatedAt] 为当前毫秒时间戳。
  /// - 返回 Isar 自增 id。
  Future<int> writeNote(Note note) async {
    _ensureNoteDefaults(note);
    final operation = (note.id == null || note.id == Isar.autoIncrement)
        ? MutationOperation.create
        : MutationOperation.update;
    final mutation = _buildNoteMutation(note, operation);

    int resultId = 0;
    await _isar.writeTxn(() async {
      // 1. 建立分类关联
      final linkedCategory = await _isar.categorys.get(note.categoryId);
      note.category.value = linkedCategory;
      // 2. 写业务表
      resultId = await _isar.notes.put(note);
      await note.category.save();
      // 3. 追加 MutationEntry（同一事务）
      await _isar.mutationEntrys.put(mutation);
    });

    return resultId;
  }

  /// 软删除笔记（isDeleted=true），并追加 delete mutation。
  Future<void> softDeleteNote(Note note) async {
    note.isDeleted = true;
    note.updatedAt = DateTime.now().millisecondsSinceEpoch;
    final mutation = _buildNoteMutation(note, MutationOperation.delete);

    await _isar.writeTxn(() async {
      await _isar.notes.put(note);
      await _isar.mutationEntrys.put(mutation);
    });
  }

  // ─────────────────────────── Category ───────────────────────────

  /// 创建或更新分类，并追加对应的 MutationEntry。
  Future<int> writeCategory(Category category) async {
    _ensureCategoryDefaults(category);
    final operation = (category.id == null || category.id == Isar.autoIncrement)
        ? MutationOperation.create
        : MutationOperation.update;
    final mutation = _buildCategoryMutation(category, operation);

    int resultId = 0;
    await _isar.writeTxn(() async {
      resultId = await _isar.categorys.put(category);
      await _isar.mutationEntrys.put(mutation);
    });

    return resultId;
  }

  /// 软删除分类，并追加 delete mutation。
  Future<void> softDeleteCategory(Category category) async {
    category.isDeleted = true;
    category.updatedAt = DateTime.now().millisecondsSinceEpoch;
    final mutation = _buildCategoryMutation(category, MutationOperation.delete);

    await _isar.writeTxn(() async {
      await _isar.categorys.put(category);
      await _isar.mutationEntrys.put(mutation);
    });
  }

  // ─────────────────────────── 工具方法 ───────────────────────────

  void _ensureNoteDefaults(Note note) {
    if (note.uuid == null || note.uuid!.isEmpty) {
      note.uuid = _uuid.v4();
    }
    note.time ??= DateTime.now();
    note.updatedAt = DateTime.now().millisecondsSinceEpoch;
  }

  void _ensureCategoryDefaults(Category category) {
    if (category.uuid == null || category.uuid!.isEmpty) {
      category.uuid = _uuid.v4();
    }
    category.createdTime ??= DateTime.now();
    category.updatedAt = DateTime.now().millisecondsSinceEpoch;
  }

  MutationEntry _buildNoteMutation(Note note, String operation) {
    return MutationEntry()
      ..mutationId = _uuid.v4()
      ..entityType = MutationEntityType.note
      ..entityUuid = note.uuid!
      ..operation = operation
      ..payload = jsonEncode(_noteToPayload(note))
      ..updatedAt = note.updatedAt
      ..status = MutationStatus.pending
      ..retries = 0;
  }

  MutationEntry _buildCategoryMutation(Category category, String operation) {
    return MutationEntry()
      ..mutationId = _uuid.v4()
      ..entityType = MutationEntityType.category
      ..entityUuid = category.uuid!
      ..operation = operation
      ..payload = jsonEncode(_categoryToPayload(category))
      ..updatedAt = category.updatedAt
      ..status = MutationStatus.pending
      ..retries = 0;
  }

  /// 将 Note 转换为同步 payload Map（去除 Isar 内部字段）
  Map<String, dynamic> _noteToPayload(Note note) {
    return {
      'uuid': note.uuid,
      'title': note.title,
      'content': note.content,
      'url': note.url,
      'time': note.time?.millisecondsSinceEpoch,
      'updatedAt': note.updatedAt,
      'isDeleted': note.isDeleted,
      'categoryId': note.categoryId,
      'tags': note.tags,
      'previewImageUrl': note.previewImageUrl,
      'previewTitle': note.previewTitle,
      'previewDescription': note.previewDescription,
      'previewContent': note.previewContent,
      'resourceStatus': note.resourceStatus,
      'aiSummary': note.aiSummary,
      'serverVersion': note.serverVersion,
    };
  }

  Map<String, dynamic> _categoryToPayload(Category category) {
    return {
      'uuid': category.uuid,
      'name': category.name,
      'description': category.description,
      'iconPath': category.iconPath,
      'createdTime': category.createdTime?.millisecondsSinceEpoch,
      'updatedAt': category.updatedAt,
      'isDeleted': category.isDeleted,
    };
  }
}
