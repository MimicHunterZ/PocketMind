import 'package:isar_community/isar.dart';

part 'chat_session.g.dart';

/// 聊天会话，对应后端 chat_sessions 表。
@collection
class ChatSession {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  /// 关联笔记 UUID，null = 全局会话
  @Index()
  String? scopeNoteUuid;

  String? title;

  /// 最后更新时间戳（毫秒），用于同步
  @Index()
  int updatedAt = 0;

  bool isDeleted = false;

  /// 当前激活的叶子节点 UUID；null = 主线（最新一条消息）
  /// 仅本地使用，不同步后端
  String? activeLeafUuid;
}
