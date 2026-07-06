import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/providers/chat_providers.dart' show ChatLiveBlock;

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

  /// 仅对 A2UI 卡片(TOOL_RESULT)有意义:非 null 表示这张卡片已经有对应的
  /// "提交交互"消息,应锁定并用这份 dataModel 定格显示;null 表示未提交,
  /// 保持可交互,或者这条消息本来就不是卡片。
  final Map<String, dynamic>? lockedDataModel;

  const ChatListMessageItem({
    required this.message,
    required this.isLeaf,
    required this.isLastUserMsg,
    required this.isLastOfTurn,
    this.lockedDataModel,
  });
}

/// 待发送用户消息占位。
class ChatListPendingUserItem extends ChatListItem {
  final String content;

  const ChatListPendingUserItem(this.content);
}

/// 流式回复占位：一轮回复还在直播的块序列（文本+工具进度+A2UI 卡片，
/// 按到达顺序追加）。
class ChatListStreamingItem extends ChatListItem {
  final List<ChatLiveBlock> blocks;

  const ChatListStreamingItem(this.blocks);
}

/// 列表尾部错误提示。
class ChatListErrorItem extends ChatListItem {
  const ChatListErrorItem();
}
