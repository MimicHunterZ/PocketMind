import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/providers/chat_providers.dart';
import 'package:pocketmind/page/chat/widgets/chat_common_widgets.dart';

/// 新分支底部弹窗（从某条 AI 消息节点开始新对话）。
class ChatBranchSheet extends ConsumerStatefulWidget {
  final String sessionUuid;
  final String parentUuid;

  const ChatBranchSheet({
    super.key,
    required this.sessionUuid,
    required this.parentUuid,
  });

  @override
  ConsumerState<ChatBranchSheet> createState() => _ChatBranchSheetState();
}

class _ChatBranchSheetState extends ConsumerState<ChatBranchSheet> {
  final _ctrl = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    Navigator.pop(context);
    await ref
        .read(chatSendProvider(widget.sessionUuid).notifier)
        .send(text, parentUuid: widget.parentUuid);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ChatBottomSheetHandle(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
            child: Text(
              '从此处开启新分支',
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16.w,
            ).copyWith(bottom: 8.h),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    constraints: BoxConstraints(maxHeight: 120.h),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 4.h,
                    ),
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: '输入分支第一条消息…',
                        border: InputBorder.none,
                        hintStyle: textTheme.bodyLarge?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                IconButton.filled(
                  icon: const Icon(Icons.send_rounded),
                  onPressed: _isSending ? null : _send,
                  style: IconButton.styleFrom(
                    backgroundColor: cs.tertiary,
                    foregroundColor: cs.onTertiary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }
}
