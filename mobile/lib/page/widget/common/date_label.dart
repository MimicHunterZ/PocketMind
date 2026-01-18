import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 可复用的日期标签组件
///
/// 支持两种样式：
/// - 亮色模式（onImage）：适用于叠加在图片上，使用白色图标和文字
/// - 暗色模式（normal）：适用于普通背景，使用 secondary 颜色
class DateLabel extends StatelessWidget {
  final String dateText;
  final DateLabelStyle style;
  final double? fontSize;
  final double? iconSize;

  const DateLabel({
    super.key,
    required this.dateText,
    this.style = DateLabelStyle.normal,
    this.fontSize,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isOnImage = style == DateLabelStyle.onImage;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.access_time_rounded,
          size: iconSize ?? (isOnImage ? 14.sp : 12.sp),
          color: isOnImage ? const Color(0xcdffffff) : colorScheme.secondary,
        ),
        SizedBox(width: 4.w),
        Text(
          dateText,
          style:
              (isOnImage ? textTheme.bodySmall : null)?.copyWith(
                fontSize: fontSize ?? 11.sp,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
                color: isOnImage
                    ? const Color(0xcdffffff)
                    : colorScheme.secondary,
              ) ??
              TextStyle(
                fontSize: fontSize ?? 11.sp,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
                color: isOnImage
                    ? const Color(0xcdffffff)
                    : colorScheme.secondary,
              ),
        ),
      ],
    );
  }
}

enum DateLabelStyle {
  /// 正常样式：用于普通背景
  normal,

  /// 图片叠加样式：用于叠加在图片上
  onImage,
}
