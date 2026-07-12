import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:genui/genui.dart' hide ChatMessage;
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/page/chat/widgets/chat_branch_sheet.dart';
import 'package:pocketmind/page/widget/creative_toast.dart';
import 'package:pocketmind/providers/chat_providers.dart';
import 'package:pocketmind/util/a2ui_card_util.dart';
import 'package:pocketmind/util/streaming_markdown_catalog_item.dart';
import 'package:pocketmind/util/theme_data.dart';

/// 单条消息气泡。
class ChatMessageBubble extends ConsumerWidget {
  final ChatMessage message;
  final ChatBubbleColors colors;
  final String sessionUuid;
  final bool isLeaf;
  final bool isLastUserMsg;
  final bool isLastOfTurn;
  final Map<String, dynamic>? lockedDataModel;
  final void Function(String uuid, String content)? onEditTap;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.colors,
    required this.sessionUuid,
    required this.isLeaf,
    required this.isLastUserMsg,
    required this.isLastOfTurn,
    this.lockedDataModel,
    this.onEditTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == 'USER';
    final textTheme = context.textTheme;

    if (message.messageType == 'TOOL_RESULT') {
      final operations = tryParseA2uiCard(message.content);
      if (operations != null) {
        // 优先用 preview 注入的 handler(debug 预览页写回本地假仓库);生产环境
        // handler 为 null,退回把这次提交当作一次新的用户消息发出去——content 是
        // {surfaceId, dataModel} JSON,后端按普通消息落库为 USER 消息并喂回模型,
        // reload 时据它推导锁定态。showPendingBubble:false 避免这条 JSON
        // 元数据以气泡形式闪现。
        final injected = ref.watch(a2uiCardSubmitHandlerProvider);
        final onSubmitted =
            injected ??
            (String surfaceId, Map<String, dynamic> dataModel) {
              ref
                  .read(chatSendProvider(sessionUuid).notifier)
                  .send(
                    jsonEncode({'surfaceId': surfaceId, 'dataModel': dataModel}),
                    showPendingBubble: false,
                  );
            };
        return A2uiCardMessage(
          key: ValueKey('a2ui-card-${message.uuid}'),
          operations: operations,
          lockedDataModel: lockedDataModel,
          onSubmitted: onSubmitted,
        );
      }
    }

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
                      : StreamingTextMarkdown.chatGPT(
                          text: message.content,
                          markdownEnabled: true,
                          animationsEnabled: false,
                          isLoading: false,
                          padding: EdgeInsets.zero,
                        ),
                ),
                SizedBox(height: 4.h),
                // 一轮 AI 回复可能拆成"文本+工具调用+文本+卡片"的块序列
                // (isLastOfTurn),操作按钮(复制/点赞/分支等)只挂在这轮
                // 最后一块上,中间的文本块还没说完这轮的话,不显示。
                // 用户自己发的消息不受这个限制。
                if (isUser || isLastOfTurn)
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
    final textTheme = context.textTheme;
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

/// 流式态气泡：按块序列渲染这一轮还在流式生成的回复。文本块实时 md 渲染；
/// 工具调用块只显示"调用中/已完成"的过渡提示，不落库——流式结束后由持久化
/// 的 TOOL_CALL/TOOL_RESULT 消息取代；A2UI 卡片块用临时 [SurfaceController]
/// 实时渲染，随分片到达逐步搭建。
class ChatStreamingBubble extends StatelessWidget {
  final List<ChatLiveBlock> blocks;
  final ChatBubbleColors colors;

  const ChatStreamingBubble({
    super.key,
    required this.blocks,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) {
      final textTheme = context.textTheme;
      return Padding(
        padding: EdgeInsets.only(bottom: 10.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: ChatBubbleShape(
                isUser: false,
                colors: colors,
                child: Text(
                  '…',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colors.assistantBubbleText,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final block in blocks) _buildBlock(context, block)],
    );
  }

  Widget _buildBlock(BuildContext context, ChatLiveBlock block) {
    return switch (block) {
      ChatLiveTextBlock(:final content) => Padding(
        padding: EdgeInsets.only(bottom: 10.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: ChatBubbleShape(
                isUser: false,
                colors: colors,
                child: StreamingTextMarkdown.chatGPT(
                  text: content,
                  markdownEnabled: true,
                  animationsEnabled: false,
                  isLoading: false,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
      ChatLiveToolCallBlock(:final toolName, :final done) =>
        _LiveToolCallHint(toolName: toolName, done: done),
      ChatLiveA2uiBlock(:final chunks) => _LiveA2uiCardMessage(chunks: chunks),
    };
  }
}

/// 流式中的工具调用过渡提示，样式对齐持久化后的 [ChatToolCallCard] 折叠态，
/// 但没有展开/结果——结果只在流式结束、消息落库后才存在。
class _LiveToolCallHint extends StatelessWidget {
  final String toolName;
  final bool done;

  const _LiveToolCallHint({required this.toolName, required this.done});

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final cs = context.colorScheme;
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
            if (done)
              Icon(
                Icons.check_circle_outline_rounded,
                size: 14.sp,
                color: cs.tertiary,
              )
            else
              SizedBox(
                width: 14.sp,
                height: 14.sp,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: cs.tertiary,
                ),
              ),
            SizedBox(width: 6.w),
            Flexible(
              child: Text(
                done ? '$toolName 已完成' : '正在调用 $toolName…',
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

/// 流式中的 A2UI 卡片：每收到一条新分片就通过 [A2uiTransportAdapter.addChunk]
/// 追加，卡片随分片到达逐步搭建；不能用同步的 [SurfaceController.handleMessage]，
/// 因为分片到达时机不确定，需要走异步解析管线。
class _LiveA2uiCardMessage extends StatefulWidget {
  final List<String> chunks;

  const _LiveA2uiCardMessage({required this.chunks});

  @override
  State<_LiveA2uiCardMessage> createState() => _LiveA2uiCardMessageState();
}

class _LiveA2uiCardMessageState extends State<_LiveA2uiCardMessage> {
  late final SurfaceController _controller;
  late final A2uiTransportAdapter _adapter;
  String? _surfaceId;
  int _consumed = 0;

  @override
  void initState() {
    super.initState();
    _controller = SurfaceController(catalogs: [buildAppCatalog()]);
    _adapter = A2uiTransportAdapter();
    _adapter.incomingMessages.listen(_controller.handleMessage);
    _consumeNewChunks();
  }

  @override
  void didUpdateWidget(covariant _LiveA2uiCardMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _consumeNewChunks();
  }

  void _consumeNewChunks() {
    for (; _consumed < widget.chunks.length; _consumed++) {
      final chunk = widget.chunks[_consumed];
      _adapter.addChunk(chunk);
      _surfaceId ??= a2uiSurfaceId([
        A2uiMessage.fromJson(jsonDecode(chunk) as Map<String, dynamic>),
      ]);
    }
  }

  @override
  void dispose() {
    _adapter.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surfaceId = _surfaceId;
    if (surfaceId == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Surface(surfaceContext: _controller.contextFor(surfaceId)),
    );
  }
}

/// 工具调用/结果消息卡片。
///
/// `TOOL_CALL` 折叠态显示"调用了 {工具名}";`TOOL_RESULT` 折叠态显示
/// "{工具名} 已完成",点击展开可看完整结果(不显示参数)。数据从
/// [message] 的 `content` 里解析——落库的原始 JSON 形如
/// `{"toolCallId":...,"name":...,"arguments"|"result":...}`。
class ChatToolCallCard extends StatefulWidget {
  final ChatMessage message;

  const ChatToolCallCard({super.key, required this.message});

  @override
  State<ChatToolCallCard> createState() => _ChatToolCallCardState();
}

class _ChatToolCallCardState extends State<ChatToolCallCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final cs = context.colorScheme;
    final isCall = widget.message.messageType == 'TOOL_CALL';
    final data = _tryParseToolData(widget.message.content);
    final toolName = data?['name'] as String? ?? '工具';
    final result = data?['result'] as String?;
    final hasResult = !isCall && result != null && result.isNotEmpty;

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
        child: InkWell(
          onTap: hasResult
              ? () => setState(() => _expanded = !_expanded)
              : null,
          borderRadius: BorderRadius.circular(10.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
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
                      isCall ? '调用了 $toolName' : '$toolName 已完成',
                      style: textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasResult) ...[
                    SizedBox(width: 2.w),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16.sp,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
              if (_expanded && hasResult) ...[
                SizedBox(height: 6.h),
                Text(
                  result,
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Map<String, dynamic>? _tryParseToolData(String content) {
  try {
    final decoded = jsonDecode(content);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}

/// A2UI 卡片消息(判别为 A2UI 消息的 `TOOL_RESULT`)。
///
/// 每条卡片消息拥有独立的 [SurfaceController],随 widget 一起创建/销毁,
/// 使同屏多条卡片各自独立、互不干扰。[operations] 是该消息落库的完整操作
/// 序列,在 [initState] 里用同步的 `handleMessage` 循环灌入(而不是走异步的
/// chunk 解析管线),确保首帧渲染即为最终态,不出现空白帧。消息内容落库后
/// 不再改写,因此不需要处理更新。
///
/// [lockedDataModel] 非 null 时表示这张卡片已经提交过一次交互:额外灌入一条
/// `updateDataModel(path: '/')` 把提交时的完整 dataModel 定格显示,并整体
/// 包一层 [AbsorbPointer] 拦截触摸——genui 的交互组件(Button/ChoicePicker/
/// TextField/CheckBox)都没有只读/禁用的 schema 属性,组件本身没法进入只读态,
/// 只能在外层拦截。未锁定时,[onSubmitted] 会在用户触发一次 `event` 提交后
/// 收到该 surface 当前的完整 dataModel(通过 [DataModel.getValue] 读根路径
/// 取整份快照,而不是解析 [SurfaceController.onSubmit] 内部的事件负载)。
class A2uiCardMessage extends StatefulWidget {
  final List<A2uiMessage> operations;
  final Map<String, dynamic>? lockedDataModel;
  final void Function(String surfaceId, Map<String, dynamic> dataModel)?
  onSubmitted;

  const A2uiCardMessage({
    super.key,
    required this.operations,
    this.lockedDataModel,
    this.onSubmitted,
  });

  @override
  State<A2uiCardMessage> createState() => _A2uiCardMessageState();
}

class _A2uiCardMessageState extends State<A2uiCardMessage> {
  late final SurfaceController _controller;
  late final String _surfaceId;
  StreamSubscription<Object?>? _submitSubscription;

  @override
  void initState() {
    super.initState();
    _controller = SurfaceController(catalogs: [buildAppCatalog()]);
    for (final operation in widget.operations) {
      _controller.handleMessage(operation);
    }
    _surfaceId = a2uiSurfaceId(widget.operations);

    final lockedDataModel = widget.lockedDataModel;
    if (lockedDataModel != null) {
      _controller.handleMessage(
        UpdateDataModel(surfaceId: _surfaceId, value: lockedDataModel),
      );
    } else if (widget.onSubmitted != null) {
      _submitSubscription = _controller.onSubmit.listen((_) {
        final dataModel = _controller.store
            .getDataModel(_surfaceId)
            .getValue<Map<String, Object?>>(DataPath.root);
        widget.onSubmitted!(_surfaceId, Map<String, dynamic>.from(dataModel ?? {}));
      });
    }
  }

  @override
  void dispose() {
    _submitSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Surface(surfaceContext: _controller.contextFor(_surfaceId)),
    );
    if (widget.lockedDataModel == null) return surface;
    return AbsorbPointer(
      key: const Key('a2ui-card-lock-barrier'),
      child: surface,
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
    final shadowColor = context.theme.shadowColor;
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
    final cs = context.colorScheme;
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
        backgroundColor: context.theme.cardColor,
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
