import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketmind/providers/app_config_provider.dart';

/// 布局切换按钮组件
/// 用于切换卡片布局和列表布局
class LayoutToggleButton extends ConsumerWidget {
  const LayoutToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final isGridMode = config.waterfallLayoutEnabled;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8.r),
      ),
      padding: EdgeInsets.all(4.w),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LayoutButton(
            icon: Icons.grid_view_rounded,
            isActive: isGridMode,
            onTap: () {
              if (!isGridMode) {
                ref.read(appConfigProvider.notifier).setWaterFallLayout(true);
              }
            },
          ),
          SizedBox(width: 4),
          _LayoutButton(
            icon: Icons.view_list_rounded,
            isActive: !isGridMode,
            onTap: () {
              if (isGridMode) {
                ref.read(appConfigProvider.notifier).setWaterFallLayout(false);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// 单个布局切换按钮
class _LayoutButton extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _LayoutButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_LayoutButton> createState() => _LayoutButtonState();
}

class _LayoutButtonState extends State<_LayoutButton> {
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
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: widget.isActive
                ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white)
                : (_isHovered
                      ? (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03))
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(6.r),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.2 : 0.05,
                      ),
                      blurRadius: 4.r,
                      offset: Offset(0, 1.h),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            widget.icon,
            size: 18.sp,
            color: widget.isActive
                ? colorScheme.tertiary
                : colorScheme.secondary,
          ),
        ),
      ),
    );
  }
}

/// 主题切换按钮
class ThemeToggleButton extends StatefulWidget {
  const ThemeToggleButton({super.key});

  @override
  State<ThemeToggleButton> createState() => _ThemeToggleButtonState();
}

class _ThemeToggleButtonState extends State<ThemeToggleButton> {
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
        onTap: () {
          // 主题切换逻辑 - 可扩展
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(
            isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            size: 20.sp,
            color: colorScheme.secondary,
          ),
        ),
      ),
    );
  }
}

/// 桌面端顶部导航栏
/// 包含搜索栏、主题切换和布局切换
class DesktopHeader extends ConsumerWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback? onSearchSubmit;
  final VoidCallback? onClear;
  final VoidCallback? onAddTap;

  const DesktopHeader({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    this.onSearchSubmit,
    this.onClear,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    // Windows 平台预留右侧窗口控制按钮空间
    // 在小窗口模式下减少右侧留白，避免溢出
    final rightPadding = Platform.isWindows
        ? (screenWidth < 600 ? 60.w : 140.w)
        : 24.w;

    return Container(
      height: 72.w,
      padding: EdgeInsets.fromLTRB(32.w, 0, rightPadding, 0),
      child: Row(
        children: [
          // 搜索栏 - 居中对齐，限制最大宽度
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: _DesktopSearchBar(
                  controller: searchController,
                  focusNode: searchFocusNode,
                  onSubmitted: onSearchSubmit,
                  onClear: onClear,
                ),
              ),
            ),
          ),

          SizedBox(width: 24),

          // 右侧功能按钮组
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onAddTap != null)
                Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: FilledButton.icon(
                    key: const ValueKey('desktop_add_note_button'),
                    onPressed: onAddTap,
                    icon: const Icon(Icons.add),
                    label: const Text('新增'),
                  ),
                ),
              const ThemeToggleButton(),
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 20,
                color: colorScheme.outlineVariant,
              ),
              SizedBox(width: 8),
              const LayoutToggleButton(),
            ],
          ),
        ],
      ),
    );
  }
}

/// 桌面端搜索栏组件
class _DesktopSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback? onSubmitted;
  final VoidCallback? onClear;

  const _DesktopSearchBar({
    required this.controller,
    required this.focusNode,
    this.onSubmitted,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 40.w,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(left: 14.w),
            child: Icon(
              Icons.search,
              size: 18.sp,
              color: colorScheme.secondary,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: '搜索收藏...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
                hintStyle: TextStyle(
                  color: colorScheme.secondary.withValues(alpha: 0.6),
                  fontSize: 14.sp,
                ),
                isDense: true,
              ),
              style: TextStyle(color: colorScheme.primary, fontSize: 14.sp),
              onSubmitted: (_) => onSubmitted?.call(),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              if (value.text.isEmpty) {
                return SizedBox(width: 14);
              }
              return Padding(
                padding: EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    controller.clear();
                    onClear?.call();
                    focusNode.requestFocus();
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: colorScheme.secondary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
