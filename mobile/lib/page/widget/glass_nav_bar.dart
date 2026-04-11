// 用于 ImageFilter.blur
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketmind/router/route_paths.dart';
import 'package:pocketmind/page/widget/categories_bar.dart' show CategoriesBar;

///
/// 这是包含 ItemBar 的主导航栏。
/// 它实现了玻璃拟态背景和状态管理。
/// 使用 Riverpod 进行依赖注入和状态管理。
/// 集成了搜索按钮和布局切换功能
///
@Deprecated('暂时弃用')
class GlassNavBar extends ConsumerWidget {
  final VoidCallback? onSearchPressed;

  const GlassNavBar({super.key, this.onSearchPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 获取当前主题亮度
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 传递正确的宽度约束下去
        Expanded(child: CategoriesBar()),

        const SizedBox(width: 8),

        // 搜索按钮
        _buildIconButton(
          context,
          icon: Icons.search,
          onPressed: onSearchPressed ?? () {},
          isDark: isDark,
        ),

        SizedBox(width: 8.w),

        // 设置按钮
        _buildIconButton(
          context,
          icon: Icons.settings,
          onPressed: () {
            context.push(RoutePaths.settings);
          },
          isDark: isDark,
        ),
      ],
    );
  }

  // 构建图标按钮的辅助方法
  Widget _buildIconButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
    required bool isDark,
    String? tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        // 亮色模式使用黑色半透明，暗色模式使用白色半透明
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.08),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        color: Theme.of(context).colorScheme.primary,
        iconSize: 22.sp,
      ),
    );
  }
}
