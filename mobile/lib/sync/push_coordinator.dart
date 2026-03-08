import 'dart:async';
import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:pocketmind/api/sync_api_service.dart';
import 'package:pocketmind/model/category.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/sync/model/mutation_entry.dart';
import 'package:pocketmind/sync/model/sync_dto.dart';
import 'package:pocketmind/sync/note_sync_payload_mapper.dart';
import 'package:pocketmind/util/logger_service.dart';

/// Push 协调器 —— 将本地 MutationQueue 中 pending 条目批量推送至服务端。
///
/// 核心行为：
/// 1. 读取所有 status=pending 的 [MutationEntry]，按 id 升序（保持写入顺序）批量 Push。
/// 2. 以 [MutationEntry.mutationId] 作为幂等键，后端保证多次提交同一 mutationId 只处理一次。
/// 3. 根据服务端每条结果的不同状态执行相应的本地操作：
///    - accepted=true ➜ status=synced，写入 serverVersion
///    - 409 conflict ➜ 以服务端权威版本覆盖本地，删除该 mutation
///    - 4xx (永久拒绝) ➜ status=failed，记录 failReason
///    - 5xx / 网络异常 ➜ 指数退避重试，超 [MutationStatus.maxRetries] 置 failed
class PushCoordinator {
  final Isar _isar;
  final SyncApiService _syncApi;
  static const String _tag = 'PushCoordinator';

  /// 每批 Push 的最大条目数（防止单次请求过大）
  static const int _batchSize = 50;

  /// 指数退避基础间隔（毫秒），每次 *2，上限 30 分钟
  static const int _backoffBaseMs = 2000;
  static const int _backoffMaxMs = 30 * 60 * 1000;

  PushCoordinator({required Isar isar, required SyncApiService syncApi})
    : _isar = isar,
      _syncApi = syncApi;

  /// 执行一轮 Push：读取所有 pending mutations，分批推送，处理返回结果。
  ///
  /// 若当前无 pending mutations，立即返回（无网络请求）。
  Future<void> push() async {
    await _recoverInterruptedPushes();

    final pendingList =
        (await _isar.mutationEntrys
              .filter()
              .statusEqualTo(MutationStatus.pending)
              .findAll())
          ..sort((a, b) => a.id.compareTo(b.id)); // 按写入顺序排序

    if (pendingList.isEmpty) {
      PMlog.d(_tag, '无 pending mutations，跳过 Push');
      return;
    }

    PMlog.d(_tag, '开始 Push，共 ${pendingList.length} 条 mutations');

    // 将 pushing 状态挂起，防止并发 Push 重复提交
    await _markAsPushing(pendingList);

    // 分批处理
    for (int i = 0; i < pendingList.length; i += _batchSize) {
      final batch = pendingList.sublist(
        i,
        (i + _batchSize).clamp(0, pendingList.length),
      );
      await _pushBatch(batch);
    }
  }

  /// 恢复上次异常中断遗留的 `pushing` 状态。
  ///
  /// `pushing` 只是进程内飞行态，不应跨进程持久化为终态。
  /// 若应用在提交中崩溃，下一轮 Push 前统一回退为 `pending`。
  Future<void> _recoverInterruptedPushes() async {
    final interrupted = await _isar.mutationEntrys
        .filter()
        .statusEqualTo(MutationStatus.pushing)
        .findAll();
    if (interrupted.isEmpty) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await _isar.writeTxn(() async {
      for (final mutation in interrupted) {
        mutation
          ..status = MutationStatus.pending
          ..lastAttemptAt = now;
        await _isar.mutationEntrys.put(mutation);
      }
    });
    PMlog.w(_tag, '恢复了 ${interrupted.length} 条中断的 pushing mutation');
  }

  Future<void> _pushBatch(List<MutationEntry> batch) async {
    final dtos = batch.map((m) {
      final payloadMap = jsonDecode(m.payload) as Map<String, dynamic>;
      return SyncMutationDto(
        mutationId: m.mutationId,
        entityType: m.entityType,
        entityUuid: m.entityUuid,
        operation: m.operation,
        updatedAt: m.updatedAt,
        payload: payloadMap,
      );
    }).toList();

    try {
      final results = await _syncApi.push(SyncPushRequest(mutations: dtos));
      // 建立 mutationId → result 映射
      final resultMap = {for (final r in results) r.mutationId: r};
      await _processBatchResults(batch, resultMap);
    } catch (e) {
      // 网络异常：整批回退为 pending，增加重试计数
      PMlog.e(_tag, 'Push 网络请求失败: $e，批次 ${batch.length} 条回退 pending');
      await _handleBatchNetworkFailure(batch);
    }
  }

  Future<void> _processBatchResults(
    List<MutationEntry> batch,
    Map<String, SyncPushResult> resultMap,
  ) async {
    await _isar.writeTxn(() async {
      for (final mutation in batch) {
        final result = resultMap[mutation.mutationId];
        if (result == null) {
          // 服务端未返回此 mutationId 的结果（异常），回退 pending
          mutation
            ..status = MutationStatus.pending
            ..lastAttemptAt = DateTime.now().millisecondsSinceEpoch;
          await _isar.mutationEntrys.put(mutation);
          continue;
        }

        if (result.accepted) {
          // ✅ 接受：标记 synced，写回 serverVersion 到对应业务实体
          mutation.status = MutationStatus.synced;
          await _isar.mutationEntrys.put(mutation);
          if (result.serverVersion != null) {
            await _updateEntityServerVersion(
              mutation.entityType,
              mutation.entityUuid,
              result.serverVersion!,
            );
          }
        } else if (result.conflictEntity != null) {
          // ⚡ 409 冲突：服务端版本更新，以服务端权威数据覆盖本地，删除该 mutation
          await _applyConflictResolution(mutation, result.conflictEntity!);
          await _isar.mutationEntrys.delete(mutation.id);
        } else if (result.retryable) {
          _scheduleRetry(mutation, result.rejectReason ?? '服务端暂时不可用');
          await _isar.mutationEntrys.put(mutation);
        } else {
          // ❌ 4xx 永久拒绝：标记 failed，记录原因
          mutation
            ..status = MutationStatus.failed
            ..failReason = result.rejectReason ?? '服务端永久拒绝'
            ..lastAttemptAt = DateTime.now().millisecondsSinceEpoch;
          await _isar.mutationEntrys.put(mutation);
          PMlog.w(
            _tag,
            'mutation ${mutation.mutationId} 永久失败: ${mutation.failReason}',
          );
        }
      }
    });
  }

  void _scheduleRetry(MutationEntry mutation, String reason) {
    mutation
      ..retries = mutation.retries + 1
      ..lastAttemptAt = DateTime.now().millisecondsSinceEpoch;

    if (mutation.retries > MutationStatus.maxRetries) {
      mutation
        ..status = MutationStatus.failed
        ..failReason = reason;
      PMlog.w(
        _tag,
        'mutation ${mutation.mutationId} 瞬时失败次数超限，转为 failed: $reason',
      );
      return;
    }

    mutation
      ..status = MutationStatus.pending
      ..failReason = reason;
    PMlog.w(_tag, 'mutation ${mutation.mutationId} 瞬时失败，将重试: $reason');
  }

  Future<void> _handleBatchNetworkFailure(List<MutationEntry> batch) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _isar.writeTxn(() async {
      for (final mutation in batch) {
        mutation.retries++;
        mutation.lastAttemptAt = now;

        if (mutation.retries >= MutationStatus.maxRetries) {
          mutation
            ..status = MutationStatus.failed
            ..failReason = '超过最大重试次数（${MutationStatus.maxRetries}）';
          PMlog.w(_tag, 'mutation ${mutation.mutationId} 超限，标记 failed');
        } else {
          // 回退为 pending（指数退避由 SyncEngine 的调度间隔实现）
          mutation.status = MutationStatus.pending;
          PMlog.d(
            _tag,
            'mutation ${mutation.mutationId} 回退 pending，重试次数: ${mutation.retries}',
          );
        }
        await _isar.mutationEntrys.put(mutation);
      }
    });
  }

  Future<void> _markAsPushing(List<MutationEntry> list) async {
    await _isar.writeTxn(() async {
      for (final m in list) {
        m.status = MutationStatus.pushing;
        await _isar.mutationEntrys.put(m);
      }
    });
  }

  Future<void> _updateEntityServerVersion(
    String entityType,
    String uuid,
    int serverVersion,
  ) async {
    if (entityType == MutationEntityType.note) {
      final note = await _isar.notes.getByUuid(uuid);
      if (note != null) {
        note.serverVersion = serverVersion;
        await _isar.notes.put(note);
      }
    } else if (entityType == MutationEntityType.category) {
      final category = await _isar.categorys.getByUuid(uuid);
      if (category != null) {
        category.serverVersion = serverVersion;
        await _isar.categorys.put(category);
      }
    }
  }

  /// 409 冲突回滚：用服务端权威数据完整覆盖本地实体
  Future<void> _applyConflictResolution(
    MutationEntry mutation,
    Map<String, dynamic> serverEntity,
  ) async {
    if (mutation.entityType == MutationEntityType.note) {
      final local = await _isar.notes.getByUuid(mutation.entityUuid);
      if (local == null) return;
      // 提取服务端字段逐一覆盖（保留 Isar id）
      _overwriteNoteFromServer(local, serverEntity);
      await _isar.notes.put(local);
      PMlog.d(_tag, 'Note ${mutation.entityUuid} 409 回滚为服务端版本');
      return;
    }

    if (mutation.entityType == MutationEntityType.category) {
      final local = await _isar.categorys.getByUuid(mutation.entityUuid);
      if (local == null) return;
      _overwriteCategoryFromServer(local, serverEntity);
      await _isar.categorys.put(local);
      PMlog.d(_tag, 'Category ${mutation.entityUuid} 409 回滚为服务端版本');
    }
  }

  void _overwriteNoteFromServer(dynamic note, Map<String, dynamic> p) {
    NoteSyncPayloadMapper.applyServerSnapshot(
      target: note as Note,
      payload: p,
      serverVersion: p['serverVersion'] as int? ?? note.serverVersion ?? 0,
    );
  }

  void _overwriteCategoryFromServer(dynamic category, Map<String, dynamic> p) {
    category
      ..name = p['name'] ?? category.name
      ..description = p['description']
      ..iconPath = p['iconPath']
      ..updatedAt = p['updatedAt'] ?? category.updatedAt
      ..isDeleted = p['isDeleted'] ?? category.isDeleted
      ..serverVersion = p['serverVersion'];
  }

  /// 计算指数退避等待时间（毫秒），以重试次数为参数
  static Duration backoffDuration(int retries) {
    final ms = (_backoffBaseMs * (1 << retries.clamp(0, 14))).clamp(
      0,
      _backoffMaxMs,
    );
    return Duration(milliseconds: ms);
  }

  /// 查询 failed mutations 数量（供 SyncStateProvider 展示角标）
  Future<int> getFailedCount() async {
    return _isar.mutationEntrys
        .filter()
        .statusEqualTo(MutationStatus.failed)
        .count();
  }

  /// 查询 pending mutations 数量（供 SyncStateProvider 展示角标）
  Future<int> getPendingCount() async {
    return _isar.mutationEntrys
        .filter()
        .statusEqualTo(MutationStatus.pending)
        .count();
  }
}
