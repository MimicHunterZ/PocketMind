import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pocketmind/page/widget/category_icon_picker.dart';

/// 添加分类的结果数据
class AddCategoryResult {
  final String name;
  final String? iconPath;

  const AddCategoryResult({required this.name, this.iconPath});
}

/// 统一的添加分类对话框 - 精美设计，适配桌面端
class AddCategoryDialog extends StatefulWidget {
  const AddCategoryDialog({super.key});

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _nameController = TextEditingController();
  final _focusNode = FocusNode();
  String? _selectedIconPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    Navigator.of(
      context,
    ).pop(AddCategoryResult(name: name, iconPath: _selectedIconPath));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width > 600;

    // 响应式尺寸
    final dialogWidth = isDesktop ? 360.0 : 300.w;
    final padding = isDesktop ? 24.0 : 20.r;
    final iconButtonSize = isDesktop ? 44.0 : 44.w;
    final iconSize = isDesktop ? 22.0 : 22.w;
    final titleSize = isDesktop ? 16.0 : 17.sp;
    final hintSize = isDesktop ? 11.0 : 11.sp;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Text(
              '新建分类',
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: padding),

            // 图标和名称输入行
            Row(
              children: [
                // 图标选择按钮
                _IconButton(
                  size: iconButtonSize,
                  iconSize: iconSize,
                  iconPath: _selectedIconPath,
                  colorScheme: colorScheme,
                  onTap: () async {
                    final iconPath = await showCategoryIconPicker(
                      context,
                      initialIconPath: _selectedIconPath,
                    );
                    if (iconPath != null) {
                      setState(() => _selectedIconPath = iconPath);
                    }
                  },
                ),
                const SizedBox(width: 12),
                // 名称输入框
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: '分类名称',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: colorScheme.primary.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 提示文字
            Padding(
              padding: EdgeInsets.only(left: iconButtonSize + 12),
              child: Text(
                '点击左侧图标可选择分类图标',
                style: TextStyle(
                  fontSize: hintSize,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
            SizedBox(height: padding),

            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
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
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('创建'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 图标选择按钮组件
class _IconButton extends StatelessWidget {
  final double size;
  final double iconSize;
  final String? iconPath;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _IconButton({
    required this.size,
    required this.iconSize,
    required this.iconPath,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasIcon = iconPath != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: hasIcon
              ? colorScheme.primary.withValues(alpha: 0.1)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasIcon
                ? colorScheme.primary.withValues(alpha: 0.3)
                : colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Center(
          child: hasIcon
              ? SvgPicture.asset(
                  iconPath!,
                  width: iconSize,
                  height: iconSize,
                  colorFilter: ColorFilter.mode(
                    colorScheme.primary,
                    BlendMode.srcIn,
                  ),
                )
              : Icon(
                  Icons.add_photo_alternate_outlined,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  size: iconSize,
                ),
        ),
      ),
    );
  }
}

/// 显示添加分类对话框
Future<AddCategoryResult?> showAddCategoryDialog(BuildContext context) {
  return showDialog<AddCategoryResult>(
    context: context,
    builder: (context) => const AddCategoryDialog(),
  );
}
