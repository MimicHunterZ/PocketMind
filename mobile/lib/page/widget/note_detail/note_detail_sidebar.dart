import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/model/note.dart';
import 'note_ai_insight_section.dart';
import 'note_source_section.dart';
import 'note_tags_section.dart';
import 'note_last_edited_info.dart';

class NoteDetailSidebar extends StatelessWidget {
  final Note note;
  final Function(String) onLaunchUrl;
  final List<String> tags;
  final ValueChanged<List<String>> onTagsChanged;
  final String formattedDate;

  const NoteDetailSidebar({
    super.key,
    required this.note,
    required this.onLaunchUrl,
    required this.tags,
    required this.onTagsChanged,
    required this.formattedDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI 洞察区
        if (note.aiSummary != null && note.aiSummary!.isNotEmpty)
          NoteAIInsightSection(
            aiSummary: note.aiSummary!,
          ), //

        SizedBox(height: 32.h),

        // 来源信息
        NoteSourceSection(note: note, onLaunchUrl: onLaunchUrl),

        SizedBox(height: 24.h),

        // 标签区
        NoteTagsSection(tags: tags, onTagsChanged: onTagsChanged),

        SizedBox(height: 24.h),

        // 最后编辑时间
        NoteLastEditedInfo(formattedDate: formattedDate),
      ],
    );
  }
}
