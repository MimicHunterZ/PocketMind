import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 标签选择器
///
/// 统一的标签管理组件，支持：
/// 1. 展示现有标签 (Chip 样式)
/// 2. 删除标签
/// 3. 添加新标签 (输入框)
/// 4. 桌面/移动端适配
class TagSelector extends StatefulWidget {
  final List<String> tags;
  final ValueChanged<List<String>> onTagsChanged;
  final String hintText;

  const TagSelector({
    super.key,
    required this.tags,
    required this.onTagsChanged,
    this.hintText = 'Add Tag',
  });

  @override
  State<TagSelector> createState() => _TagSelectorState();
}

class _TagSelectorState extends State<TagSelector> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isInputVisible = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitTag() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !widget.tags.contains(text)) {
      final newTags = List<String>.from(widget.tags)..add(text);
      widget.onTagsChanged(newTags);
      _controller.clear();
      // 保持焦点以便继续输入
      _focusNode.requestFocus();
    } else {
      // 空内容或重复，关闭输入框
      setState(() {
        _isInputVisible = false;
      });
    }
  }

  void _removeTag(String tag) {
    final newTags = List<String>.from(widget.tags)..remove(tag);
    widget.onTagsChanged(newTags);
  }

  void _showInput() {
    setState(() {
      _isInputVisible = true;
    });
    // 等待 UI 构建完成后获取焦点
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.outline.withValues(alpha: 0.2);
    final iconColor = colorScheme.onSurfaceVariant;

    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // 1. 已存在的标签
        ...widget.tags.map((tag) => _buildTagChip(context, tag)),

        // 2. 输入框 或 添加按钮
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: _isInputVisible
              ? _buildInput(context)
              : _buildAddButton(context, borderColor, iconColor),
        ),
      ],
    );
  }

  Widget _buildTagChip(BuildContext context, String tag) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$tag',
            style: TextStyle(
              fontSize: 12.sp,
              color: colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 4.w),
          InkWell(
            onTap: () => _removeTag(tag),
            borderRadius: BorderRadius.circular(10.r),
            child: Icon(
              Icons.close,
              size: 14.sp,
              color: colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.outline.withValues(alpha: 0.2);

    return Container(
      width: 120.w,
      height: 32.h,
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: '输入标签...',
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          hintStyle: TextStyle(
            fontSize: 12.sp,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
        style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurface),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submitTag(),
        // 失去焦点时自动提交
        onEditingComplete: _submitTag,
        onTapOutside: (_) {
          if (_controller.text.isEmpty) {
            setState(() {
              _isInputVisible = false;
            });
          } else {
            _submitTag();
          }
        },
      ),
    );
  }

  Widget _buildAddButton(
    BuildContext context,
    Color borderColor,
    Color iconColor,
  ) {
    return InkWell(
      onTap: _showInput,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_offer_outlined, size: 14.sp, color: iconColor),
            SizedBox(width: 6.w),
            Text(
              widget.hintText,
              style: TextStyle(
                fontSize: 12.sp,
                color: iconColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
