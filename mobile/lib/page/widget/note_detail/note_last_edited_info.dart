import 'package:flutter/material.dart';
import 'package:pocketmind/util/theme_data.dart';

class NoteLastEditedInfo extends StatelessWidget {
  final String formattedDate;

  const NoteLastEditedInfo({super.key, required this.formattedDate});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Text(
      'Last edited on $formattedDate',
      style: TextStyle(
        fontSize: 12,
        fontStyle: FontStyle.italic,
        color: colorScheme.secondary.withValues(alpha: 0.7),
      ),
    );
  }
}
