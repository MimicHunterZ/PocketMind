import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/page/widget/common/immersive_image.dart';
import 'package:pocketmind/util/url_helper.dart';
import 'note_link_content_section.dart';
import 'note_source_link_card.dart';

class NoteOriginalDataSection extends StatelessWidget {
  final Note note;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final ValueChanged<int> onCategorySelected;
  final String categoryName;
  final String formattedDate;
  final String? previewTitle;
  final String? previewContent;
  final bool isLoadingPreview;
  final VoidCallback onSave;
  final Function(String) onLaunchUrl;
  final bool isDesktop;
  final bool titleEnabled;
  final List<String> previewImages;

  const NoteOriginalDataSection({
    super.key,
    required this.note,
    required this.titleController,
    required this.contentController,
    required this.onCategorySelected,
    required this.categoryName,
    required this.formattedDate,
    this.previewTitle,
    this.previewContent,
    required this.isLoadingPreview,
    required this.onSave,
    required this.onLaunchUrl,
    required this.isDesktop,
    required this.titleEnabled,
    this.previewImages = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isLocalImage = UrlHelper.isLocalImagePath(note.url);
    final isHttpsUrl = UrlHelper.containsHttpsUrl(note.url);
    final hasTitle =
        titleEnabled && note.title != null && note.title!.isNotEmpty;

    // 收集可显示的图片
    List<String> displayImages = [];
    bool isNetworkImage = false;

    // 只有本地图片才使用 getFileByRelativePath
    if (isLocalImage && note.url != null) {
      displayImages.add(note.url!);
    }

    // 如果是网络链接且预览图已加载，使用预览图
    if (isHttpsUrl && !isLocalImage) {
      isNetworkImage = true;
      displayImages.addAll(previewImages);
    }

    final hasImages = displayImages.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 图片/画廊区域
        if (hasImages) ...[
          // 图片轮播：
          ImmersiveImageCarousel(images: displayImages, isDesktop: isDesktop),
        ] else if (isNetworkImage && isLoadingPreview) ...[
          // 加载中显示占位
          Container(
            height: isDesktop ? 0.35.sh : 0.25.sh,
            color: colorScheme.surfaceContainerHighest,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],

        // 内容容器
        Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isHttpsUrl &&
                  !isLoadingPreview &&
                  previewTitle != null &&
                  previewTitle!.isNotEmpty) ...[
                SizedBox(height: hasImages ? 16.h : 24.h),
                Text(
                  previewTitle!,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 16.h),
              ],

              // 无图时显示分类和日期
              if (!hasImages && !isLoadingPreview) ...[
                SizedBox(height: 20.h),

                // 标题（无图时）
                if (hasTitle) ...[
                  TextField(
                    controller: titleController,
                    maxLines: null,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      letterSpacing: -0.5,
                      color: colorScheme.onSurface,
                    ),
                    onChanged: (_) => onSave(),
                  ),
                  SizedBox(height: 16.h),
                  // 装饰线
                  Container(
                    width: 60.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: colorScheme.tertiary,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 24.h),
                ],
              ],

              // 网络链接时显示链接标题和正文（来自预览数据）
              if (isHttpsUrl) ...[
                if (!isLoadingPreview)
                  NoteLinkContentSection(
                    previewDescription: previewContent,
                    contentController: contentController,
                    onSave: onSave,
                  ),
              ],

              // 用户笔记区（个人笔记）
              if (!isHttpsUrl) ...[
                // 非链接类型时，content 就是用户内容
                TextField(
                  controller: contentController,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: '记录你的想法...',
                    hintStyle: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.secondary.withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: textTheme.bodyLarge?.copyWith(
                    fontSize: 16.sp,
                    height: 1.8,
                    letterSpacing: 0.2,
                    color: colorScheme.onSurface,
                  ),
                  onChanged: (_) => onSave(),
                ),
              ],

              SizedBox(height: 24.h),

              // 来源链接卡片（仅移动端或无侧边栏时显示）
              if (isHttpsUrl && !isDesktop && note.url != null) ...[
                NoteSourceLinkCard(
                  url: note.url!,
                  isHttpsUrl: isHttpsUrl,
                  onTap: () => onLaunchUrl(note.url!),
                ),
                SizedBox(height: 16.h),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
