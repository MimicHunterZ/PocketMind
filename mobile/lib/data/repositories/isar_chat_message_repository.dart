import 'package:isar_community/isar.dart';
import 'package:pocketmind/api/models/chat_models.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/util/logger_service.dart';

/// Isar 聊天消息仓库。
///
/// 封装所有与 Isar 相关的 [ChatMessage] 数据访问逻辑。
class IsarChatMessageRepository {
  final Isar _isar;
  static const String _tag = 'IsarChatMessageRepository';

  IsarChatMessageRepository(this._isar);

  // 查询 / 监听

  /// 实时监听指定会话的消息列表，按 [ChatMessage.updatedAt] 升序（时间轴顺序）。
  Stream<List<ChatMessage>> watchBySessionUuid(String sessionUuid) {
    return _isar.chatMessages
        .filter()
        .sessionUuidEqualTo(sessionUuid)
        .and()
        .isDeletedEqualTo(false)
        .sortByUpdatedAt()
        .watch(fireImmediately: true);
  }

  /// 实时监听单条消息（用于 AppBar 分支标签获取 branchAlias）。
  Stream<ChatMessage?> watchByUuid(String uuid) {
    return _isar.chatMessages
        .filter()
        .uuidEqualTo(uuid)
        .watch(fireImmediately: true)
        .map((list) => list.isEmpty ? null : list.first);
  }

  /// 按 UUID 一次性查找单条消息。
  Future<ChatMessage?> findByUuid(String uuid) {
    return _isar.chatMessages.filter().uuidEqualTo(uuid).findFirst();
  }

  /// 监听特定叶子节点所在的分支消息链（从根到叶，升序）。
  ///
  /// 通过加载会话全量消息，在内存中沿 [ChatMessage.parentUuid] 向上回溯，
  /// 每次 Isar 数据变化时重新计算链路。
  Stream<List<ChatMessage>> watchByLeafUuid(
    String sessionUuid,
    String leafUuid,
  ) {
    return _isar.chatMessages
        .filter()
        .sessionUuidEqualTo(sessionUuid)
        .and()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((allMessages) {
          final map = {for (final m in allMessages) m.uuid: m};
          final chain = <ChatMessage>[];
          String? current = leafUuid;
          while (current != null) {
            final msg = map[current];
            if (msg == null) break;
            chain.add(msg);
            current = msg.parentUuid;
          }
          return chain.reversed.toList();
        });
  }

  // 写入

  /// 将服务端返回的消息列表全量 upsert（有则更新，无则插入）。
  ///
  /// 通常在收到 [ChatDoneEvent] 后调用，将完整历史消息写入本地。
  Future<void> upsertFromModels(List<ChatMessageModel> models) async {
    final messages = models.map(_fromModel).toList();
    await _isar.writeTxn(() async {
      for (final m in messages) {
        final existing = await _isar.chatMessages
            .filter()
            .uuidEqualTo(m.uuid)
            .findFirst();
        if (existing != null) {
          m.id = existing.id;
        }
        await _isar.chatMessages.put(m);
      }
    });
    PMlog.d(_tag, 'upsert ${messages.length} 条消息');
  }

  /// 软删除指定 UUID 列表对应的本地消息。
  Future<void> softDeleteByUuids(List<String> uuids) async {
    await _isar.writeTxn(() async {
      for (final uuid in uuids) {
        final msg = await _isar.chatMessages
            .filter()
            .uuidEqualTo(uuid)
            .findFirst();
        if (msg != null) {
          msg.isDeleted = true;
          await _isar.chatMessages.put(msg);
        }
      }
    });
    PMlog.d(_tag, '软删除 ${uuids.length} 条消息');
  }

  /// 软删除指定父节点的所有 ASSISTANT 子消息（编辑用户消息后清理旧 AI 回复）。
  Future<void> softDeleteAssistantChildrenOf(String parentUuid) async {
    await _isar.writeTxn(() async {
      final children = await _isar.chatMessages
          .filter()
          .parentUuidEqualTo(parentUuid)
          .and()
          .roleEqualTo('ASSISTANT')
          .and()
          .isDeletedEqualTo(false)
          .findAll();
      for (final m in children) {
        m.isDeleted = true;
        await _isar.chatMessages.put(m);
      }
    });
    PMlog.d(_tag, '清理父节点 $parentUuid 的 ASSISTANT 子消息');
  }

  /// 更新本地消息的评分。
  Future<void> upsertRating(String uuid, int rating) async {
    await _isar.writeTxn(() async {
      final msg = await _isar.chatMessages
          .filter()
          .uuidEqualTo(uuid)
          .findFirst();
      if (msg != null) {
        msg.rating = rating;
        await _isar.chatMessages.put(msg);
      }
    });
    PMlog.d(_tag, '更新消息 $uuid 评分 -> $rating');
  }

  /// 更新本地消息内容（编辑后覆盖）。
  Future<void> updateContent(String uuid, String content) async {
    await _isar.writeTxn(() async {
      final msg = await _isar.chatMessages
          .filter()
          .uuidEqualTo(uuid)
          .findFirst();
      if (msg != null) {
        msg.content = content;
        msg.updatedAt = DateTime.now().millisecondsSinceEpoch;
        await _isar.chatMessages.put(msg);
      }
    });
    PMlog.d(_tag, '更新消息 $uuid 内容');
  }

  /// 更新本地消息的分支别名（最多 10 个字符）。
  Future<void> updateBranchAlias(String uuid, String alias) async {
    await _isar.writeTxn(() async {
      final msg = await _isar.chatMessages
          .filter()
          .uuidEqualTo(uuid)
          .findFirst();
      if (msg != null) {
        msg.branchAlias = alias;
        await _isar.chatMessages.put(msg);
      }
    });
    PMlog.d(_tag, '更新消息 $uuid 分支别名: $alias');
  }

  // 私有工具

  /// 将 API 响应模型转换为 Isar 持久化模型。
  ///
  /// 注意：[ChatMessageModel.createdAt] 作为本地 updatedAt 存储，
  /// 因为后端消息一经创建不会被修改，两者等价。
  static ChatMessage _fromModel(ChatMessageModel m) {
    return ChatMessage()
      ..uuid = m.uuid
      ..sessionUuid = m.sessionUuid
      ..parentUuid = m.parentUuid
      ..messageType = m.messageType
      ..role = m.role
      ..content = m.content
      ..attachmentUuids = m.attachmentUuids
      ..updatedAt = m.createdAt
      ..rating = m.rating
      ..branchAlias = m.branchAlias
      ..isDeleted = false;
  }
}
