import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketmind/router/route_paths.dart';
import 'package:pocketmind/providers/category_providers.dart';
import 'package:pocketmind/providers/nav_providers.dart';
import 'package:pocketmind/providers/note_providers.dart';
import 'package:pocketmind/page/widget/creative_toast.dart';
import 'sidebar_item.dart';

/// 桌面端侧边栏组件
/// 包含 App 名称、分类列表和设置入口
class DesktopSidebar extends ConsumerWidget {
  /// 侧边栏宽度
  static const double width = 260;

  const DesktopSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    // 从 provider 获取当前激活的索引
    final activeIndex = ref.watch(activeNavIndexProvider);

    // macOS 红绿灯按钮预留空间
    final topPadding = Platform.isMacOS ? 28.w : 0.0;

    return Container(
      width: width,
      // 使用 surfaceContainerLow 作为侧边栏背景
      color: colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // macOS 红绿灯预留空间
          SizedBox(height: topPadding),

          // App 名称区域
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 24.w, 20.w, 32.w),
            child: Row(
              children: [
                // App Logo
                Container(
                  width: 28.w,
                  height: 28.w,
                  decoration: BoxDecoration(
                    color: colorScheme.tertiary,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'P',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Georgia',
                    ),
                  ),
                ),
                SizedBox(width: 10),
                // App 名称 - 使用衬线字体
                Text(
                  'PocketMind',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          // 主导航标题
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              '主导航',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.secondary.withValues(alpha: 0.7),
                letterSpacing: 1.5,
              ),
            ),
          ),

          // 三个主Tab入口
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                SidebarItem(
                  text: 'Everything',
                  isActive: activeIndex == 0,
                  onTap: () {
                    ref.read(activeNavIndexProvider.notifier).set(0);
                    context.go(RoutePaths.home);
                  },
                ),
                SidebarItem(
                  text: 'AI',
                  isActive: activeIndex == 1,
                  onTap: () {
                    ref.read(activeNavIndexProvider.notifier).set(1);
                    context.go(RoutePaths.home);
                  },
                ),
                SidebarItem(
                  text: '分类',
                  isActive: activeIndex == 2,
                  onTap: () {
                    ref.read(activeNavIndexProvider.notifier).set(2);
                    context.go(RoutePaths.home);
                  },
                ),
              ],
            ),
          ),

          // 底部分隔线
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: colorScheme.outline,
            ),
          ),

          // 设置入口
          const _SettingsButton(),

          // 底部安全区域
          SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 删除分类对话框
  Future<void> _onDeletePressed(
    BuildContext context,
    WidgetRef ref,
    int categoryId,
    String categoryName,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除分类',
      message: '确定要删除分类 "$categoryName" 吗？\n该分类下的所有笔记也将被永久删除，此操作无法撤销。',
      confirmText: '确认删除',
      cancelText: '取消',
    );

    if (confirmed == true) {
      try {
        await ref
            .read(noteServiceProvider)
            .deleteAllNoteByCategoryId(categoryId);
        await ref.read(categoryServiceProvider).deleteCategory(categoryId);

        // 重置选中项到"全部"
        ref.read(activeNavIndexProvider.notifier).set(0);

        if (context.mounted) {
          CreativeToast.success(
            context,
            title: '删除成功',
            message: '分类 "$categoryName" 已删除',
            direction: ToastDirection.top,
          );
        }
      } catch (e) {
        if (context.mounted) {
          CreativeToast.error(
            context,
            title: '删除失败',
            message: e.toString(),
            direction: ToastDirection.top,
          );
        }
      }
    }
  }
}

/// 设置按钮组件
class _SettingsButton extends StatefulWidget {
  const _SettingsButton();

  @override
  State<_SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<_SettingsButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push(RoutePaths.settings),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.w),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.w),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            children: [
              Icon(
                Icons.settings_outlined,
                size: 18.sp,
                color: colorScheme.secondary,
              ),
              SizedBox(width: 10.w),
              Text(
                '设置',
                style: TextStyle(
                  color: colorScheme.secondary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
