import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/providers/app_config_provider.dart';
import 'package:pocketmind/page/widget/pm_image.dart';

import 'source_info.dart';

/// 智能链接预览卡片组件
/// - 仅展示 Note 中的预览数据
/// - 不再进行网络请求
final String tag = 'LinkPreviewCard';

class LinkPreviewCard extends ConsumerWidget {
  final Note note;
  final bool isVertical;
  final bool hasContent;
  final VoidCallback onTap;
  final bool isDesktop;
  final String? publishDate;
  final bool isHovered;

  const LinkPreviewCard({
    super.key,
    required this.note,
    this.isVertical = false,
    required this.hasContent,
    required this.onTap,
    this.isDesktop = false,
    this.publishDate,
    this.isHovered = false,
  });

  String get url => note.url ?? '';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleEnabled = ref.watch(appConfigProvider).titleEnabled;

    // 创建 Metadata 对象用于显示
    final metadata = Metadata();
    metadata.title = note.previewTitle;
    metadata.desc = note.previewContent ?? note.previewDescription;
    metadata.image = note.previewImageUrl;
    metadata.url = note.url;

    return isVertical
        ? _VerticalPreviewCard(
            url: note.url ?? '',
            metadata: metadata,
            imageUrl: note.previewImageUrl,
            hasContent: hasContent,
            onTap: onTap,
            isDesktop: isDesktop,
            publishDate: publishDate,
            isHovered: isHovered,
            titleEnabled: titleEnabled,
          )
        : _HorizontalPreviewCard(
            url: note.url ?? '',
            metadata: metadata,
            imageUrl: note.previewImageUrl,
            onTap: onTap,
            publishDate: publishDate,
            titleEnabled: titleEnabled,
          );
  }
}

// 常量定义 (用于保证高度一致性)

// 垂直布局下，图片区域的固定高度
final double _kVerticalImageHeight = 100.w;
// 垂直布局下，骨架屏和错误卡片"内容区域"的固定高度。
final double _kVerticalPlaceholderContentHeight = 105.w;

// 基础组件
class _BaseCardContainer extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool isVertical;
  final bool hasContent;
  final double? height;
  final bool isDesktop;

  const _BaseCardContainer({
    required this.child,
    this.onTap,
    required this.isVertical,
    this.hasContent = true,
    this.height,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = (isVertical && hasContent)
        ? BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          )
        : BorderRadius.circular(16);

    // 统一使用主题色，移除移动端的独立阴影（由外层 NoteItem 统一控制）
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

// 成功状态组件
class _VerticalPreviewCard extends StatelessWidget {
  final String url;
  final Metadata metadata;
  final String? imageUrl;
  final bool hasContent;
  final VoidCallback onTap;
  final bool isDesktop;
  final String? publishDate;
  final bool isHovered;
  final bool titleEnabled;

  const _VerticalPreviewCard({
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
    // 判断是否为空内容
    final bool isEmptyContent =
        (metadata.title == null || metadata.title!.isEmpty) &&
        (metadata.desc == null || metadata.desc!.isEmpty);
    final bool isEmptyImage =
        (metadata.image == null || metadata.image!.isEmpty);

    // 桌面端图片高度增加
    final imageHeight = isDesktop ? 180.w : _kVerticalImageHeight;

    return _BaseCardContainer(
      isVertical: true,
      hasContent: hasContent,
      isDesktop: isDesktop,
      // 只有空内容时才固定高度,正常内容自适应
      height: isEmptyContent && isEmptyImage
          ? (_kVerticalPlaceholderContentHeight)
          : null,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CardImageSection(
            imageUrl: imageUrl,
            isVertical: true,
            isDesktop: isDesktop,
          ),
          _VerticalContentSection(
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

class _HorizontalPreviewCard extends StatelessWidget {
  final String url;
  final Metadata metadata;
  final String? imageUrl;
  final VoidCallback onTap;
  final String? publishDate;
  final bool titleEnabled;

  const _HorizontalPreviewCard({
    required this.url,
    required this.metadata,
    this.imageUrl,
    required this.onTap,
    this.publishDate,
    required this.titleEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return _BaseCardContainer(
      isVertical: false,
      height: 120,
      onTap: onTap,
      child: Row(
        children: [
          _CardImageSection(imageUrl: imageUrl, isVertical: false),
          _HorizontalContentSection(
            metadata: metadata,
            publishData: publishDate,
            titleEnabled: titleEnabled,
          ),
        ],
      ),
    );
  }
}

// 通用子组件
class _CardImageSection extends StatelessWidget {
  final String? imageUrl;
  final bool isVertical;
  final bool isDesktop;

  const _CardImageSection({
    required this.imageUrl,
    required this.isVertical,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
      return const SizedBox.shrink();
    }
    // 桌面端图片高度增加
    final height = isDesktop ? 180.w : _kVerticalImageHeight;
    return SizedBox(
      width: isVertical ? double.infinity : 120.w,
      height: isVertical ? height : double.infinity,
      child: PMImage(
        pathOrUrl: imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}

class _VerticalContentSection extends StatelessWidget {
  final Metadata metadata;
  final bool fixedHeight;
  final bool isDesktop;
  final String? publishDate;
  final bool isHovered;
  final bool titleEnabled;

  const _VerticalContentSection({
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

    // 标题样式 - 杂志感：衬线字体、紧凑行高、hover高亮
    final titleStyle = textTheme.titleMedium?.copyWith(
      fontSize: isDesktop ? 20.sp : 17.sp,
      color: isHovered ? colorScheme.tertiary : null,
    );

    // 描述样式
    final descStyle = textTheme.bodyMedium?.copyWith(
      color: colorScheme.secondary,
      fontSize: isDesktop ? 14.sp : 13.sp,
    );

    final padding = isDesktop ? 16.0 : 12.0;

    if (fixedHeight) {
      return Container(
        height: _kVerticalPlaceholderContentHeight,
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              metadata.title ?? '预览失败',
              style: titleStyle?.copyWith(
                color: metadata.title == null ? colorScheme.error : null,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4.h),
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
          Text(
            metadata.title ?? '预览失败',
            style: titleStyle?.copyWith(
              color: metadata.title == null ? colorScheme.error : null,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isDesktop ? 10.w : 8.w),
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

class _HorizontalContentSection extends StatelessWidget {
  final Metadata metadata;
  final String? publishData;
  final bool titleEnabled;

  const _HorizontalContentSection({
    required this.metadata,
    this.publishData,
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
            const SizedBox(height: 4),
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
            SourceInfo(metadata: metadata, publishDate: publishData),
          ],
        ),
      ),
    );
  }
}
