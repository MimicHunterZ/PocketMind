import 'package:any_link_preview/any_link_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/page/widget/pm_image.dart';

import '../source_info.dart';

// 常量定义（用于保证不同布局下的高度一致性）
final double _kWaterfallImageHeight = 100.w;
final double _kWaterfallPlaceholderContentHeight = 105.w;

/// 瀑布流卡片样式（原 vertical）。
///
/// 适用于双列/多列瀑布流场景，内容区域采用“上图下文”结构。
class WaterfallPreviewCard extends StatelessWidget {
  final String url;
  final Metadata metadata;
  final String? imageUrl;
  final bool hasContent;
  final VoidCallback onTap;
  final bool isDesktop;
  final String? publishDate;
  final bool isHovered;
  final bool titleEnabled;

  const WaterfallPreviewCard({
    super.key,
    required this.url,
    required this.metadata,
    this.imageUrl,
    required this.hasContent,
    required this.onTap,
    this.isDesktop = false,
    this.publishDate,
    this.isHovered = false,
    required this.titleEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEmptyContent =
        (metadata.title == null || metadata.title!.isEmpty) &&
        (metadata.desc == null || metadata.desc!.isEmpty);
    final bool isEmptyImage =
        (metadata.image == null || metadata.image!.isEmpty);

    return _PreviewCardContainer(
      isWaterfallLayout: true,
      hasContent: hasContent,
      isDesktop: isDesktop,
      height: isEmptyContent && isEmptyImage
          ? _kWaterfallPlaceholderContentHeight
          : null,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CardImageSection(
            imageUrl: imageUrl,
            isWaterfallLayout: true,
            isDesktop: isDesktop,
          ),
          _WaterfallContentSection(
            metadata: metadata,
            fixedHeight: isEmptyContent,
            isDesktop: isDesktop,
            publishDate: publishDate,
            isHovered: isHovered,
            titleEnabled: titleEnabled,
          ),
        ],
      ),
    );
  }
}

/// 经典列表卡片样式（原 horizontal）。
///
/// 适用于单列列表场景，内容结构为“左图右文”。
class ClassicListPreviewCard extends StatelessWidget {
  final String url;
  final Metadata metadata;
  final String? imageUrl;
  final VoidCallback onTap;
  final String? publishDate;
  final bool titleEnabled;

  const ClassicListPreviewCard({
    super.key,
    required this.url,
    required this.metadata,
    this.imageUrl,
    required this.onTap,
    this.publishDate,
    required this.titleEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return _PreviewCardContainer(
      isWaterfallLayout: false,
      height: 120,
      onTap: onTap,
      child: Row(
        children: [
          _CardImageSection(imageUrl: imageUrl, isWaterfallLayout: false),
          _ClassicListContentSection(
            metadata: metadata,
            publishDate: publishDate,
            titleEnabled: titleEnabled,
          ),
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
  final bool isWaterfallLayout;
  final bool hasContent;
  final double? height;
  final bool isDesktop;

  const _PreviewCardContainer({
    required this.child,
    this.onTap,
    required this.isWaterfallLayout,
    this.hasContent = true,
    this.height,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = (isWaterfallLayout && hasContent)
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          )
        : BorderRadius.circular(16);

    final decoration = BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: borderRadius,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: height,
        decoration: decoration,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _CardImageSection extends StatelessWidget {
  final String? imageUrl;
  final bool isWaterfallLayout;
  final bool isDesktop;

  const _CardImageSection({
    required this.imageUrl,
    required this.isWaterfallLayout,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
      return const SizedBox.shrink();
    }

    final height = isDesktop ? 180.w : _kWaterfallImageHeight;
    return SizedBox(
      width: isWaterfallLayout ? double.infinity : 120.w,
      height: isWaterfallLayout ? height : double.infinity,
      child: PMImage(
        pathOrUrl: imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}

class _WaterfallContentSection extends StatelessWidget {
  final Metadata metadata;
  final bool fixedHeight;
  final bool isDesktop;
  final String? publishDate;
  final bool isHovered;
  final bool titleEnabled;

  const _WaterfallContentSection({
    required this.metadata,
    this.fixedHeight = false,
    this.isDesktop = false,
    this.publishDate,
    this.isHovered = false,
    required this.titleEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final titleStyle = textTheme.titleMedium?.copyWith(
      fontSize: isDesktop ? 20.sp : 17.sp,
      color: isHovered ? colorScheme.tertiary : null,
    );

    final descStyle = textTheme.bodyMedium?.copyWith(
      color: colorScheme.secondary,
      fontSize: isDesktop ? 14.sp : 13.sp,
    );

    final padding = isDesktop ? 16.0 : 12.0;

    if (fixedHeight) {
      return Container(
        height: _kWaterfallPlaceholderContentHeight,
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (titleEnabled)
              Text(
                metadata.title ?? '预览失败',
                style: titleStyle?.copyWith(
                  color: metadata.title == null ? colorScheme.error : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (titleEnabled) SizedBox(height: 4.h),
            Expanded(
              child: Text(
                metadata.desc ?? (metadata.title == null ? '无法获取该链接的预览信息' : ''),
                style: descStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: 4.h),
            SourceInfo(metadata: metadata, publishDate: publishDate),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titleEnabled)
            Text(
              metadata.title ?? '预览失败',
              style: titleStyle?.copyWith(
                color: metadata.title == null ? colorScheme.error : null,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (titleEnabled) SizedBox(height: isDesktop ? 10.w : 8.w),
          Text(
            metadata.desc ?? (metadata.title == null ? '无法获取该链接的预览信息' : ''),
            style: descStyle,
            maxLines: isDesktop ? 4 : 3,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isDesktop ? 14.w : 12.w),
          SourceInfo(metadata: metadata, publishDate: publishDate),
        ],
      ),
    );
  }
}

class _ClassicListContentSection extends StatelessWidget {
  final Metadata metadata;
  final String? publishDate;
  final bool titleEnabled;

  const _ClassicListContentSection({
    required this.metadata,
    this.publishDate,
    required this.titleEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (titleEnabled)
              Text(
                metadata.title ?? '预览失败，请检查网络连接',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                  color: metadata.title == null ? colorScheme.error : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (titleEnabled) const SizedBox(height: 4),
            Expanded(
              child: Text(
                metadata.desc ?? (metadata.title == null ? '无法获取该链接的预览信息' : ''),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.secondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            SourceInfo(metadata: metadata, publishDate: publishDate),
          ],
        ),
      ),
    );
  }
}
