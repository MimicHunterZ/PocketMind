import 'package:pocketmind/model/chat_message.dart';

/// 聊天列表项基类（仅描述数据，不包含 UI 组件）。
sealed class ChatListItem {
  const ChatListItem();
}

/// 时间分割线。
class ChatListTimeDivider extends ChatListItem {
  final DateTime time;

  const ChatListTimeDivider(this.time);
}

/// 常规消息项。
class ChatListMessageItem extends ChatListItem {
  final ChatMessage message;
  final bool isLeaf;
  final bool isLastUserMsg;

  /// 是否是这一轮 AI 回复(下一条 USER 消息之前的最后一块)的最后一块。
  /// 一轮回复可能是"文本+工具调用+文本+卡片"的块序列,复制/点赞/分支这些
  /// 操作按钮只应在整轮回复结束后、挂在最后一块上,不应该在中间块上出现。
  final bool isLastOfTurn;

  const ChatListMessageItem({
    required this.message,
    required this.isLeaf,
    required this.isLastUserMsg,
    required this.isLastOfTurn,
  });
}

/// 待发送用户消息占位。
class ChatListPendingUserItem extends ChatListItem {
  final String content;

  const ChatListPendingUserItem(this.content);
}

/// 流式回复占位。
class ChatListStreamingItem extends ChatListItem {
  final String content;

  const ChatListStreamingItem(this.content);
}

/// 列表尾部错误提示。
class ChatListErrorItem extends ChatListItem {
  const ChatListErrorItem();
}
