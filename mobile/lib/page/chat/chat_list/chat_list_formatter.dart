import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/page/chat/chat_list/chat_list_item.dart';
import 'package:pocketmind/providers/chat_providers.dart';

/// 构建聊天列表描述数据。
///
/// 该函数仅做数据组装，不依赖 BuildContext，便于单元测试。
List<ChatListItem> buildChatListItems({
  required List<ChatMessage> messages,
  required ChatSendState sendState,
  DateTime Function()? nowProvider,
}) {
  final items = <ChatListItem>[];
  DateTime? lastTime;

  final parentUuidSet = messages
      .map((m) => m.parentUuid)
      .whereType<String>()
      .toSet();

  String? lastUserMsgUuid;
  for (final message in messages) {
    if (message.role == 'USER') {
      lastUserMsgUuid = message.uuid;
    }
  }

  for (final message in messages) {
    final ts = DateTime.fromMillisecondsSinceEpoch(message.updatedAt);
    if (lastTime == null || ts.difference(lastTime).abs().inMinutes >= 5) {
      items.add(ChatListTimeDivider(ts));
    }
    lastTime = ts;

    items.add(
      ChatListMessageItem(
        message: message,
        isLeaf: !parentUuidSet.contains(message.uuid),
        isLastUserMsg: message.uuid == lastUserMsgUuid,
      ),
    );
  }

  if (sendState is ChatSendStreaming) {
    final now = (nowProvider ?? DateTime.now).call();
    if (lastTime == null || now.difference(lastTime).abs().inMinutes >= 5) {
      items.add(ChatListTimeDivider(now));
    }

    if (sendState.pendingUserMessage.isNotEmpty) {
      items.add(ChatListPendingUserItem(sendState.pendingUserMessage));
    }
    items.add(ChatListStreamingItem(sendState.content));
  }

  if (sendState is ChatSendError) {
    items.add(const ChatListErrorItem());
  }

  return items;
}
