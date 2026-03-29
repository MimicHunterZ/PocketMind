import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pocketmind/page/home/model/category_theme_icon_registry.dart';

final List<CategoryIconOption> availableCategoryIcons = [
  ...themeCategoryIconOptions.map(
    (icon) => CategoryIconOption(path: icon.assetPath, label: icon.label),
  ),
];

class CategoryIconOption {
  final String path;
  final String label;

  const CategoryIconOption({required this.path, required this.label});
}

class CategoryIconPickerDialog extends StatefulWidget {
  final String? initialIconPath;

  const CategoryIconPickerDialog({super.key, this.initialIconPath});

  @override
  State<CategoryIconPickerDialog> createState() =>
      _CategoryIconPickerDialogState();
}

class _CategoryIconPickerDialogState extends State<CategoryIconPickerDialog> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    final initialPath = widget.initialIconPath;
    if (initialPath == null) {
      _currentIndex = 0;
      return;
    }
    final index = availableCategoryIcons.indexWhere((it) => it.path == initialPath);
    _currentIndex = index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width > 600;

    final dialogWidth = isDesktop ? 320.0 : 300.w;
    final padding = isDesktop ? 24.0 : 20.r;
    final previewSize = isDesktop ? 110.0 : 110.w;
    final titleSize = isDesktop ? 15.0 : 16.sp;

    final current = availableCategoryIcons[_currentIndex];

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
                fontSize: titleSize,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                IconButton(
                  onPressed: _goPrev,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                        child: Container(
                          key: ValueKey(current.path),
                          width: previewSize,
                          height: previewSize,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withValues(
                              alpha: 0.45,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                            ),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: SvgPicture.asset(current.path),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        current.label,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: isDesktop ? 13 : 13.sp,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${_currentIndex + 1}/${availableCategoryIcons.length}',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: isDesktop ? 11 : 11.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _goNext,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            SizedBox(height: 22.h),
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
                  onPressed: () => Navigator.pop(context, current.path),
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

  void _goPrev() {
    setState(() {
      _currentIndex =
          (_currentIndex - 1 + availableCategoryIcons.length) %
          availableCategoryIcons.length;
    });
  }

  void _goNext() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % availableCategoryIcons.length;
    });
  }
}

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
