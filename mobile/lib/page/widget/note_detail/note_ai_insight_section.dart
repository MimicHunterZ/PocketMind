import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/page/widget/creative_toast.dart';

class NoteAIInsightSection extends StatelessWidget {
  String aiSummary;
  NoteAIInsightSection({super.key,required this.aiSummary});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w),
      child: Stack(
        children: [
          // 渐变背景光晕
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                gradient: LinearGradient(
                  colors: [
                    colorScheme.tertiary.withValues(alpha: 0.15),
                    Colors.orange.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // 主卡片
          Container(
            margin: EdgeInsets.all(1),
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(15.r),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题行
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 16.sp,
                      color: colorScheme.tertiary,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'AI 洞察',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: colorScheme.tertiary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                // 占位内容
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 24.h),
                  child: Column(
                    children: [
                      Text(
                        aiSummary,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: colorScheme.secondary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
