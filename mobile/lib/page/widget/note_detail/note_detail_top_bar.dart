import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NoteDetailTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// 顶部栏中间区域（用于放置分类/时间等信息）。
  final Widget? middle;

  /// 右侧操作区的前置区域（用于放置分类选择器等）。
  final Widget? rightLeading;

  const NoteDetailTopBar({
    super.key,
    required this.onBack,
    required this.onShare,
    required this.onEdit,
    required this.onDelete,
    this.middle,
    this.rightLeading,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 56.h,
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 返回按钮 - 带文字提示
          _buildNavButton(
            icon: Icons.arrow_back_rounded,
            label: '返回',
            onPressed: onBack,
            colorScheme: colorScheme,
          ),

          // 中间区域：分类 & 时间
          Expanded(child: Center(child: middle ?? const SizedBox.shrink())),

          // 右侧操作按钮组
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (rightLeading != null) ...[
                rightLeading!,
                SizedBox(width: 8.w),
              ],
              // _buildNavButton(
              //   icon: Icons.share_outlined,
              //   label: '分享',
              //   onPressed: onShare,
              //   colorScheme: colorScheme,
              // ),
              // _buildNavButton(
              //   icon: Icons.edit_outlined,
              //   label: '编辑',
              //   onPressed: onEdit,
              //   colorScheme: colorScheme,
              // ),
              Container(
                width: 1,
                height: 20.h,
                margin: EdgeInsets.symmetric(horizontal: 8.w),
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              _buildNavButton(
                icon: Icons.delete_outline,
                label: '删除',
                onPressed: onDelete,
                colorScheme: colorScheme,
                isDestructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 导航栏按钮
  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required ColorScheme colorScheme,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? colorScheme.error.withValues(alpha: 0.8)
        : colorScheme.secondary;
    final hoverColor = isDestructive
        ? colorScheme.error.withValues(alpha: 0.1)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8.r),
        hoverColor: hoverColor,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18.sp, color: color),
              SizedBox(width: 4.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
