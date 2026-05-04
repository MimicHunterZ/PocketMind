import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/util/theme_data.dart';

class NotePersonalNotesSection extends StatelessWidget {
  final TextEditingController notesController;

  const NotePersonalNotesSection({super.key, required this.notesController});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Text(
                '个人笔记',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: colorScheme.secondary,
                ),
              ),
            ],
          ),

          SizedBox(height: 12.h),

          // 多行输入框 - 无边框风格
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.05,
              ),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: TextField(
              controller: notesController,
              maxLines: 6,
              minLines: 3,
              decoration: InputDecoration(
                hintText: '添加你的想法和注释...',
                hintStyle: TextStyle(
                  fontSize: 13.sp,
                  color: colorScheme.secondary.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16.r),
              ),
              style: TextStyle(
                fontSize: 14.sp,
                color: colorScheme.onSurface,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
