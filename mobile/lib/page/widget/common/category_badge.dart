import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 可复用的分类徽章组件
///
/// 支持两种样式：
/// - 亮色模式（onImage）：适用于叠加在图片上，使用半透明白色背景
/// - 暗色模式（normal）：适用于普通背景，使用 surfaceContainerHighest 背景
class CategoryBadge extends StatelessWidget {
  final String categoryName;
  final CategoryBadgeStyle style;

  const CategoryBadge({
    super.key,
    required this.categoryName,
    this.style = CategoryBadgeStyle.normal,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final isOnImage = style == CategoryBadgeStyle.onImage;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: isOnImage
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        categoryName,
        style: textTheme.bodySmall?.copyWith(
          color: isOnImage
              ? const Color(0xcdffffff)
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

enum CategoryBadgeStyle {
  /// 正常样式：用于普通背景
  normal,

  /// 图片叠加样式：用于叠加在图片上
  onImage,
}
