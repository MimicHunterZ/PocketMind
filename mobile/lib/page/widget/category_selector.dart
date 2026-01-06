import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pocketmind/model/category.dart';
import 'package:pocketmind/page/widget/add_category_dialog.dart';
import 'package:pocketmind/providers/category_providers.dart';

/// 分类选择器
class CategorySelector extends ConsumerWidget {
  final int selectedCategoryId;
  final ValueChanged<int> onCategorySelected;
  final Widget Function(BuildContext context, Category selectedCategory)?
  builder;

  const CategorySelector({
    super.key,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    this.builder,
  });

  void _showSelectionPanel(
    BuildContext context,
    List<Category> categories,
    int currentId,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => _CategoryDialog(
        categories: categories,
        currentId: currentId,
        onSelected: (id) {
          onCategorySelected(id);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return categoriesAsync.when(
      data: (categories) {
        final effectiveCategoryId =
            categories.any((c) => c.id == selectedCategoryId)
            ? selectedCategoryId
            : (categories.isNotEmpty ? categories.first.id! : 0);

        final selectedCategory = categories.firstWhere(
          (c) => c.id == effectiveCategoryId,
          orElse: () => Category()
            ..id = 0
            ..name = 'Uncategorized',
        );

        return GestureDetector(
          onTap: () =>
              _showSelectionPanel(context, categories, effectiveCategoryId),
          behavior: HitTestBehavior.opaque,
          child: builder != null
              ? builder!(context, selectedCategory)
              : Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectedCategory.name,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 16.sp,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
        );
      },
      loading: () => SizedBox(
        width: 60.w,
        height: 32.h,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, stack) => Text(
        'Error',
        style: TextStyle(color: colorScheme.error, fontSize: 12.sp),
      ),
    );
  }
}

/// 根据分类名称获取默认图标路径（当 Category.iconPath 为空时使用）
String getDefaultIconForCategory(String name) {
  // 预设的图标映射，用于已知平台
  const iconMap = {
    'b站': 'assets/icons/bilibili.svg',
    'B站': 'assets/icons/bilibili.svg',
    'bilibili': 'assets/icons/bilibili.svg',
    'Bilibili': 'assets/icons/bilibili.svg',
    '小红书': 'assets/icons/redBook.svg',
    'RedBook': 'assets/icons/redBook.svg',
    'X': 'assets/icons/x.svg',
    'x': 'assets/icons/x.svg',
    'Twitter': 'assets/icons/x.svg',
    'twitter': 'assets/icons/x.svg',
  };
  return iconMap[name] ?? 'assets/icons/home.svg';
}

/// 获取分类图标路径，优先使用数据库存储的 iconPath，否则使用默认映射
String getCategoryIcon(Category category) {
  return category.iconPath ?? getDefaultIconForCategory(category.name);
}

class _CategoryDialog extends ConsumerWidget {
  final List<Category> categories;
  final int currentId;
  final ValueChanged<int> onSelected;

  const _CategoryDialog({
    required this.categories,
    required this.currentId,
    required this.onSelected,
  });

  Future<void> _handleAddCategory(BuildContext context, WidgetRef ref) async {
    final result = await showAddCategoryDialog(context);
    if (result != null) {
      await ref
          .read(categoryActionsProvider.notifier)
          .addCategory(name: result.name, iconPath: result.iconPath);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width > 600;

    // 响应式尺寸
    final dialogWidth = isDesktop ? 280.0 : 260.w;
    final padding = isDesktop ? 16.0 : 14.r;
    final titleSize = isDesktop ? 14.0 : 15.sp;
    final iconBtnSize = isDesktop ? 32.0 : 32.w;

    return Center(
      child: Container(
        width: dialogWidth,
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Padding(
                padding: EdgeInsets.fromLTRB(padding, padding, 8, 8),
                child: Row(
                  children: [
                    Text(
                      '选择分类',
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    // 添加按钮
                    IconButton(
                      onPressed: () => _handleAddCategory(context, ref),
                      icon: Icon(
                        Icons.add_rounded,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      tooltip: '新建分类',
                      style: IconButton.styleFrom(
                        minimumSize: Size(iconBtnSize, iconBtnSize),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              // 分类列表
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: categories
                        .map(
                          (c) => _CategoryItem(
                            name: c.name,
                            iconPath: getCategoryIcon(c),
                            isSelected: c.id == currentId,
                            onTap: () => onSelected(c.id!),
                            isDesktop: isDesktop,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final String name;
  final String iconPath;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDesktop;

  const _CategoryItem({
    required this.name,
    required this.iconPath,
    required this.isSelected,
    required this.onTap,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 响应式尺寸
    final hPadding = isDesktop ? 12.0 : 12.w;
    final vPadding = isDesktop ? 10.0 : 10.h;
    final iconSize = isDesktop ? 18.0 : 18.w;
    final fontSize = isDesktop ? 13.0 : 14.sp;
    final margin = isDesktop ? 6.0 : 6.w;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: margin, vertical: 2),
        padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              iconPath,
              width: iconSize,
              height: iconSize,
              colorFilter: ColorFilter.mode(
                isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_rounded,
                size: isDesktop ? 16.0 : 16.sp,
                color: colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
