import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketmind/core/constants.dart';
import 'package:pocketmind/router/route_paths.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/service/note_service.dart';
import 'package:pocketmind/util/url_helper.dart';
import 'preview_card/link_preview_card.dart';
import 'pm_image.dart';
import 'local_text_card.dart';

String tag = 'noteItem';

class NoteItem extends ConsumerStatefulWidget {
  final Note note;
  final bool isWaterfall;
  final bool isDesktop;

  final NoteService noteService;

  const NoteItem({
    required this.note,
    required this.noteService,
    required this.isWaterfall,
    this.isDesktop = false,
    super.key,
  });

  @override
  ConsumerState<NoteItem> createState() => _NoteItemState();
}

class _NoteItemState extends ConsumerState<NoteItem>
    with AutomaticKeepAliveClientMixin {
  // 保持 widget 状态，避免滚动时被销毁重建
  @override
  bool get wantKeepAlive => true;

  bool _isHovered = false;

  // 显示笔记详情页
  void _showNoteDetail(BuildContext context) {
    context.go(RoutePaths.noteDetail, extra: widget.note);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  bool _isLinkScraping(Note note) {
    if (!UrlHelper.containsHttpsUrl(note.url)) {
      return false;
    }

    return note.resourceStatus == AppConstants.resourceStatusScraping ||
        note.resourceStatus == AppConstants.resourceStatusPending;
  }

  @override
  Widget build(BuildContext context) {
    // 必须调用 super.build，让 AutomaticKeepAliveClientMixin 工作
    super.build(context);

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // 判断是否为纯文本笔记
    final isTextOnly = widget.note.url == null ? true : false;
    final isHttpsUrl = UrlHelper.containsHttpsUrl(widget.note.url);
    final isLocalImage = UrlHelper.isLocalImagePath(widget.note.url);
    final isLinkScraping = _isLinkScraping(widget.note);

    final content = widget.note.content;

    // 桌面端样式调整
    final margin = widget.isDesktop
        ? EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.w)
        : (widget.isWaterfall
              ? EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.w)
              : EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.w));

    // 桌面端悬停效果
    final transform = widget.isDesktop && _isHovered
        ? Matrix4.identity().scaled(1.02)
        : Matrix4.identity();

    final shadow = widget.isDesktop && _isHovered
        ? [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ]
        : [
            BoxShadow(
              color: Theme.of(context).shadowColor,
              blurRadius: 20,
              spreadRadius: -5,
              offset: const Offset(0, 4),
            ),
          ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.2)
        : Colors.black.withValues(alpha: 0.1);

    // 抓取中：整卡直接替换为 skeleton，避免旧卡片+loading 卡片嵌套。
    if (isHttpsUrl && isLinkScraping) {
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          margin: margin,
          child: LinkPreviewCard(
            note: widget.note,
            isLoading: true,
            isWaterfall: widget.isWaterfall,
            hasContent: false,
            onTap: () {},
            isDesktop: widget.isDesktop,
            publishDate: _formatDate(widget.note.time),
            isHovered: _isHovered,
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: transform,
        transformAlignment: Alignment.center,
        margin: margin,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: shadow,
        ),
        child: InkWell(
          onTap: isLinkScraping ? null : () => _showNoteDetail(context),
          borderRadius: BorderRadius.circular(16.r),
          child: isTextOnly
              // 1. 纯文本模式：
              ? LocalTextCard(
                  note: widget.note,
                  isDesktop: widget.isDesktop,
                  isHovered: _isHovered,
                )
              : isLocalImage
              // 2. 本地图片模式
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 图片部分
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16.r),
                      ),
                      child: AspectRatio(
                        aspectRatio: widget.isWaterfall ? 1.0 : 16 / 9,
                        child: PMImage(
                          pathOrUrl: widget.note.url!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    // 图片下面的文字部分
                    if (content != null && content.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.all(widget.isDesktop ? 16.w : 12.w),
                        child: Text(
                          content,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: widget.isDesktop ? 15.sp : null,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                )
              : isHttpsUrl
              // 3. HTTPS 链接模式
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 链接卡片部分
                    LinkPreviewCard(
                      note: widget.note,
                      isLoading: isLinkScraping,
                      isWaterfall: widget.isWaterfall,
                      hasContent: content != null && content.isNotEmpty,
                      onTap: () => _showNoteDetail(context),
                      isDesktop: widget.isDesktop,
                      publishDate: _formatDate(widget.note.time),
                      isHovered: _isHovered,
                    ),
                    // 链接卡片下面的文字部分
                    if (content != null && content.isNotEmpty) ...[
                      if (widget.isWaterfall)
                        Divider(
                          color: colorScheme.outline,
                          thickness: 1.0,
                          height: 5.w,
                          indent: 12.w, // 左侧缩进
                          endIndent: 12.w, // 右侧缩进
                        ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 8.w,
                        ),
                        child: Text(
                          content,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: widget.isDesktop ? 15.sp : null,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                )
              // 4. 其他URL
              : Container(
                  padding: EdgeInsets.all(widget.isDesktop ? 24.w : 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.note.url != null)
                        Text(
                          widget.note.url!,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (content != null && content.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          content,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: widget.isDesktop ? 15.sp : null,
                          ),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
