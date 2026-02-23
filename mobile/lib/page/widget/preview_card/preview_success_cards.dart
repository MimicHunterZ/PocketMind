import 'package:any_link_preview/any_link_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/page/widget/pm_image.dart';

import '../source_info.dart';

// 常量定义（用于保证不同布局下的高度一致性）
final double _kWaterfallPlaceholderContentHeight = 105.w;
final double _kClassicCardHeight = 120.w;

/// 瀑布流卡片样式
///
/// 适用于双列/多列瀑布流场景，内容区域采用“上图下文”结构。
class WaterfallPreviewCard extends StatelessWidget {
  final String url;
  final Note note;
  final bool hasContent;
  final VoidCallback onTap;
  final bool isDesktop;
  final String? publishDate;
  final bool isHovered;

  const WaterfallPreviewCard({
    super.key,
    required this.url,
    required this.note,
    required this.hasContent,
    required this.onTap,
    this.isDesktop = false,
    this.publishDate,
    this.isHovered = false,
  });

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = note.firstPreviewImage;
    final bool isEmptyContent = note.hasNoTitle;
    final bool isEmptyImage = imageUrl == null || imageUrl.isEmpty;

    // 当图片和内容都为空时，固定高度以保持布局整齐
    final double? fixedHeight = (isEmptyContent && isEmptyImage)
        ? _kWaterfallPlaceholderContentHeight
        : null;

    return _PreviewCardContainer(
      borderRadius: (hasContent)
          ? const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            )
          : BorderRadius.circular(16),
      height: fixedHeight,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CardImageSection.waterfall(imageUrl: imageUrl, isDesktop: isDesktop),
          _WaterfallContentSection(
            note: note,
            isFixedMode: isEmptyContent,
            isDesktop: isDesktop,
            publishDate: publishDate,
            isHovered: isHovered,
          ),
        ],
      ),
    );
  }
}

/// 经典列表卡片样式
///
/// 适用于单列列表场景，内容结构为“左图右文”。
class ClassicListPreviewCard extends StatelessWidget {
  final String url;
  final Note note;
  final VoidCallback onTap;
  final String? publishDate;

  const ClassicListPreviewCard({
    super.key,
    required this.url,
    required this.note,
    required this.onTap,
    this.publishDate,
  });

  @override
  Widget build(BuildContext context) {
    return _PreviewCardContainer(
      borderRadius: BorderRadius.circular(16),
      height: _kClassicCardHeight,
      onTap: onTap,
      child: Row(
        children: [
          _CardImageSection.classic(imageUrl: note.firstPreviewImage),
          _ClassicListContentSection(note: note, publishDate: publishDate),
        ],
      ),
    );
  }
}

/// 成功态预览卡片的基础容器。
///
/// 负责统一点击交互与圆角裁切策略。
class _PreviewCardContainer extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadiusGeometry borderRadius;
  final double? height;

  const _PreviewCardContainer({
    required this.child,
    this.onTap,
    required this.borderRadius,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: borderRadius is BorderRadius
          ? borderRadius as BorderRadius
          : BorderRadius.circular(16),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: borderRadius,
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _CardImageSection extends StatelessWidget {
  final String? imageUrl;
  final bool isWaterfall;
  final bool isDesktop;

  const _CardImageSection._({
    required this.imageUrl,
    required this.isWaterfall,
    this.isDesktop = false,
  });

  factory _CardImageSection.waterfall({
    required String? imageUrl,
    bool isDesktop = false,
  }) {
    return _CardImageSection._(
      imageUrl: imageUrl,
      isWaterfall: true,
      isDesktop: isDesktop,
    );
  }

  factory _CardImageSection.classic({required String? imageUrl}) {
    return _CardImageSection._(imageUrl: imageUrl, isWaterfall: false);
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    final imageWidget = PMImage(
      pathOrUrl: imageUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: isWaterfall ? null : double.infinity,
    );

    if (isWaterfall) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: isDesktop ? 600.w : 350.w),
        child: imageWidget,
      );
    }

    return SizedBox(width: 120.w, height: double.infinity, child: imageWidget);
  }
}

class _WaterfallContentSection extends StatelessWidget {
  final Note note;
  final bool isFixedMode; // 重命名语义更清晰
  final bool isDesktop;
  final String? publishDate;
  final bool isHovered;

  const _WaterfallContentSection({
    required this.note,
    this.isFixedMode = false,
    this.isDesktop = false,
    this.publishDate,
    this.isHovered = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final titleStyle = textTheme.titleMedium?.copyWith(
      fontSize: isDesktop ? 20.sp : 17.sp,
      color: isHovered ? colorScheme.tertiary : null,
    );

    final descStyle = textTheme.bodyMedium?.copyWith(
      color: colorScheme.secondary,
      fontSize: isDesktop ? 14.sp : 13.sp,
    );

    final padding = isDesktop ? 16.0 : 12.0;

    // 统一构建内容列，减少重复代码
    final contentColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: isFixedMode ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Text(
          note.displayTitle,
          style: titleStyle?.copyWith(
            color: note.hasNoTitle ? colorScheme.error : null,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: isDesktop ? 10.w : 8.w),
        isFixedMode
            ? Expanded(child: _buildDescText(note, descStyle, maxLines: 2))
            : _buildDescText(note, descStyle, maxLines: isDesktop ? 4 : 3),
        SizedBox(height: isDesktop ? 14.w : 12.w),
        SourceInfo(url: note.url, publishDate: publishDate),
      ],
    );

    return Container(
      height: isFixedMode ? _kWaterfallPlaceholderContentHeight : null,
      padding: EdgeInsets.all(padding),
      child: contentColumn,
    );
  }

  Widget _buildDescText(Note note, TextStyle? style, {required int maxLines}) {
    return Text(
      note.displayDescription,
      style: style,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ClassicListContentSection extends StatelessWidget {
  final Note note;
  final String? publishDate;

  const _ClassicListContentSection({required this.note, this.publishDate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note.displayTitle,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
                color: note.hasNoTitle ? colorScheme.error : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                note.displayDescription,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.secondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            SourceInfo(url: note.url, publishDate: publishDate),
          ],
        ),
      ),
    );
  }
}

// 扩展方法定义
extension NotePreviewExtension on Note {
  String? get firstPreviewImage => previewImageUrl;

  bool get hasNoTitle => (previewTitle == null || previewTitle!.isEmpty);

  String get displayTitle => hasNoTitle ? '预览失败' : previewTitle!;

  String get displayDescription =>
      previewContent ?? previewDescription ?? '无法获取该链接的预览信息';
}
