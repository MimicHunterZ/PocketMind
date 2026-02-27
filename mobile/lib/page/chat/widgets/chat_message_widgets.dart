import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/page/chat/widgets/chat_branch_sheet.dart';
import 'package:pocketmind/page/widget/creative_toast.dart';
import 'package:pocketmind/page/widget/markdown_text.dart';
import 'package:pocketmind/providers/chat_providers.dart';
import 'package:pocketmind/util/theme_data.dart';

/// 单条消息气泡。
class ChatMessageBubble extends ConsumerWidget {
  final ChatMessage message;
  final ChatBubbleColors colors;
  final String sessionUuid;
  final bool isLeaf;
  final bool isLastUserMsg;
  final void Function(String uuid, String content)? onEditTap;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.colors,
    required this.sessionUuid,
    required this.isLeaf,
    required this.isLastUserMsg,
    this.onEditTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == 'USER';
    final textTheme = Theme.of(context).textTheme;

    if (message.messageType == 'TOOL_CALL' ||
        message.messageType == 'TOOL_RESULT') {
      return ChatToolCallCard(message: message);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ChatBubbleShape(
                  isUser: isUser,
                  colors: colors,
                  child: isUser
                      ? SelectableText(
                          message.content,
                          style: textTheme.bodyLarge?.copyWith(
                            color: colors.userBubbleText,
                          ),
                        )
                      : MarkdownText(
                          data: message.content,
                          baseStyle: textTheme.bodyLarge?.copyWith(
                            color: colors.assistantBubbleText,
                          ),
                        ),
                ),
                SizedBox(height: 4.h),
                ChatMessageActionBar(
                  message: message,
                  sessionUuid: sessionUuid,
                  isUser: isUser,
                  isLeaf: isLeaf,
                  isLastUserMsg: isLastUserMsg,
                  onEditStart: isUser && onEditTap != null
                      ? () => onEditTap!(message.uuid, message.content)
                      : null,
                ),
              ],
            ),
          ),
          if (isUser) SizedBox(width: 4.w),
        ],
      ),
    );
  }
}

/// 用户消息乐观展示气泡（等待 Isar 落库期间的占位）。
class ChatPendingUserBubble extends StatelessWidget {
  final String content;
  final ChatBubbleColors colors;

  const ChatPendingUserBubble({
    super.key,
    required this.content,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: ChatBubbleShape(
              isUser: true,
              colors: colors,
              child: SelectableText(
                content,
                style: textTheme.bodyLarge?.copyWith(
                  color: colors.userBubbleText,
                ),
              ),
            ),
          ),
          SizedBox(width: 4.w),
        ],
      ),
    );
  }
}

/// 流式打字气泡。
class ChatStreamingBubble extends StatefulWidget {
  final String content;
  final ChatBubbleColors colors;

  const ChatStreamingBubble({
    super.key,
    required this.content,
    required this.colors,
  });

  @override
  State<ChatStreamingBubble> createState() => _ChatStreamingBubbleState();
}

class _ChatStreamingBubbleState extends State<ChatStreamingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: ChatBubbleShape(
              isUser: false,
              colors: widget.colors,
              child: widget.content.isEmpty
                  ? _DotsIndicator(
                      ctrl: _dotCtrl,
                      color: widget.colors.streamingDot,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MarkdownText(
                          data: widget.content,
                          isStreaming: true,
                          baseStyle: textTheme.bodyLarge?.copyWith(
                            color: widget.colors.assistantBubbleText,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        _DotsIndicator(
                          ctrl: _dotCtrl,
                          color: widget.colors.streamingDot,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 工具调用消息卡片。
class ChatToolCallCard extends StatelessWidget {
  final ChatMessage message;

  const ChatToolCallCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isCall = message.messageType == 'TOOL_CALL';

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h, left: 36.w, right: 36.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: cs.outline.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCall
                  ? Icons.engineering_outlined
                  : Icons.check_circle_outline_rounded,
              size: 14.sp,
              color: cs.tertiary,
            ),
            SizedBox(width: 6.w),
            Flexible(
              child: Text(
                isCall ? '调用工具中…' : '工具执行完成',
                style: textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatBubbleShape extends StatelessWidget {
  final bool isUser;
  final ChatBubbleColors colors;
  final Widget child;

  const ChatBubbleShape({
    super.key,
    required this.isUser,
    required this.colors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final shadowColor = Theme.of(context).shadowColor;
    const r = Radius.circular(18);
    const userShape = BorderRadius.only(
      topLeft: r,
      topRight: r,
      bottomLeft: r,
      bottomRight: Radius.circular(4),
    );
    const aiShape = BorderRadius.only(
      topLeft: Radius.circular(4),
      topRight: r,
      bottomLeft: r,
      bottomRight: r,
    );

    return Container(
      constraints: BoxConstraints(maxWidth: 0.72.sw),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isUser ? colors.userBubble : colors.assistantBubble,
        borderRadius: isUser ? userShape : aiShape,
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class ChatMessageActionBar extends ConsumerWidget {
  final ChatMessage message;
  final String sessionUuid;
  final bool isUser;
  final bool isLeaf;
  final bool isLastUserMsg;
  final VoidCallback? onEditStart;

  const ChatMessageActionBar({
    super.key,
    required this.message,
    required this.sessionUuid,
    required this.isUser,
    required this.isLeaf,
    required this.isLastUserMsg,
    this.onEditStart,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final notifier = ref.read(chatSendProvider(sessionUuid).notifier);
    final isSending =
        ref.watch(chatSendProvider(sessionUuid)) is ChatSendStreaming;

    void copyContent() {
      Clipboard.setData(ClipboardData(text: message.content));
      CreativeToast.success(
        context,
        title: '已复制',
        message: '内容已复制到剪贴板',
        direction: ToastDirection.bottom,
      );
    }

    void rateMessage(int rating) {
      final newRating = message.rating == rating ? 0 : rating;
      notifier.rateMessage(message.uuid, newRating);
    }

    Future<void> openBranchSheet() async {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        builder: (ctx) =>
            ChatBranchSheet(sessionUuid: sessionUuid, parentUuid: message.uuid),
      );
    }

    final iconColor = cs.onSurfaceVariant.withValues(alpha: 0.7);
    final iconSize = 18.sp;

    if (isUser) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionIconButton(
            icon: Icons.copy_outlined,
            size: iconSize,
            color: iconColor,
            tooltip: '复制',
            onTap: isSending ? null : copyContent,
          ),
          if (isLastUserMsg)
            _ActionIconButton(
              icon: Icons.edit_outlined,
              size: iconSize,
              color: iconColor,
              tooltip: '编辑',
              onTap: (isSending || onEditStart == null) ? null : onEditStart,
            ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionIconButton(
          icon: Icons.copy_outlined,
          size: iconSize,
          color: iconColor,
          tooltip: '复制',
          onTap: isSending ? null : copyContent,
        ),
        _ActionIconButton(
          icon: message.rating == 1
              ? Icons.thumb_up_alt
              : Icons.thumb_up_alt_outlined,
          size: iconSize,
          color: message.rating == 1 ? cs.primary : iconColor,
          tooltip: '点赞',
          onTap: isSending ? null : () => rateMessage(1),
        ),
        _ActionIconButton(
          icon: message.rating == -1
              ? Icons.thumb_down_alt
              : Icons.thumb_down_alt_outlined,
          size: iconSize,
          color: message.rating == -1 ? cs.error : iconColor,
          tooltip: '点踩',
          onTap: isSending ? null : () => rateMessage(-1),
        ),
        if (isLeaf)
          _ActionIconButton(
            icon: Icons.refresh_rounded,
            size: iconSize,
            color: iconColor,
            tooltip: '重新生成',
            onTap: isSending ? null : () => notifier.regenerate(message.uuid),
          ),
        _ActionIconButton(
          icon: Icons.account_tree_outlined,
          size: iconSize,
          color: iconColor,
          tooltip: '开启分支',
          onTap: isSending ? null : openBranchSheet,
        ),
      ],
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  const _ActionIconButton({
    required this.icon,
    required this.size,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 3.h),
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final AnimationController ctrl;
  final Color color;

  const _DotsIndicator({required this.ctrl, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16.h,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final begin = i * 0.2;
          final end = begin + 0.5;
          final anim = Tween<double>(begin: 0.3, end: 1.0).animate(
            CurvedAnimation(
              parent: ctrl,
              curve: Interval(begin, end, curve: Curves.easeInOut),
            ),
          );
          return AnimatedBuilder(
            animation: anim,
            builder: (_, _) => Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.w),
              child: Opacity(
                opacity: anim.value,
                child: CircleAvatar(radius: 3.5.r, backgroundColor: color),
              ),
            ),
          );
        }),
      ),
    );
  }
}
