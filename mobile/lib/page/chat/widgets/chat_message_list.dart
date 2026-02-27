import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/page/chat/chat_list/chat_list_formatter.dart';
import 'package:pocketmind/page/chat/chat_list/chat_list_item.dart';
import 'package:pocketmind/page/chat/widgets/chat_common_widgets.dart';
import 'package:pocketmind/page/chat/widgets/chat_message_widgets.dart';
import 'package:pocketmind/providers/chat_providers.dart';
import 'package:pocketmind/util/theme_data.dart';

/// 聊天消息列表。
class ChatMessageList extends ConsumerWidget {
  final String sessionUuid;
  final ScrollController scrollController;
  final AsyncValue<List<ChatMessage>> asyncValue;
  final ChatSendState sendState;
  final ChatBubbleColors colors;
  final void Function(String uuid, String content) onStartEdit;

  const ChatMessageList({
    super.key,
    required this.sessionUuid,
    required this.scrollController,
    required this.asyncValue,
    required this.sendState,
    required this.colors,
    required this.onStartEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return asyncValue.when(
      data: (messages) {
        final items = buildChatListItems(
          messages: messages,
          sendState: sendState,
        );
        if (items.isEmpty) {
          return const ChatEmptyHint();
        }
        return ListView.builder(
          controller: scrollController,
          padding: EdgeInsets.only(
            left: 16.w,
            right: 16.w,
            top: 12.h,
            bottom: 8.h,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item = items[i];
            return _buildItem(context, ref, item);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          '加载失败，请重试',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, WidgetRef ref, ChatListItem item) {
    switch (item) {
      case ChatListTimeDivider(:final time):
        return ChatTimeDivider(time: time, colors: colors);
      case ChatListMessageItem(
        :final message,
        :final isLeaf,
        :final isLastUserMsg,
      ):
        return ChatMessageBubble(
          message: message,
          colors: colors,
          sessionUuid: sessionUuid,
          isLeaf: isLeaf,
          isLastUserMsg: isLastUserMsg,
          onEditTap: isLastUserMsg ? onStartEdit : null,
        );
      case ChatListPendingUserItem(:final content):
        return ChatPendingUserBubble(content: content, colors: colors);
      case ChatListStreamingItem(:final content):
        return ChatStreamingBubble(content: content, colors: colors);
      case ChatListErrorItem():
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Center(
            child: InkWell(
              onTap: () =>
                  ref.read(chatSendProvider(sessionUuid).notifier).reset(),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '回复失败，点击关闭',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ),
          ),
        );
    }
  }
}
