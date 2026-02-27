import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:pocketmind/util/theme_data.dart';

/// 时间分割线。
class ChatTimeDivider extends StatelessWidget {
  final DateTime time;
  final ChatBubbleColors colors;

  const ChatTimeDivider({super.key, required this.time, required this.colors});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
            style: textTheme.bodySmall?.copyWith(color: colors.timeLabelText),
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

/// 空状态提示。
class ChatEmptyHint extends StatelessWidget {
  const ChatEmptyHint({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
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
            style: textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 底部弹窗顶部拖拽条。
class ChatBottomSheetHandle extends StatelessWidget {
  const ChatBottomSheetHandle({super.key});

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

/// 会话菜单项。
class ChatSheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const ChatSheetTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effective = color ?? Theme.of(context).colorScheme.onSurface;
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      leading: Icon(icon, color: effective, size: 22.sp),
      title: Text(
        label,
        style: textTheme.bodyLarge?.copyWith(color: effective),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 24.w),
    );
  }
}

/// 编辑模式提示条。
class ChatEditModeBanner extends StatelessWidget {
  final VoidCallback onCancel;

  const ChatEditModeBanner({super.key, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      color: cs.secondaryContainer.withValues(alpha: 0.6),
      child: Row(
        children: [
          Icon(
            Icons.edit_outlined,
            size: 14.sp,
            color: cs.onSecondaryContainer,
          ),
          SizedBox(width: 6.w),
          Text(
            '编辑模式 — 修改内容后发送',
            style: textTheme.bodySmall?.copyWith(
              color: cs.onSecondaryContainer,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onCancel,
            child: Icon(
              Icons.close_rounded,
              size: 16.sp,
              color: cs.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
