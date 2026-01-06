import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/page/widget/tag_selector.dart';

class NoteTagsSection extends StatelessWidget {
  final List<String> tags;
  final ValueChanged<List<String>> onTagsChanged;

  const NoteTagsSection({
    super.key,
    required this.tags,
    required this.onTagsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Text(
            '标签',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: colorScheme.secondary,
            ),
          ),

          SizedBox(height: 12.h),

          // 标签选择器
          TagSelector(tags: tags, onTagsChanged: onTagsChanged, hintText: '添加'),
        ],
      ),
    );
  }
}
