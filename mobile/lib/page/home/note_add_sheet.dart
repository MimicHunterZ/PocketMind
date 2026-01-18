import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/page/home/mixin/note_editor_logic_mixin.dart';
import 'package:pocketmind/page/widget/category_selector.dart';
import 'package:pocketmind/page/widget/tag_selector.dart';

class NoteEditorRoute extends PageRouteBuilder {
  NoteEditorRoute()
    : super(
        opaque: false, // 允许看到下面的 route
        barrierColor: Colors.transparent, // 不要额外蒙一层黑
        transitionDuration: Duration.zero, // 不用默认的 page 动画
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) =>
            const NoteEditorSheet(),
      );
}

/// 笔记编辑器
class NoteEditorSheet extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  const NoteEditorSheet({super.key, this.onClose});

  @override
  ConsumerState<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends ConsumerState<NoteEditorSheet>
    with SingleTickerProviderStateMixin, NoteEditorLogicMixin {
  // 动画控制器
  late AnimationController _animationController;
  late Animation<Offset> _headerSlideAnimation;
  late Animation<Offset> _bodySlideAnimation;

  @override
  void initState() {
    super.initState();

    // 动画初始化
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // 头部从右向左滑入
    _headerSlideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    // 内容从下向上滑入
    _bodySlideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    // 启动动画
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Future<void> handleClose() async {
    // 反向播放动画
    await _animationController.reverse();
    await super.handleClose();
  }

  // --- UI 构建方法 ---
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = colorScheme.surface;

    final media = MediaQuery.of(context);
    final double headerHeight = 60.h; // 和 _buildHeader 里的高度保持一致
    final double keyboard = media.viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // 用 padding 处理键盘，关掉默认的挤压行为
      resizeToAvoidBottomInset: false,
      body: AnimatedPadding(
        // 键盘出来时，整体内容往上抬，底部空出 keyboard 高度
        padding: EdgeInsets.only(bottom: keyboard),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: SafeArea(
          child: Stack(
            children: [
              // 顶部栏：固定在顶部，高度 headerHeight
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: headerHeight,
                child: SlideTransition(
                  position: _headerSlideAnimation,
                  child: _buildHeader(context),
                ),
              ),

              // 底部编辑区：从 headerHeight 到底（受 AnimatedPadding 影响）
              Positioned(
                left: 0,
                right: 0,
                top: headerHeight,
                bottom: 0, // 键盘出现时，这个 bottom 实际就是“键盘上沿”
                child: SlideTransition(
                  position: _bodySlideAnimation, // (0,1) -> (0,0)
                  child: Container(
                    color: bg, // 整块编辑区域有背景色，哪里滑到哪里就被覆盖
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 20.h,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMetadataBar(context),
                          SizedBox(height: 24.h),
                          _buildImagePreview(context),
                          _buildMainInputs(context),
                          SizedBox(
                            height: media.viewInsets.bottom > 0 ? 300.h : 100.h,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 1. 顶部工具栏
  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 60.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
        color: colorScheme.surface,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 关闭按钮
          IconButton(
            onPressed: handleClose,
            icon: Icon(Icons.close, size: 24.sp),
            color: colorScheme.onSurfaceVariant,
            tooltip: '关闭',
          ),

          // 标题
          Text(
            'NEW ENTRY',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: colorScheme.onSurface.withValues(alpha: 0.38),
            ),
          ),

          // 保存按钮
          ElevatedButton.icon(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            ),
            icon: Icon(Icons.check, size: 16.sp),
            label: Text(
              'Save',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. 元数据栏 (分类、标签、工具按钮)
  Widget _buildMetadataBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.outline.withValues(alpha: 0.2);

    return Wrap(
      spacing: 12.w,
      runSpacing: 12.h,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // 分类选择器
        CategorySelector(
          selectedCategoryId: selectedCategoryId,
          onCategorySelected: selectCategory,
        ),

        // 标签选择器
        TagSelector(tags: tags, onTagsChanged: updateTags),

        // 分割线
        Container(
          width: 1,
          height: 24.h,
          color: borderColor,
          margin: EdgeInsets.symmetric(horizontal: 4.w),
        ),
      ],
    );
  }

  // 3. 图片预览区域
  Widget _buildImagePreview(BuildContext context) {
    if (!isImageInputVisible || localImagePath == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Stack(
        children: [
          Container(
            height: 200.h,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: colorScheme.outlineVariant),
              image: DecorationImage(
                image: FileImage(File(localImagePath!)),
                fit: BoxFit.cover,
                onError: (exception, stackTrace) {},
              ),
            ),
          ),
          Positioned(
            top: 8.h,
            right: 8.w,
            child: GestureDetector(
              onTap: clearImage,
              child: Container(
                padding: EdgeInsets.all(4.r),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, size: 16.sp, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. 主要输入区域 (标题、内容)
  Widget _buildMainInputs(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题输入
        TextField(
          controller: titleController,
          decoration: InputDecoration(
            hintText: 'Untitled',
            border: InputBorder.none,
            hintStyle: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          style: textTheme.bodyLarge,
          maxLines: null,
        ),

        SizedBox(height: 16.h),

        // 内容输入
        TextField(
          controller: contentController,
          decoration: InputDecoration(
            hintText: 'Tell your story...',
            border: InputBorder.none,
            hintStyle: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
              fontFamily: 'Merriweather',
            ),
            contentPadding: EdgeInsets.zero,
          ),
          style: textTheme.bodyLarge?.copyWith(
            height: 1.6,
            fontFamily: 'Merriweather',
            color: colorScheme.onSurface.withValues(alpha: 0.8),
          ),
          maxLines: null, // 自动高度
          minLines: 10, // 最小高度
        ),
      ],
    );
  }
}
