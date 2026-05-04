import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/util/theme_data.dart';

class NoteLinkContentSection extends StatelessWidget {
  final String? previewDescription;
  final TextEditingController contentController;
  final VoidCallback onSave;

  const NoteLinkContentSection({
    super.key,
    this.previewDescription,
    required this.contentController,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final textTheme = context.textTheme;

    final linkDescription = previewDescription;
    final hasDescription =
        linkDescription != null && linkDescription.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 链接正文/描述
        if (hasDescription) ...[
          Text(
            linkDescription,
            style: textTheme.bodyLarge?.copyWith(
              fontSize: 15.sp,
              height: 1.7,
              letterSpacing: 0.1,
              color: colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
          SizedBox(height: 24.h),
          // 分隔线
          Row(
            children: [
              Icon(
                Icons.edit_note_rounded,
                size: 16.sp,
                color: colorScheme.tertiary,
              ),
              SizedBox(width: 8.w),
              Text(
                '个人笔记',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: colorScheme.tertiary,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Container(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
        ],

        // 用户笔记编辑框
        TextField(
          controller: contentController,
          maxLines: null,
          decoration: InputDecoration(
            hintText: '添加你的想法和注释...',
            hintStyle: textTheme.bodyLarge?.copyWith(
              color: colorScheme.secondary.withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          style: textTheme.bodyLarge?.copyWith(
            fontSize: 16.sp,
            height: 1.8,
            letterSpacing: 0.2,
            color: colorScheme.onSurface,
          ),
          onChanged: (_) => onSave(),
        ),
      ],
    );
  }
}
