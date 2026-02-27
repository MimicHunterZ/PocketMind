import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/providers/chat_providers.dart';

/// 分支标签（显示在 AppBar 标题旁，指示当前所在分支）。
class ChatBranchChip extends ConsumerWidget {
  final String sessionUuid;

  const ChatBranchChip({super.key, required this.sessionUuid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(chatSessionStreamProvider(sessionUuid)).asData?.value;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final leafUuid = session?.activeLeafUuid;

    final leafMessage = leafUuid != null
        ? ref.watch(chatMessageByUuidProvider(leafUuid)).asData?.value
        : null;
    final label = leafUuid == null ? '主线' : (leafMessage?.branchAlias ?? '分支');

    return Container(
      margin: EdgeInsets.only(left: 6.w),
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        label,
        style: textTheme.bodyMedium?.copyWith(color: cs.onTertiaryContainer),
      ),
    );
  }
}
