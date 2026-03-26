import 'package:isar_community/isar.dart';
import 'package:pocketmind/api/sync_api_service.dart';
import 'package:pocketmind/model/category.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/sync/model/mutation_entry.dart';
import 'package:pocketmind/sync/model/sync_checkpoint.dart';
import 'package:pocketmind/sync/model/sync_dto.dart';
import 'package:pocketmind/sync/note_sync_payload_mapper.dart';
import 'package:pocketmind/sync/sync_checkpoint_policy.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'package:pocketmind/util/tag_list_utils.dart';

/// Pull 协调器 —— 负责从服务端增量拉取变更并应用到本地 Isar。
///
/// 核心行为：
/// 1. 以 [SyncCheckpoint.lastPulledVersion] 为游标请求后端增量数据。
/// 2. 分页处理，每批完整写入 Isar 后才更新游标（防崩溃数据空洞）。
/// 3. Pull Apply 阶段执行字段级 LWW 合并：
///    - 本地无 pending mutation ➜ 粗粒度 updatedAt 比较，服务端胜则全字段覆盖。
///    - 本地有 pending mutation ➜ 细粒度合并：仅覆盖「服务端权威字段」，
///      保留用户正在编辑的 title / content 等「本地锁定字段」。
class PullCoordinator {
  final Isar _isar;
  final SyncApiService _syncApi;
  static const String _tag = 'PullCoordinator';
  static const int _pageSize = 200;

  PullCoordinator({required Isar isar, required SyncApiService syncApi})
    : _isar = isar,
      _syncApi = syncApi;

  /// 返回当前用户最近一次成功 Pull 的游标。
  Future<int> getLastPulledVersion(String userId) async {
    final checkpoint = await _loadCheckpoint(userId);
    return checkpoint?.lastPulledVersion ?? 0;
  }

  /// 当前用户是否仍处于首次全量拉取前。
  Future<bool> isInitialPull(String userId) async {
    final version = await getLastPulledVersion(userId);
    return SyncCheckpointPolicy.isInitialPullVersion(version);
  }

  /// 执行一轮完整的增量 Pull。
  ///
  /// - 若 [SyncCheckpoint.lastPulledVersion] == 0，触发全量分页拉取。
  /// - 全量拉取期间由调用方（SyncEngine）将 SyncPhase 置为 initialPull，
  ///   note_providers 据此冻结 UI Watch 订阅，防止全量写入时 Widget 高频重绘。
  /// - 返回本次 Pull 到的最新 serverVersion，若无新数据则返回原游标值。
  Future<int> pull(String userId) async {
    final checkpoint = await _loadCheckpoint(userId);
    int cursor = checkpoint?.lastPulledVersion ?? 0;
    bool hasMore = true;

    PMlog.d(_tag, '开始 Pull，游标: $cursor');

    while (hasMore) {
      final response = await _syncApi.pull(
        sinceVersion: cursor,
        pageSize: _pageSize,
      );

      if (response.changes.isNotEmpty) {
        await _applyBatch(response.changes, userId);
      }

      // 整批成功写入后再推进游标（防崩溃数据空洞）
      cursor = response.serverVersion;
      await _saveCheckpoint(userId, cursor);

      hasMore = response.hasMore;
      PMlog.d(
        _tag,
        '本批 changes: ${response.changes.length}，新游标: $cursor，hasMore: $hasMore',
      );
    }

    return cursor;
  }

  // ─────────────────────────── Apply 逻辑 ───────────────────────────

  Future<void> _applyBatch(List<SyncChangeDto> changes, String userId) async {
    // 批量查询本地已有 UUID 对应的 pending mutations（减少 per-change DB 查询）
    final uuids = changes.map((c) => c.uuid).toSet().toList();
    final pendingUuids = await _findUuidsWithPendingMutations(uuids);

    // 单次大事务写入整批（全量 Pull 时减少事务次数，防低端机卡顿）
    await _isar.writeTxn(() async {
      for (final change in changes) {
        await _applyChange(change, pendingUuids);
      }
    });
  }

  /// 处理单条变更：分发到 Note 或 Category 的合并逻辑
  Future<void> _applyChange(
    SyncChangeDto change,
    Set<String> pendingUuids,
  ) async {
    switch (change.entityType) {
      case MutationEntityType.note:
        await _applyNoteChange(change, pendingUuids.contains(change.uuid));
        break;
      case MutationEntityType.category:
        await _applyCategoryChange(change, pendingUuids.contains(change.uuid));
        break;
      default:
        PMlog.w(_tag, '未知 entityType: ${change.entityType}，跳过');
    }
  }

  // ─────────────────────────── Note 合并 ───────────────────────────

  Future<void> _applyNoteChange(SyncChangeDto change, bool hasPending) async {
    if (change.operation == MutationOperation.delete) {
      // 删除操作：始终以服务端为准（防止本地复活已删除笔记）
      final local = await _isar.notes.getByUuid(change.uuid);
      if (local != null) {
        local
          ..isDeleted = true
          ..serverVersion = change.serverVersion;
        await _isar.notes.put(local);
      }
      return;
    }

    final local = await _isar.notes.getByUuid(change.uuid);

    if (local == null) {
      // 新实体：直接从 payload 构建并插入
      final note = NoteSyncPayloadMapper.createFromServerSnapshot(
        payload: change.payload,
        serverVersion: change.serverVersion,
      );
      final linkedCategory = await _isar.categorys.get(note.categoryId);
      note.category.value = linkedCategory;
      await _isar.notes.put(note);
      await note.category.save();
      return;
    }

    if (!hasPending) {
      // 本地干净（无 pending mutation）：粗粒度 LWW
      if (change.updatedAt >= local.updatedAt) {
        // 服务端胜：全字段覆盖（保留 Isar id 确保不重复插入）
        final updated = NoteSyncPayloadMapper.createFromServerSnapshot(
          payload: change.payload,
          serverVersion: change.serverVersion,
          fallbackPreviewImageUrl: local.previewImageUrl,
        )..id = local.id;
        final linkedCategory = await _isar.categorys.get(updated.categoryId);
        updated.category.value = linkedCategory;
        await _isar.notes.put(updated);
        await updated.category.save();
      } else {
        // 本地胜：仅更新 serverVersion，不覆盖内容
        local.serverVersion = change.serverVersion;
        await _isar.notes.put(local);
      }
    } else {
      // 本地有 pending mutation（用户正在编辑）：细粒度字段合并
      // 仅覆盖「服务端托管字段」，保留「本地锁定字段」
      _mergeServerManagedFields(local, change.payload);
      local.serverVersion = change.serverVersion;
      // 注意：local.updatedAt 保持本地值，确保下次 Push 时本地版本仍能胜出
      await _isar.notes.put(local);
    }
  }

  /// 将服务端托管字段合并到本地 Note。
  ///
  /// 这里的 `tags` 是混合来源字段：既可能来自用户手动维护，也可能来自 AI / 云端补全。
  /// 因此在本地仍有 pending mutation 时，不能直接让服务端覆盖，而要做“本地优先顺序的并集合并”。
  ///
  /// 绝对不触碰本地锁定字段（title / content / url / categoryId / time）。
  void _mergeServerManagedFields(Note local, Map<String, dynamic> p) {
    // 服务端托管字段（AI 管线和抓取任务写入，客户端可能只读或与本地做并集合并）
    if (p['aiSummary'] != null) local.aiSummary = p['aiSummary'] as String?;
    if (p['tags'] != null) {
      local.tags = TagListUtils.mergeLocalAndServer(
        localTags: local.tags,
        serverTags: p['tags'] as List<dynamic>,
      );
    }
    if (p['resourceStatus'] != null) {
      local.resourceStatus = p['resourceStatus'] as String?;
    }
    final serverPreviewTitle = p['previewTitle'] as String?;
    if (serverPreviewTitle != null && serverPreviewTitle.trim().isNotEmpty) {
      local.previewTitle = serverPreviewTitle;
    }
    final serverPreviewDescription = p['previewDescription'] as String?;
    if (serverPreviewDescription != null &&
        serverPreviewDescription.trim().isNotEmpty) {
      local.previewDescription = serverPreviewDescription;
    }
    final serverPreviewContent = p['previewContent'] as String?;
    if (serverPreviewContent != null &&
        serverPreviewContent.trim().isNotEmpty) {
      local.previewContent = serverPreviewContent;
    }
    if (p['previewImageUrl'] != null) {
      local.previewImageUrl = p['previewImageUrl'] as String?;
    }
    // 本地锁定字段（绑对注释，防止未来误加进来）：
    // ✋ title / content / url / categoryId / time
  }

  // ─────────────────────────── Category 合并 ───────────────────────────

  Future<void> _applyCategoryChange(
    SyncChangeDto change,
    bool hasPending,
  ) async {
    if (change.operation == MutationOperation.delete) {
      final local = await _isar.categorys.getByUuid(change.uuid);
      if (local != null) {
        local
          ..isDeleted = true
          ..serverVersion = change.serverVersion;
        await _isar.categorys.put(local);
      }
      return;
    }

    final local = await _isar.categorys.getByUuid(change.uuid);
    if (local == null) {
      final category = _categoryFromPayload(
        change.payload,
        change.serverVersion,
      );
      await _isar.categorys.put(category);
      return;
    }

    if (!hasPending || change.updatedAt >= local.updatedAt) {
      final updated = _categoryFromPayload(change.payload, change.serverVersion)
        ..id = local.id;
      await _isar.categorys.put(updated);
    } else {
      local.serverVersion = change.serverVersion;
      await _isar.categorys.put(local);
    }
  }

  // ─────────────────────────── 工具方法 ───────────────────────────

  Category _categoryFromPayload(Map<String, dynamic> p, int serverVersion) {
    final category = Category()
      ..uuid = p['uuid'] as String?
      ..name = (p['name'] as String?) ?? ''
      ..description = p['description'] as String?
      ..iconPath = p['iconPath'] as String?
      ..updatedAt = p['updatedAt'] as int? ?? 0
      ..isDeleted = p['isDeleted'] as bool? ?? false
      ..serverVersion = serverVersion;

    final createdMs = p['createdTime'] as int?;
    if (createdMs != null) {
      category.createdTime = DateTime.fromMillisecondsSinceEpoch(createdMs);
    }
    return category;
  }

  /// 查找给定 UUID 集合中哪些存在 pending mutation（批量查询，减少 IO）
  Future<Set<String>> _findUuidsWithPendingMutations(List<String> uuids) async {
    if (uuids.isEmpty) return {};
    final pending = await _isar.mutationEntrys
        .filter()
        .statusEqualTo(MutationStatus.pending)
        .and()
        .anyOf(uuids, (q, uuid) => q.entityUuidEqualTo(uuid))
        .findAll();
    return pending.map((m) => m.entityUuid).toSet();
  }

  Future<SyncCheckpoint?> _loadCheckpoint(String userId) async {
    return _isar.syncCheckpoints.getByUserId(userId);
  }

  Future<void> _saveCheckpoint(String userId, int version) async {
    final existing = await _isar.syncCheckpoints.getByUserId(userId);
    final checkpoint =
        existing ??
        (SyncCheckpoint()
          ..userId = userId
          ..lastPulledVersion = 0
          ..lastSyncedAt = 0);
    checkpoint
      ..lastPulledVersion = version
      ..lastSyncedAt = DateTime.now().millisecondsSinceEpoch;
    // 注意：此方法在事务外调用，自行开启事务
    await _isar.writeTxn(() async {
      await _isar.syncCheckpoints.put(checkpoint);
    });
  }
}
