import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pocketmind/model/category.dart';
import 'package:pocketmind/page/home/category_posts_screen.dart';
import 'package:pocketmind/page/home/model/category_theme_icon_registry.dart';
import 'package:pocketmind/page/home/widgets/themed_category_card.dart';
import 'package:pocketmind/providers/note_providers.dart';

class ThemedCategoryGrid extends ConsumerWidget {
  const ThemedCategoryGrid({super.key, required this.categories});

  final List<Category> categories;

  static int columnsForWidth(double width) {
    if (width < 600) return 2;
    if (width < 1024) return 3;
    if (width < 1440) return 4;
    return 5;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(allNotesProvider);
    final notes = notesAsync.maybeWhen(
      data: (value) => value,
      orElse: () => const [],
    );
    final formatter = DateFormat('yyyy-MM-dd');

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsForWidth(constraints.maxWidth);
        final accents = <Color>[
          const Color(0xFF38BDF8),
          const Color(0xFFD946EF),
          const Color(0xFF10B981),
          const Color(0xFFF59E0B),
          const Color(0xFFFB7185),
        ];

        return GridView.builder(
          key: ValueKey('category-grid-$columns'),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 96),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 24,
            childAspectRatio: 0.82,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final iconPath = _resolveJellyIconPath(category, index);
            final count = notes.where((note) => note.categoryId == category.id).length;
            final createdTime = category.createdTime;
            final createdLabel = createdTime == null
                ? '-'
                : formatter.format(createdTime);

            return ThemedCategoryCard(
              title: category.name,
              description: category.description ?? '暂无描述',
              metaText: '$count 条 · $createdLabel',
              iconPath: iconPath,
              accent: accents[index % accents.length],
              onTap: () {
                final categoryId = category.id;
                if (categoryId == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CategoryPostsScreen(categoryId: categoryId),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _resolveJellyIconPath(Category category, int index) {
    final options = themeCategoryIconOptions;
    if (options.isEmpty) {
      return 'assets/icons/jelly/notes.svg';
    }

    final savedPath = category.iconPath;
    if (savedPath != null && savedPath.startsWith('assets/icons/jelly/')) {
      return savedPath;
    }

    final source = category.name.trim().toLowerCase();
    final byLabel = options.where((option) {
      final label = option.label.trim().toLowerCase();
      return label.isNotEmpty && source.contains(label);
    });
    if (byLabel.isNotEmpty) {
      return byLabel.first.assetPath;
    }

    return options[index % options.length].assetPath;
  }
}
