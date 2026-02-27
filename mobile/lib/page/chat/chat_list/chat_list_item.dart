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

  const ChatListMessageItem({
    required this.message,
    required this.isLeaf,
    required this.isLastUserMsg,
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
