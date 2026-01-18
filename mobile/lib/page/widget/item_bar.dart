import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ItemBar extends StatelessWidget {
  final String svgPath;
  final String text;
  final bool isActive;
  final VoidCallback onTap;

  const ItemBar({
    super.key,
    required this.svgPath,
    required this.text,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 1. 根据 'isActive' 状态定义样式
    // 匹配 Variant 1 的 'bg-white/30' (激活)
    final Color bgColor = isActive ? Color(0xE22583DF) : Colors.transparent;

    Color textColor() {
      if (isActive) {
        return Theme.of(context).colorScheme.primary;
      } else {
        return Theme.of(context).colorScheme.primary.withValues(alpha: 0.8);
      }
    }

    // 匹配 'font-semibold' (激活) vs 'font-medium' (非激活)
    final FontWeight fontWeight = isActive ? FontWeight.w600 : FontWeight.w500;

    // 1. 判断当前是否是暗色模式
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 2. 根据模式选择微光的基色
    final Color glossColor = isDark ? Colors.white : Colors.black;

    // 2. 模拟激活项的 '悬浮微光' (before:animate-pulse-slow)
    // 这是一个静态的从左上到右下的渐变，模仿 '微光'
    final Gradient? activeGradient = isActive
        ? LinearGradient(
            colors: [
              glossColor.withValues(alpha: 0.2),
              glossColor.withValues(alpha: 0.0),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;

    // 3. 使用 GestureDetector 监听点击
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.w),
        decoration: BoxDecoration(
          color: bgColor,
          gradient: activeGradient,
          borderRadius: BorderRadius.circular(100.r),
          // boxShadow: boxShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              svgPath,
              // 匹配 'nav-icon' 尺寸和 'text-white' 颜色
              colorFilter: ColorFilter.mode(textColor(), BlendMode.srcIn),
              width: 20.w,
              height: 20.w,
            ),
            // 匹配 'gap-2'
            SizedBox(width: 8.w),
            Text(
              text,
              style: TextStyle(
                color: textColor(),
                // 匹配 'text-sm'
                fontSize: 14.sp,
                fontWeight: fontWeight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
