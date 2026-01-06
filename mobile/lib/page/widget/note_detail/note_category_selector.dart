import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pocketmind/page/widget/category_icon_picker.dart';
import 'package:pocketmind/page/widget/category_selector.dart';
import 'package:pocketmind/providers/category_providers.dart';

class NoteCategorySelector extends ConsumerStatefulWidget {
  final int currentCategoryId;
  final Function(int) onCategorySelected;
  final Future<void> Function(String name, String? iconPath) onAddCategory;

  const NoteCategorySelector({
    super.key,
    required this.currentCategoryId,
    required this.onCategorySelected,
    required this.onAddCategory,
  });

  @override
  ConsumerState<NoteCategorySelector> createState() =>
      _NoteCategorySelectorState();
}

class _NoteCategorySelectorState extends ConsumerState<NoteCategorySelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _addCategoryAnimationController;
  late Animation<Offset> _categoryBarSlideAnimation;
  late Animation<Offset> _addCategoryBarSlideAnimation;
  final TextEditingController _addCategoryController = TextEditingController();
  final FocusNode _addCategoryFocusNode = FocusNode();
  bool _isAddCategoryMode = false;
  String? _selectedIconPath;

  @override
  void initState() {
    super.initState();
    _addCategoryAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _categoryBarSlideAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1)).animate(
          CurvedAnimation(
            parent: _addCategoryAnimationController,
            curve: Curves.easeInOut,
          ),
        );

    _addCategoryBarSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _addCategoryAnimationController,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  void dispose() {
    _addCategoryAnimationController.dispose();
    _addCategoryController.dispose();
    _addCategoryFocusNode.dispose();
    super.dispose();
  }

  void _toggleAddCategoryMode() {
    setState(() {
      _isAddCategoryMode = !_isAddCategoryMode;
      if (_isAddCategoryMode) {
        _addCategoryAnimationController.forward();
        _addCategoryFocusNode.requestFocus();
      } else {
        _addCategoryAnimationController.reverse();
        _addCategoryFocusNode.unfocus();
        _addCategoryController.clear();
        _selectedIconPath = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return Container(
      constraints: BoxConstraints(maxHeight: 0.6.sh),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 顶部栏
            ClipRect(
              child: Stack(
                children: [
                  // 普通标题栏
                  SlideTransition(
                    position: _categoryBarSlideAnimation,
                    child: Container(
                      padding: EdgeInsets.all(20.r),
                      child: Row(
                        children: [
                          Text(
                            '选择分类',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _toggleAddCategoryMode,
                            color: colorScheme.surfaceContainerHighest,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 添加分类输入栏
                  SlideTransition(
                    position: _addCategoryBarSlideAnimation,
                    child: _buildAddCategoryBar(colorScheme),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // 分类列表
            Expanded(
              child: categoriesAsync.when(
                data: (categories) {
                  return ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected =
                          category.id == widget.currentCategoryId;

                      final iconPath = getCategoryIcon(category);
                      return ListTile(
                        leading: SvgPicture.asset(
                          iconPath,
                          width: 20.w,
                          height: 20.w,
                          colorFilter: ColorFilter.mode(
                            isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            BlendMode.srcIn,
                          ),
                        ),
                        title: Text(
                          category.name,
                          style: TextStyle(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check,
                                color: colorScheme.surfaceContainerHighest,
                              )
                            : null,
                        onTap: () {
                          widget.onCategorySelected(category.id ?? 0);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('加载失败: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCategoryBar(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.all(16.r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 名称输入行
          Row(
            children: [
              // 图标选择按钮
              GestureDetector(
                onTap: () async {
                  final iconPath = await showCategoryIconPicker(
                    context,
                    initialIconPath: _selectedIconPath,
                  );
                  if (iconPath != null) {
                    setState(() => _selectedIconPath = iconPath);
                  }
                },
                child: Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Center(
                    child: _selectedIconPath != null
                        ? SvgPicture.asset(
                            _selectedIconPath!,
                            width: 24.w,
                            height: 24.w,
                            colorFilter: ColorFilter.mode(
                              colorScheme.primary,
                              BlendMode.srcIn,
                            ),
                          )
                        : Icon(
                            Icons.add_photo_alternate_outlined,
                            color: colorScheme.onSurfaceVariant,
                            size: 22.sp,
                          ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              // 名称输入框
              Expanded(
                child: TextField(
                  controller: _addCategoryController,
                  focusNode: _addCategoryFocusNode,
                  decoration: InputDecoration(
                    hintText: '输入新分类名称',
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: colorScheme.primary),
                    ),
                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  style: TextStyle(color: colorScheme.onSurface),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          // 操作按钮行
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _toggleAddCategoryMode,
                child: Text(
                  '取消',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
              SizedBox(width: 8.w),
              FilledButton.icon(
                onPressed: () async {
                  final categoryName = _addCategoryController.text.trim();
                  if (categoryName.isNotEmpty) {
                    await widget.onAddCategory(categoryName, _selectedIconPath);
                    _toggleAddCategoryMode();
                  }
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('添加'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
