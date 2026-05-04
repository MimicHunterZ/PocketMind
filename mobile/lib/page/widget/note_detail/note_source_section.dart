import 'package:flutter/material.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/util/url_helper.dart';
import 'package:pocketmind/util/theme_data.dart';

class NoteSourceSection extends StatelessWidget {
  final Note note;
  final Function(String) onLaunchUrl;

  const NoteSourceSection({
    super.key,
    required this.note,
    required this.onLaunchUrl,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    final isHttpsUrl = UrlHelper.containsHttpsUrl(note.url);
    if (!isHttpsUrl) return const SizedBox.shrink();

    final domain = UrlHelper.extractDomain(note.url ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SOURCE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () {
            final url = note.url;
            if (url != null && url.isNotEmpty) {
              onLaunchUrl(url);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.language_rounded,
                  size: 20,
                  color: colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    domain,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 16,
                  color: colorScheme.tertiary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
