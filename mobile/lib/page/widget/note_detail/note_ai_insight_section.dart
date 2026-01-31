import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/page/widget/creative_toast.dart';

class NoteAIInsightSection extends StatelessWidget {
  String aiSummary;
  NoteAIInsightSection({super.key, required this.aiSummary});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 解析 Q&A 格式
    String? question;
    String? answer;

    // 简单的解析逻辑：检查是否以 Q: 开头并包含 \n\nA:
    if (aiSummary.trim().startsWith('Q:') && aiSummary.contains('\n\nA:')) {
      final parts = aiSummary.split('\n\nA:');
      if (parts.length == 2) {
        question = parts[0].substring(2).trim(); // Remove 'Q:'
        answer = parts[1].trim();
      }
    }

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
                // 内容区域
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    vertical: 8.h,
                  ), // Reduced padding
                  child: question != null
                      ? _buildQaContent(context, colorScheme, question, answer!)
                      : _buildSummaryContent(context, colorScheme, aiSummary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryContent(
    BuildContext context,
    ColorScheme colorScheme,
    String text,
  ) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13.sp,
        color: colorScheme.secondary,
        height: 1.5,
      ),
      textAlign: TextAlign.justify,
    );
  }

  Widget _buildQaContent(
    BuildContext context,
    ColorScheme colorScheme,
    String question,
    String answer,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 问题部分
        Container(
          padding: EdgeInsets.only(left: 12.w, top: 4.h, bottom: 4.h),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: colorScheme.tertiary, width: 3.w),
            ),
          ),
          child: Text(
            question,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
              height: 1.4,
            ),
          ),
        ),
        SizedBox(height: 16.h),
        // 回答部分
        Text(
          answer,
          style: TextStyle(
            fontSize: 13.sp,
            color: colorScheme.secondary,
            height: 1.5,
          ),
          textAlign: TextAlign.justify,
        ),
      ],
    );
  }
}
