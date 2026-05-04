import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/providers/category_providers.dart';
import 'package:pocketmind/providers/nav_providers.dart';
import 'package:pocketmind/providers/note_providers.dart';
import 'package:pocketmind/util/theme_data.dart';

import 'item_bar.dart';
import 'package:pocketmind/util/theme_data.dart';

class CategoriesBar extends ConsumerWidget {
  const CategoriesBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 从 provider 获取导航项数据
    final navItemsAsync = ref.watch(navItemsProvider);
    // 从 provider 获取当前激活的索引
    final activeIndex = ref.watch(activeNavIndexProvider);

    // 获取当前主题亮度
    final isDark = context.isDark;
    return navItemsAsync.when(
      data: (navItems) {
        // 如果没有导航项，返回空容器
        if (navItems.isEmpty) {
          return const SizedBox.shrink();
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 主导航栏（毛玻璃效果）
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100.0.r),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0.r, sigmaY: 10.0.r),
                  child: Container(
                    padding: EdgeInsets.all(8.0.r),
                    decoration: BoxDecoration(
                      // 根据主题调整毛玻璃颜色 - 亮色模式使用更深的背景
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05), // 改用黑色半透明
                      borderRadius: BorderRadius.circular(100.0.r),
                      // 添加边框以在亮色模式下提供对比度
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.08), // 使用黑色半透明边框
                        width: 1.0.w,
                      ),
                      // 添加微妙阴影
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.3 : 0.08,
                          ),
                          blurRadius: 12.r,
                          spreadRadius: 0,
                          offset: Offset(0, 2.h),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(navItems.length, (index) {
                          final item = navItems[index];
                          return GestureDetector(
                            // 删除对应的
                            onLongPressUp: () =>
                                _onDeletePressed(context, ref, item.categoryId),
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: index == navItems.length - 1 ? 0 : 6.0.w,
                              ),
                              child: ItemBar(
                                svgPath: item.svgPath,
                                text: item.text,
                                isActive: activeIndex == index,
                                onTap: () {
                                  ref
                                      .read(activeNavIndexProvider.notifier)
                                      .set(index);
                                },
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) {
        debugPrint('Error loading nav items: $error');
        return const SizedBox.shrink();
      },
    );
  }

  void _onDeletePressed(BuildContext context, WidgetRef ref, int categoryId) {
    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = context.colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text('删除分类', style: TextStyle(color: colorScheme.primary)),
          content: Text(
            '确定要删除这个分类吗？此操作无法撤销。',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('取消', style: TextStyle(color: colorScheme.secondary)),
            ),
            TextButton(
              onPressed: () async {
                // 删除对应分类下的笔记
                await ref
                    .read(noteServiceProvider)
                    .deleteAllNoteByCategoryId(categoryId);
                await ref
                    .read(categoryServiceProvider)
                    .deleteCategory(categoryId);
                // 下标切换为home
                ref.read(activeNavIndexProvider.notifier).set(1);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: Text('删除', style: TextStyle(color: colorScheme.error)),
            ),
          ],
        );
      },
    );
  }
}
