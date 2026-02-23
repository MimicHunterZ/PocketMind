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
      ..isDeleted = false;
  }
}
