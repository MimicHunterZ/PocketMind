import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/page/widget/markdown_text.dart';
import 'package:pocketmind/page/widget/pm_app_bar.dart';
import 'package:pocketmind/providers/chat_providers.dart';
import 'package:pocketmind/util/theme_data.dart';

/// 聊天页面。
///
/// 路由参数：sessionUuid (path param)
/// 导航方式：context.push(RoutePaths.chatOf(sessionUuid))
class ChatPage extends ConsumerStatefulWidget {
  final String sessionUuid;

  const ChatPage({super.key, required this.sessionUuid});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isVoiceMode = false;
  bool _hasText = false;

  // AppBar 标题底部弹出菜单
  void _showSessionMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BottomSheetHandle(),
            SizedBox(height: 8.h),
            _SheetTile(
              icon: Icons.edit_outlined,
              label: '重命名会话',
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(context);
              },
            ),
            _SheetTile(
              icon: Icons.delete_outline,
              label: '删除会话',
              color: Theme.of(context).colorScheme.error,
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context);
              },
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext outerContext) {
    final controller = TextEditingController();
    showDialog<void>(
      context: outerContext,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名会话'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入新标题'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final t = controller.text.trim();
              if (t.isNotEmpty) {
                ref
                    .read(chatServiceProvider)
                    .renameSession(widget.sessionUuid, t);
              }
              Navigator.pop(ctx);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext outerContext) {
    showDialog<void>(
      context: outerContext,
      builder: (ctx) => AlertDialog(
        title: const Text('删除会话'),
        content: const Text('删除后无法恢复，确认删除？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(chatServiceProvider)
                  .deleteSession(widget.sessionUuid);
              if (ctx.mounted) Navigator.pop(ctx);
              if (outerContext.mounted) outerContext.pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  
  // 生命周期
  

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
    // 进入页面时从服务端同步历史
    Future.microtask(() {
      if (!mounted) return;
      ref.read(chatSendProvider(widget.sessionUuid).notifier).initSession();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  
  // 滚动 & 发送
  

  void _scrollToBottom({bool immediate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (immediate) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      } else {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    _focusNode.requestFocus();
    ref.read(chatSendProvider(widget.sessionUuid).notifier).send(text);
    _scrollToBottom();
  }

  
  // Build
  

  @override
  Widget build(BuildContext context) {
    // 有新消息时滚到底
    ref.listen(chatMessagesProvider(widget.sessionUuid), (_, _) {
      _scrollToBottom();
    });
    ref.listen(chatSendProvider(widget.sessionUuid), (_, next) {
      if (next is ChatSendStreaming) _scrollToBottom();
    });

    final session = ref
        .watch(chatSessionByUuidProvider(widget.sessionUuid))
        .asData
        ?.value;
    final messagesAsync = ref.watch(chatMessagesProvider(widget.sessionUuid));
    final sendState = ref.watch(chatSendProvider(widget.sessionUuid));
    final colors = ChatBubbleColors.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: PMAppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              session?.title ?? 'AI 对话',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (sendState is ChatSendStreaming)
              Text(
                '正在回复…',
                style: TextStyle(fontSize: 11.sp, color: cs.tertiary),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_horiz_rounded, size: 22.sp),
            onPressed: () => _showSessionMenu(context),
            splashRadius: 20.r,
          ),
          SizedBox(width: 4.w),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: _buildMessageList(context, messagesAsync, sendState, colors),
          ),
          // 底部输入栏
          _ChatInputBar(
            textController: _textController,
            focusNode: _focusNode,
            isVoiceMode: _isVoiceMode,
            hasText: _hasText,
            isSending: sendState is ChatSendStreaming,
            onToggleVoice: () => setState(() => _isVoiceMode = !_isVoiceMode),
            onSend: _sendMessage,
            onCamera: () {
              // TODO: 调起相机/相册选图
            },
            colors: colors,
          ),
        ],
      ),
    );
  }

  
  // 消息列表
  

  Widget _buildMessageList(
    BuildContext context,
    AsyncValue<List<ChatMessage>> asyncValue,
    ChatSendState sendState,
    ChatBubbleColors colors,
  ) {
    return asyncValue.when(
      data: (messages) {
        final items = _buildItems(messages, sendState, colors);
        if (items.isEmpty) {
          return _EmptyHint();
        }
        return ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.only(
            left: 16.w,
            right: 16.w,
            top: 12.h,
            bottom: 8.h,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => items[i],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          '加载失败，请重试',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }

  /// 将消息列表扁平化为 Widget 列表（插入时间分割线）。
  List<Widget> _buildItems(
    List<ChatMessage> messages,
    ChatSendState sendState,
    ChatBubbleColors colors,
  ) {
    final widgets = <Widget>[];
    DateTime? lastTime;

    for (final msg in messages) {
      final ts = DateTime.fromMillisecondsSinceEpoch(msg.updatedAt);
      if (lastTime == null || ts.difference(lastTime).abs().inMinutes >= 5) {
        widgets.add(_TimeDivider(time: ts, colors: colors));
      }
      lastTime = ts;
      widgets.add(_ChatBubble(message: msg, colors: colors));
    }

    // 流式预览气泡
    if (sendState is ChatSendStreaming) {
      final now = DateTime.now();
      if (lastTime == null || now.difference(lastTime).abs().inMinutes >= 5) {
        widgets.add(_TimeDivider(time: now, colors: colors));
      }
      // 乐观展示用户消息（落库前即刻呈现）
      widgets.add(
        _PendingUserBubble(
          content: sendState.pendingUserMessage,
          colors: colors,
        ),
      );
      widgets.add(_StreamingBubble(content: sendState.content, colors: colors));
    }

    // 错误提示（内联在列表底部）
    if (sendState is ChatSendError) {
      widgets.add(
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Center(
            child: InkWell(
              onTap: () => ref
                  .read(chatSendProvider(widget.sessionUuid).notifier)
                  .reset(),
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
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }
}


// 消息气泡


class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final ChatBubbleColors colors;

  const _ChatBubble({required this.message, required this.colors});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'USER';

    if (message.messageType == 'TOOL_CALL' ||
        message.messageType == 'TOOL_RESULT') {
      return _ToolCallCard(message: message);
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
            child: _BubbleShape(
              isUser: isUser,
              colors: colors,
              child: isUser
                  ? SelectableText(
                      message.content,
                      style: TextStyle(
                        fontSize: 15.sp,
                        height: 1.55,
                        color: colors.userBubbleText,
                      ),
                    )
                  : MarkdownText(
                      data: message.content,
                      baseStyle: TextStyle(color: colors.assistantBubbleText),
                    ),
            ),
          ),
          if (isUser) SizedBox(width: 4.w),
        ],
      ),
    );
  }
}

class _BubbleShape extends StatelessWidget {
  final bool isUser;
  final ChatBubbleColors colors;
  final Widget child;

  const _BubbleShape({
    required this.isUser,
    required this.colors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(18);
    final userShape = const BorderRadius.only(
      topLeft: r,
      topRight: r,
      bottomLeft: r,
      bottomRight: Radius.circular(4),
    );
    final aiShape = const BorderRadius.only(
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
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}


// 用户消息乐观展示气泡（等待 Isar 落库期间的占位）


class _PendingUserBubble extends StatelessWidget {
  final String content;
  final ChatBubbleColors colors;

  const _PendingUserBubble({required this.content, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: _BubbleShape(
              isUser: true,
              colors: colors,
              child: SelectableText(
                content,
                style: TextStyle(
                  fontSize: 15.sp,
                  height: 1.55,
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


// 流式打字气泡


class _StreamingBubble extends StatefulWidget {
  final String content;
  final ChatBubbleColors colors;

  const _StreamingBubble({required this.content, required this.colors});

  @override
  State<_StreamingBubble> createState() => _StreamingBubbleState();
}

class _StreamingBubbleState extends State<_StreamingBubble>
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
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: _BubbleShape(
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
                          baseStyle: TextStyle(
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


// 工具调用消息卡片


class _ToolCallCard extends StatelessWidget {
  final ChatMessage message;

  const _ToolCallCard({required this.message});

  @override
  Widget build(BuildContext context) {
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
                style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// 时间分割线


class _TimeDivider extends StatelessWidget {
  final DateTime time;
  final ChatBubbleColors colors;

  const _TimeDivider({required this.time, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: colors.timeLabelBackground,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Text(
            _formatTime(time),
            style: TextStyle(fontSize: 11.sp, color: colors.timeLabelText),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    if (t.year != now.year) {
      return DateFormat('yyyy年M月d日 HH:mm').format(t);
    }
    final diff = now.difference(t);
    if (diff.inDays >= 2) {
      return DateFormat('M月d日 HH:mm').format(t);
    }
    if (diff.inDays >= 1) {
      return '昨天 ${DateFormat('HH:mm').format(t)}';
    }
    return DateFormat('HH:mm').format(t);
  }
}


// 空状态提示


class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 48.sp,
            color: cs.tertiary.withValues(alpha: 0.4),
          ),
          SizedBox(height: 12.h),
          Text(
            '有什么可以帮你的？',
            style: TextStyle(fontSize: 16.sp, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}


// 底部菜单辅助组件


class _BottomSheetHandle extends StatelessWidget {
  const _BottomSheetHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 12.h),
      child: Center(
        child: Container(
          width: 36.w,
          height: 4.h,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _SheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effective = color ?? Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: effective, size: 22.sp),
      title: Text(
        label,
        style: TextStyle(color: effective, fontSize: 15.sp),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 24.w),
    );
  }
}


// 底部输入栏


class _ChatInputBar extends StatelessWidget {
  final TextEditingController textController;
  final FocusNode focusNode;
  final bool isVoiceMode;
  final bool hasText;
  final bool isSending;
  final VoidCallback onToggleVoice;
  final VoidCallback onSend;
  final VoidCallback onCamera;
  final ChatBubbleColors colors;

  const _ChatInputBar({
    required this.textController,
    required this.focusNode,
    required this.isVoiceMode,
    required this.hasText,
    required this.isSending,
    required this.onToggleVoice,
    required this.onSend,
    required this.onCamera,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.inputBarBackground,
        border: Border(
          top: BorderSide(color: cs.outline.withValues(alpha: 0.2), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 左：语音/键盘切换
              _InputActionButton(
                icon: isVoiceMode
                    ? Icons.keyboard_rounded
                    : Icons.mic_none_rounded,
                onTap: onToggleVoice,
                color: cs.onSurfaceVariant,
              ),
              SizedBox(width: 6.w),

              // 中：文字输入框 or 按住说话按钮
              Expanded(
                child: isVoiceMode
                    ? _VoiceHoldButton(cs: cs)
                    : _TextInput(
                        controller: textController,
                        focusNode: focusNode,
                        enabled: !isSending,
                        onSubmit: onSend,
                        cs: cs,
                      ),
              ),

              SizedBox(width: 6.w),

              // 右：发送 or 相机
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: hasText && !isVoiceMode
                    ? _SendButton(
                        key: const Key('send'),
                        onTap: onSend,
                        isSending: isSending,
                        cs: cs,
                      )
                    : _InputActionButton(
                        key: const Key('camera'),
                        icon: Icons.camera_alt_outlined,
                        onTap: onCamera,
                        color: cs.onSurfaceVariant,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSubmit;
  final ColorScheme cs;

  const _TextInput({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSubmit,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: 40.h, maxHeight: 120.h),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22.r),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 2.h),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        maxLines: null,
        textInputAction: TextInputAction.newline,
        style: TextStyle(fontSize: 15.sp, color: cs.onSurface),
        decoration: InputDecoration(
          hintText: enabled ? '发消息…' : '正在回复中…',
          hintStyle: TextStyle(
            fontSize: 15.sp,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 10.h),
        ),
      ),
    );
  }
}

class _VoiceHoldButton extends StatelessWidget {
  final ColorScheme cs;

  const _VoiceHoldButton({required this.cs});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) {
        // TODO: 开始录音
      },
      onLongPressEnd: (_) {
        // TODO: 停止录音并发送
      },
      child: Container(
        height: 40.h,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22.r),
        ),
        alignment: Alignment.center,
        child: Text(
          '按住说话',
          style: TextStyle(
            fontSize: 14.sp,
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _InputActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _InputActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40.w,
      height: 40.w,
      child: IconButton(
        icon: Icon(icon, size: 24.sp, color: color),
        onPressed: onTap,
        padding: EdgeInsets.zero,
        splashRadius: 20.r,
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isSending;
  final ColorScheme cs;

  const _SendButton({
    super.key,
    required this.onTap,
    required this.isSending,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40.w,
      height: 40.w,
      child: Material(
        color: cs.tertiary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: isSending ? null : onTap,
          child: Center(
            child: isSending
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onTertiary,
                    ),
                  )
                : Icon(
                    Icons.arrow_upward_rounded,
                    size: 20.sp,
                    color: cs.onTertiary,
                  ),
          ),
        ),
      ),
    );
  }
}
