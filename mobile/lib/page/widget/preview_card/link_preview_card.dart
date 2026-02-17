import 'package:any_link_preview/any_link_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/providers/app_config_provider.dart';

import 'preview_success_cards.dart';
import 'scraping_skeleton_card.dart';

/// 链接预览卡片编排入口。
///
/// 1) 将 Note 转换为可渲染的 Metadata；
/// 2) 根据状态选择 skeleton 或成功态卡片；
/// 3) 根据布局类型分发到对应样式组件。
final String tag = 'LinkPreviewCard';

class LinkPreviewCard extends ConsumerWidget {
  final Note note;

  /// `true` 表示瀑布流卡片样式
  /// `false` 表示经典单列卡片样式。
  final bool isWaterfall;

  final bool hasContent;
  final VoidCallback onTap;
  final bool isDesktop;
  final String? publishDate;
  final bool isHovered;
  final bool isLoading;

  const LinkPreviewCard({
    super.key,
    required this.note,
    required this.isWaterfall,
    required this.hasContent,
    required this.onTap,
    this.isDesktop = false,
    this.publishDate,
    this.isHovered = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLoading) {
      return ScrapingSkeletonCard(
        isVertical: isWaterfall,
        url: note.url,
        publishDate: publishDate,
      );
    }

    if (isWaterfall) {
      return WaterfallPreviewCard(
        url: note.url ?? '',
        note: note,
        hasContent: hasContent,
        onTap: onTap,
        isDesktop: isDesktop,
        publishDate: publishDate,
        isHovered: isHovered,
      );
    }

    return ClassicListPreviewCard(
      url: note.url ?? '',
      note: note,
      onTap: onTap,
      publishDate: publishDate,
    );
  }
}
