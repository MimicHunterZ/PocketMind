import 'package:isar_community/isar.dart';

part 'chat_message.g.dart';

/// 聊天消息，对应后端 chat_messages 表。
@collection
class ChatMessage {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  /// 所属会话 UUID
  @Index()
  late String sessionUuid;

  /// 链表结构，指向上一条消息的 UUID，null = 链头
  String? parentUuid;

  /// 消息类型：TEXT | TOOL_CALL | TOOL_RESULT
  String messageType = 'TEXT';

  /// 消息角色：USER | ASSISTANT | SYSTEM | TOOL_CALL | TOOL_RESULT
  late String role;

  String content = '';

  /// 消息中引用的资产 UUID 列表
  List<String> attachmentUuids = [];

  /// 最后更新时间戳（毫秒）
  int updatedAt = 0;

  bool isDeleted = false;

  /// 评分：1=点赞, 0=未评, -1=点踩
  int rating = 0;

  /// 分支别名（AI 自动生成，4-8 汉字），仅叶子节点有值
  String? branchAlias;
}
