import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketmind/page/chat/widgets/chat_branch_chip.dart';
import 'package:pocketmind/page/chat/widgets/chat_common_widgets.dart';
import 'package:pocketmind/page/chat/widgets/chat_input_bar.dart';
import 'package:pocketmind/page/chat/widgets/chat_message_list.dart';
import 'package:pocketmind/page/widget/creative_toast.dart';
import 'package:pocketmind/page/widget/pm_app_bar.dart';
import 'package:pocketmind/providers/chat_providers.dart';
import 'package:pocketmind/router/route_paths.dart';
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

class _ChatPageState extends ConsumerState<ChatPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isVoiceMode = false;
  bool _hasText = false;

  /// 正在编辑的消息 UUID（非 null 表示编辑模式）。
  String? _editingMessageUuid;

  /// 编辑前的原始内容，用于判断是否有修改。
  String _editingOriginalContent = '';

  /// 用户在流式接收期间主动上滑时设为 true，暂停自动滚底。
  bool _userScrolledUp = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });

    _scrollController.addListener(_onScroll);

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

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final isAtBottom = pos.pixels >= pos.maxScrollExtent - 60;
    if (!isAtBottom && !_userScrolledUp) {
      setState(() => _userScrolledUp = true);
    }
  }

  void _scrollToBottom({bool immediate = false}) {
    if (_userScrolledUp) return;
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

  void _startEdit(String messageUuid, String content) {
    setState(() {
      _editingMessageUuid = messageUuid;
      _editingOriginalContent = content;
    });
    _textController.text = content;
    _textController.selection = TextSelection.collapsed(
      offset: _textController.text.length,
    );
    _focusNode.requestFocus();
  }

  void _cancelEdit() {
    setState(() {
      _editingMessageUuid = null;
      _editingOriginalContent = '';
    });
    _textController.clear();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (_editingMessageUuid != null) {
      if (text == _editingOriginalContent) {
        CreativeToast.info(
          context,
          title: '内容未修改',
          message: '请修改内容后再发送',
          direction: ToastDirection.bottom,
        );
        return;
      }

      final editingUuid = _editingMessageUuid!;
      _cancelEdit();
      setState(() => _userScrolledUp = false);
      ref
          .read(chatSendProvider(widget.sessionUuid).notifier)
          .editAndResend(editingUuid, text);
      _scrollToBottom();
      return;
    }

    _textController.clear();
    _focusNode.requestFocus();
    setState(() => _userScrolledUp = false);
    ref.read(chatSendProvider(widget.sessionUuid).notifier).send(text);
    _scrollToBottom();
  }

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
            const ChatBottomSheetHandle(),
            SizedBox(height: 8.h),
            ChatSheetTile(
              icon: Icons.edit_outlined,
              label: '重命名会话',
              onTap: () async {
                Navigator.pop(ctx);
                _showRenameDialog(context);
              },
            ),
            ChatSheetTile(
              icon: Icons.account_tree_outlined,
              label: '查看分支',
              onTap: () {
                Navigator.pop(ctx);
                context.push(RoutePaths.branchListOf(widget.sessionUuid));
              },
            ),
            ChatSheetTile(
              icon: Icons.delete_outline,
              label: '删除会话',
              color: Theme.of(context).colorScheme.error,
              onTap: () async {
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

  void _showRenameDialog(BuildContext outerContext) async {
    final title = await showInputDialog(
      outerContext,
      title: '重命名会话',
      hintText: '输入新标题',
    );
    if (title != null) {
      ref.read(chatServiceProvider).renameSession(widget.sessionUuid, title);
    }
  }

  void _confirmDelete(BuildContext outerContext) async {
    final confirm = await showConfirmDialog(
      outerContext,
      title: '删除会话',
      message: '删除后无法恢复，确认删除？',
    );
    if (confirm == true) {
      await ref.read(chatServiceProvider).deleteSession(widget.sessionUuid);
    }
    if (!outerContext.mounted) return;
    outerContext.pop();
  }

  void _onCameraTap() {
    // TODO: 调起相机/相册选图
  }

  void _onVoiceStart() {
    // TODO: 开始录音
  }

  void _onVoiceEnd() {
    // TODO: 停止录音并发送
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chatMessagesProvider(widget.sessionUuid), (_, _) {
      _scrollToBottom();
    });
    ref.listen(chatSendProvider(widget.sessionUuid), (prev, next) {
      if (prev is! ChatSendStreaming && next is ChatSendStreaming) {
        if (mounted) {
          setState(() => _userScrolledUp = false);
        }
      }
      if (next is ChatSendStreaming) {
        _scrollToBottom();
      }
    });

    final session = ref.watch(chatSessionByUuidProvider(widget.sessionUuid)).asData?.value;
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
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    session?.title ?? 'AI 对话',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ChatBranchChip(sessionUuid: widget.sessionUuid),
              ],
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
          Expanded(
            child: ChatMessageList(
              sessionUuid: widget.sessionUuid,
              scrollController: _scrollController,
              asyncValue: messagesAsync,
              sendState: sendState,
              colors: colors,
              onStartEdit: _startEdit,
            ),
          ),
          if (_editingMessageUuid != null)
            ChatEditModeBanner(onCancel: _cancelEdit),
          ChatInputBar(
            textController: _textController,
            focusNode: _focusNode,
            isVoiceMode: _isVoiceMode,
            hasText: _hasText,
            isSending: sendState is ChatSendStreaming,
            isEditMode: _editingMessageUuid != null,
            onToggleVoice: () => setState(() => _isVoiceMode = !_isVoiceMode),
            onSend: _sendMessage,
            colors: colors,
            actions: ChatInputActions(
              onCamera: _onCameraTap,
              onVoiceStart: _onVoiceStart,
              onVoiceEnd: _onVoiceEnd,
            ),
          ),
        ],
      ),
    );
  }
}
