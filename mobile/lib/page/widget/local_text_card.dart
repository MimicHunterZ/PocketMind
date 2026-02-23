import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/providers/app_config_provider.dart';

/// 纯文本卡片变体类型
enum TextCardVariant {
  snippet, // 无标题的日志/随笔风格
  quote, // 引用风格（带引号装饰）
  headline, // 大标题风格（强调色背景）
  essay, // 标准文章风格（标题+内容）
}

/// 中文日期格式化
String formatDateChinese(DateTime? date) {
  if (date == null) return '';
  return '${date.year}年${date.month}月${date.day}日';
}

/// 本地纯文本笔记卡片组件
class LocalTextCard extends ConsumerStatefulWidget {
  final Note note;
  final bool isDesktop;
  final bool isHovered;

  const LocalTextCard({
    super.key,
    required this.note,
    this.isDesktop = false,
    this.isHovered = false,
  });

  @override
  ConsumerState<LocalTextCard> createState() => _LocalTextCardState();
}

class _LocalTextCardState extends ConsumerState<LocalTextCard> {
  @override
  void initState() {
    super.initState();
  }

  /// 根据笔记内容特征判断变体类型
  TextCardVariant _determineVariant() {
    final title = widget.note.title?.trim() ?? '';
    final content = widget.note.content?.trim() ?? '';
    final tag = widget.note.tags.join(',').toLowerCase();
    final hasTitle =
        ref.watch(appConfigProvider).titleEnabled && title.isNotEmpty;

    // 无标题的情况
    if (!hasTitle) {
      // 短内容（< 100字符）使用 Quote 风格
      if (content.length < 100) {
        return TextCardVariant.quote;
      }
      return TextCardVariant.snippet;
    }

    // 有标题的情况
    if (tag.contains('quote') || tag.contains('phil')) {
      return TextCardVariant.quote;
    }
    if (title.length < 25 && content.length < 15) {
      return TextCardVariant.headline;
    }
    return TextCardVariant.essay;
  }

  @override
  Widget build(BuildContext context) {
    final variant = _determineVariant();
    final date = formatDateChinese(widget.note.time);

    switch (variant) {
      case TextCardVariant.snippet:
        return _SnippetCard(
          note: widget.note,
          isDesktop: widget.isDesktop,
          formattedDate: date,
          isHovered: widget.isHovered,
        );
      case TextCardVariant.quote:
        return _QuoteCard(
          note: widget.note,
          isDesktop: widget.isDesktop,
          isHovered: widget.isHovered,
        );
      case TextCardVariant.headline:
        return _HeadlineCard(
          note: widget.note,
          isDesktop: widget.isDesktop,
          formattedDate: date,
        );
      case TextCardVariant.essay:
        return _EssayCard(
          note: widget.note,
          isDesktop: widget.isDesktop,
          formattedDate: date,
          isHovered: widget.isHovered,
        );
    }
  }
}

// =============================================================================
// Variant 1: Snippet Card - 无标题的日志/随笔风格
// =============================================================================
class _SnippetCard extends StatelessWidget {
  final Note note;
  final bool isDesktop;
  final String formattedDate;
  final bool isHovered;

  const _SnippetCard({
    required this.note,
    required this.isDesktop,
    required this.formattedDate,
    this.isHovered = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final padding = isDesktop ? 24.w : 16.w;

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部装饰 - 圆点 + 日期
          _DateHeader(date: formattedDate, colorScheme: colorScheme),
          SizedBox(height: 16.w),

          // 内容 - 正常字号斜体，类似日记
          Text(
            note.content ?? '',
            style: textTheme.bodyLarge?.copyWith(
              fontSize: isDesktop ? 16.sp : 15.sp,
              fontStyle: FontStyle.italic,
              height: 1.7,
              color: isHovered ? colorScheme.onSurface : colorScheme.primary,
            ),
            maxLines: 12,
            overflow: TextOverflow.ellipsis,
          ),

          // 底部标签
          if (note.tags.isNotEmpty)
            _TagsFooter(tags: note.tags, colorScheme: colorScheme),
        ],
      ),
    );
  }
}

// =============================================================================
// Variant 2: Quote Card - 引用风格
// =============================================================================
class _QuoteCard extends StatelessWidget {
  final Note note;
  final bool isDesktop;
  final bool isHovered;

  const _QuoteCard({
    required this.note,
    required this.isDesktop,
    this.isHovered = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final padding = isDesktop ? 28.w : 20.w;

    return Stack(
      children: [
        // 背景引号装饰
        Positioned(
          top: 12.w,
          left: 12.w,
          child: Transform.rotate(
            angle: 3.14159, // 180度翻转
            child: Text(
              '"',
              style: TextStyle(
                fontSize: 60.sp,
                fontFamily: 'Merriweather',
                color: colorScheme.tertiary.withValues(alpha: 0.08),
                height: 1,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 12.w,
          right: 12.w,
          child: Text(
            '"',
            style: TextStyle(
              fontSize: 60.sp,
              fontFamily: 'Merriweather',
              color: colorScheme.tertiary.withValues(alpha: 0.08),
              height: 1,
            ),
          ),
        ),

        // 主内容
        Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            children: [
              // 分类标签
              if (note.tags.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(bottom: 16.w),
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.w,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    note.tags.first.trim().toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: colorScheme.tertiary,
                    ),
                  ),
                ),

              // 引用内容 - 居中斜体
              Text(
                '"${note.content ?? note.title ?? ''}"',
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontSize: isDesktop ? 22.sp : 18.sp,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                  color: isHovered ? colorScheme.tertiary : colorScheme.primary,
                ),
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 16.w),

              // 分隔线和署名（仅当有标题时显示）
              if (note.title != null && note.title!.trim().isNotEmpty) ...[
                Container(width: 32.w, height: 1, color: colorScheme.outline),
                SizedBox(height: 12.w),
                Text(
                  '— ${note.title}',
                  style: TextStyle(
                    fontSize: isDesktop ? 13.sp : 12.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: colorScheme.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Variant 3: Headline Card - 大标题风格（强调色背景）
// =============================================================================
class _HeadlineCard extends StatelessWidget {
  final Note note;
  final bool isDesktop;
  final String formattedDate;

  const _HeadlineCard({
    required this.note,
    required this.isDesktop,
    required this.formattedDate,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final padding = isDesktop ? 28.w : 20.w;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.tertiary,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Stack(
        children: [
          // 背景光晕装饰
          Positioned(
            top: -40.w,
            right: -40.w,
            child: Container(
              width: 120.w,
              height: 120.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),

          // 主内容
          Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部信息栏
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (note.tags.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.w,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          note.tags.first.trim().toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      )
                    else
                      const SizedBox(),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.w),

                // 大标题
                Text(
                  note.title ?? '',
                  style: textTheme.titleLarge?.copyWith(
                    fontSize: isDesktop ? 32.sp : 28.sp,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 24.w),

                // 底部提示
                Row(
                  children: [
                    Text(
                      'Read Entry',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      width: 24.w,
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Variant 4: Essay Card - 标准文章风格
// =============================================================================
class _EssayCard extends StatelessWidget {
  final Note note;
  final bool isDesktop;
  final String formattedDate;
  final bool isHovered;

  const _EssayCard({
    required this.note,
    required this.isDesktop,
    required this.formattedDate,
    this.isHovered = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final padding = isDesktop ? 24.w : 16.w;

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部：标签 + 日期
          _TagDateHeader(
            tags: note.tags,
            date: formattedDate,
            colorScheme: colorScheme,
          ),
          SizedBox(height: 12.w),

          // 标题 - hover时高亮
          Text(
            note.title ?? '',
            style: textTheme.titleMedium?.copyWith(
              fontSize: isDesktop ? 22.sp : 20.sp,
              height: 1.2,
              color: isHovered ? colorScheme.tertiary : null,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 10.w),

          // 内容摘要
          if (note.content != null && note.content!.isNotEmpty)
            Text(
              note.content!.length > 200
                  ? '${note.content!.substring(0, 200)}...'
                  : note.content!,
              style: textTheme.bodyMedium?.copyWith(
                fontSize: isDesktop ? 14.sp : 13.sp,
                height: 1.6,
                color: colorScheme.secondary,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          SizedBox(height: 16.w),

          // 底部阅读提示
          _ReadMoreFooter(colorScheme: colorScheme, isHovered: isHovered),
        ],
      ),
    );
  }
}

// =============================================================================
// 共享组件
// =============================================================================

/// 日期头部（圆点 + 日期）
class _DateHeader extends StatelessWidget {
  final String date;
  final ColorScheme colorScheme;

  const _DateHeader({required this.date, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6.w,
          height: 6.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.outline,
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          date,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            color: colorScheme.secondary,
          ),
        ),
      ],
    );
  }
}

/// 标签 + 日期头部
class _TagDateHeader extends StatelessWidget {
  final List<String> tags;
  final String date;
  final ColorScheme colorScheme;

  const _TagDateHeader({
    required this.tags,
    required this.date,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tags.isNotEmpty)
          Flexible(
            child: Wrap(
              spacing: 6.w,
              runSpacing: 4.w,
              children: tags
                  .take(2)
                  .map(
                    (tag) =>
                        _TagBadge(tag: tag.trim(), colorScheme: colorScheme),
                  )
                  .toList(),
            ),
          )
        else
          const SizedBox(),
        Text(
          date,
          style: TextStyle(fontSize: 11.sp, color: colorScheme.secondary),
        ),
      ],
    );
  }
}

/// 标签徽章
class _TagBadge extends StatelessWidget {
  final String tag;
  final ColorScheme colorScheme;

  const _TagBadge({required this.tag, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.w),
      decoration: BoxDecoration(
        color: colorScheme.outline.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        tag.toUpperCase(),
        style: TextStyle(
          fontSize: 9.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: colorScheme.secondary,
        ),
      ),
    );
  }
}

/// 标签底部
class _TagsFooter extends StatelessWidget {
  final List<String> tags;
  final ColorScheme colorScheme;

  const _TagsFooter({required this.tags, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 16.w),
      padding: EdgeInsets.only(top: 12.w),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
        ),
      ),
      child: Wrap(
        spacing: 8.w,
        children: tags
            .map(
              (tag) => Text(
                '#${tag.trim()}',
                style: TextStyle(fontSize: 11.sp, color: colorScheme.secondary),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// 阅读更多底部
class _ReadMoreFooter extends StatelessWidget {
  final ColorScheme colorScheme;
  final bool isHovered;

  const _ReadMoreFooter({required this.colorScheme, this.isHovered = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 12.w),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isHovered ? colorScheme.tertiary : colorScheme.outline,
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            'Read full entry',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: isHovered ? colorScheme.primary : colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
