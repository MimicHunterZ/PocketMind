import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 可选的分类图标列表
const List<CategoryIconOption> availableCategoryIcons = [
  CategoryIconOption(path: 'assets/icons/home.svg', label: '默认'),
  CategoryIconOption(path: 'assets/icons/bilibili.svg', label: 'B站'),
  CategoryIconOption(path: 'assets/icons/redBook.svg', label: '小红书'),
  CategoryIconOption(path: 'assets/icons/x.svg', label: 'X'),
];

class CategoryIconOption {
  final String path;
  final String label;

  const CategoryIconOption({required this.path, required this.label});
}

/// 图标选择弹窗 - 精美设计，适配桌面端
class CategoryIconPickerDialog extends StatefulWidget {
  final String? initialIconPath;

  const CategoryIconPickerDialog({super.key, this.initialIconPath});

  @override
  State<CategoryIconPickerDialog> createState() =>
      _CategoryIconPickerDialogState();
}

class _CategoryIconPickerDialogState extends State<CategoryIconPickerDialog> {
  late String? _selectedPath;

  @override
  void initState() {
    super.initState();
    _selectedPath = widget.initialIconPath;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width > 600;

    // 桌面端使用固定尺寸，移动端使用响应式
    final dialogWidth = isDesktop ? 320.0 : 280.w;
    final iconSize = isDesktop ? 52.0 : 56.w;
    final iconInnerSize = isDesktop ? 24.0 : 26.w;
    final spacing = isDesktop ? 16.0 : 14.w;
    final padding = isDesktop ? 24.0 : 20.r;
    final fontSize = isDesktop ? 14.0 : 15.sp;
    final labelSize = isDesktop ? 11.0 : 10.sp;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: dialogWidth,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '选择图标',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: padding),
            // 图标网格
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              alignment: WrapAlignment.center,
              children: availableCategoryIcons.map((icon) {
                final isSelected =
                    _selectedPath == icon.path ||
                    (_selectedPath == null &&
                        icon == availableCategoryIcons.first);

                return GestureDetector(
                  onTap: () => setState(() => _selectedPath = icon.path),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.12)
                          : colorScheme.surfaceContainerHighest.withValues(
                              alpha: 0.5,
                            ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary.withValues(alpha: 0.5)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          icon.path,
                          width: iconInnerSize,
                          height: iconInnerSize,
                          colorFilter: ColorFilter.mode(
                            isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          icon.label,
                          style: TextStyle(
                            fontSize: labelSize,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: padding),
            // 按钮行
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _selectedPath),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('确定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 显示图标选择对话框
Future<String?> showCategoryIconPicker(
  BuildContext context, {
  String? initialIconPath,
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        CategoryIconPickerDialog(initialIconPath: initialIconPath),
  );
}
