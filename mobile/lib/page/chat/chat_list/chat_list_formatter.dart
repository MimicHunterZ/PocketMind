import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/page/chat/chat_list/chat_list_item.dart';
import 'package:pocketmind/providers/chat_providers.dart';
import 'package:pocketmind/util/a2ui_card_util.dart';

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

  // 卡片提交锁定:只要消息列表里存在一条能解析成功的"提交交互"消息,该
  // surfaceId 对应的卡片就锁定。surfaceId 由卡片自己生成,不可能被提前
  // 提交,所以不必强制要求这条消息排在卡片之后。
  //
  // 提交消息本身是 content 为 {surfaceId, dataModel} JSON 的 USER 消息,只作为
  // 锁定态的数据来源和喂模型的历史,不作为气泡渲染(卡片已定格显示选择),
  // 因此收集它们的 uuid,渲染时跳过。
  final lockedDataModelBySurfaceId = <String, Map<String, dynamic>>{};
  final submissionUuids = <String>{};
  for (final message in messages) {
    if (message.role != 'USER' || message.messageType != 'TEXT') continue;
    final submission = tryParseA2uiSubmission(message.content);
    if (submission != null) {
      lockedDataModelBySurfaceId[submission.surfaceId] = submission.dataModel;
      submissionUuids.add(message.uuid);
    }
  }

  // 最后一条 USER 消息(可编辑)不算提交消息——提交消息不作为气泡,也不该拿到
  // 编辑入口。
  String? lastUserMsgUuid;
  for (final message in messages) {
    if (message.role == 'USER' && !submissionUuids.contains(message.uuid)) {
      lastUserMsgUuid = message.uuid;
    }
  }

  for (var i = 0; i < messages.length; i++) {
    final message = messages[i];
    // 提交交互消息只驱动锁定态,不渲染成气泡。
    if (submissionUuids.contains(message.uuid)) continue;

    final ts = DateTime.fromMillisecondsSinceEpoch(message.updatedAt);
    if (lastTime == null || ts.difference(lastTime).abs().inMinutes >= 5) {
      items.add(ChatListTimeDivider(ts));
    }
    lastTime = ts;

    // 一轮的结尾:下一条非提交消息是 USER,或后面没有更多可见消息。跳过被隐藏的
    // 提交消息,避免它把上一块误判成 turn 结尾。
    var next = i + 1;
    while (next < messages.length &&
        submissionUuids.contains(messages[next].uuid)) {
      next++;
    }
    final isLastOfTurn =
        next == messages.length || messages[next].role == 'USER';

    Map<String, dynamic>? lockedDataModel;
    if (message.messageType == 'TOOL_RESULT') {
      final operations = tryParseA2uiCard(message.content);
      if (operations != null) {
        lockedDataModel =
            lockedDataModelBySurfaceId[a2uiSurfaceId(operations)];
      }
    }

    items.add(
      ChatListMessageItem(
        message: message,
        isLeaf: !parentUuidSet.contains(message.uuid),
        isLastUserMsg: message.uuid == lastUserMsgUuid,
        isLastOfTurn: isLastOfTurn,
        lockedDataModel: lockedDataModel,
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
    items.add(ChatListStreamingItem(sendState.blocks));
  }

  if (sendState is ChatSendError) {
    items.add(const ChatListErrorItem());
  }

  return items;
}
