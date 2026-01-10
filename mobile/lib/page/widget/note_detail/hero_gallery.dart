import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/page/widget/pm_image.dart';
import 'package:pocketmind/page/widget/common/category_badge.dart';
import 'package:pocketmind/page/widget/common/date_label.dart';

class HeroGallery extends StatefulWidget {
  final List<String> images;
  final String title;
  final bool isDesktop;
  final double? height;
  final VoidCallback? onImageTap;
  final bool showGradientFade;
  final String? categoryLabel;
  final Widget? categoryBadge;
  final String? dateLabel;
  final String? overlayTitle;

  const HeroGallery({
    super.key,
    required this.images,
    this.title = '',
    this.isDesktop = false,
    this.height,
    this.onImageTap,
    this.showGradientFade = true,
    this.categoryLabel,
    this.categoryBadge,
    this.dateLabel,
    this.overlayTitle,
  });

  @override
  State<HeroGallery> createState() => _HeroGalleryState();
}

class _HeroGalleryState extends State<HeroGallery> {
  int _currentSlide = 0;
  late PageController _pageController;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextSlide() {
    if (_currentSlide < widget.images.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevSlide() {
    if (_currentSlide > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _pageController.animateToPage(
        widget.images.length - 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();

    final defaultHeight = widget.isDesktop
        ? (widget.images.length == 1 ? 0.50.sh : 0.55.sh)
        : (widget.images.length == 1 ? 0.40.sh : 0.45.sh);
    final totalHeight = widget.height ?? defaultHeight;

    // 获取背景色
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: SizedBox(
        height: totalHeight, // 1. 这是一个定高的容器
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand, // 填满容器
          children: [
            // --- 层级 1：图片层 ---
            // 图片只占总高度的 70%，且贴顶放置
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: totalHeight * 0.7,
              child: _buildImageContent(),
            ),

            // --- 层级 2：全局渐变层 (The Whole Gradient) ---
            // 这是一个覆盖全屏的渐变，但是通过 stops 控制只在下半部分显示
            if (widget.showGradientFade)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      // 这里是关键！颜色数组
                      colors: [
                        Colors.transparent, // 0. 顶部透明
                        Colors.transparent, // 1. 保持透明
                        bgColor, // 2. 渐变到实色背景
                        bgColor, // 3. 底部保持实色
                      ],
                      // 这里是对应的位置 (0.0 - 1.0)
                      stops: const [
                        0.0,
                        0.5, // 0% - 50%: 完全透明 (露出图片上半部分)
                        0.7, // 50% - 70%: 渐变过度 (覆盖图片底部的)
                        1.0, // 70% - 100%: 完全实色 (图片下方的留白区)
                      ],
                    ),
                  ),
                ),
              ),

            // --- 层级 3：文字内容层 ---
            // 文字从渐变开始的地方 (0.5) 就开始布局，一直到底部
            Positioned(
              top: totalHeight * 0.5, // 与渐变开始的位置对齐 (50%)
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildTextContent(),
            ),

            // --- 层级 4：控制元素 ---
            if (widget.images.length > 1) ...[
              // 箭头限制在图片区域内
              Positioned(
                top: 0,
                height: totalHeight * 0.7,
                left: 0,
                child: _buildArrow(isLeft: true),
              ),
              Positioned(
                top: 0,
                height: totalHeight * 0.7,
                right: 0,
                child: _buildArrow(isLeft: false),
              ),
              // 指示器放在图片底部稍往上一点
              Positioned(
                top: (totalHeight * 0.7) - 24.h,
                left: 0,
                right: 0,
                child: _buildDotsIndicator(),
              ),
              // 计数器
              Positioned(
                top: (totalHeight * 0.7) - 32.h,
                right: 16.w,
                child: _buildCounterPill(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建文字内容
  Widget _buildTextContent() {
    final textScheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final hasCategory =
        widget.categoryLabel != null && widget.categoryLabel!.isNotEmpty;
    final hasBadge = widget.categoryBadge != null;
    final hasDate = widget.dateLabel != null && widget.dateLabel!.isNotEmpty;
    final hasTitle =
        widget.overlayTitle != null && widget.overlayTitle!.isNotEmpty;

    if (!hasCategory && !hasBadge && !hasDate && !hasTitle) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        // 让文字垂直方向分布：一部分在渐变里，一部分在实色区
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 撑开顶部的空间，让文字落在渐变变深的地方
          Spacer(),

          // 1. 分类和日期
          if (hasCategory || hasBadge || hasDate)
            Row(
              children: [
                if (hasBadge)
                  widget.categoryBadge!
                else if (hasCategory)
                  CategoryBadge(
                    categoryName: widget.categoryLabel!,
                    style: CategoryBadgeStyle.onImage,
                  ),
                if ((hasCategory || hasBadge) && hasDate) SizedBox(width: 12.w),
                if (hasDate)
                  DateLabel(
                    dateText: widget.dateLabel!,
                    style: DateLabelStyle.onImage,
                  ),
              ],
            ),

          SizedBox(height: 12.h),

          // 2. 标题
          if (hasTitle)
            Text(
              widget.overlayTitle!,
              style: textScheme.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

          // 底部留出一点安全距离
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  Widget _buildImageContent() {
    Widget imageWidget;
    if (widget.images.length == 1) {
      imageWidget = GestureDetector(
        onTap: widget.onImageTap,
        child: _buildImage(widget.images[0]),
      );
    } else {
      imageWidget = PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) => setState(() => _currentSlide = index),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: widget.onImageTap,
            child: _buildImage(widget.images[index]),
          );
        },
      );
    }
    return imageWidget;
  }

  Widget _buildImage(String imageUrl) {
    return PMImage(pathOrUrl: imageUrl, fit: BoxFit.cover);
  }

  Widget _buildArrow({required bool isLeft}) {
    return Center(
      child: AnimatedOpacity(
        opacity: _isHovered ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: InkWell(
          onTap: isLeft ? _prevSlide : _nextSlide,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: EdgeInsets.all(8.r),
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: Colors.black26,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLeft ? Icons.chevron_left : Icons.chevron_right,
              color: Colors.white,
              size: 24.sp,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDotsIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.images.length, (index) {
        final isActive = index == _currentSlide;
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          width: isActive ? 16.w : 6.w,
          height: 6.w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4.r),
            color: isActive ? Colors.white : Colors.white54,
          ),
        );
      }),
    );
  }

  Widget _buildCounterPill() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        '${_currentSlide + 1}/${widget.images.length}',
        style: TextStyle(fontSize: 10.sp, color: Colors.white),
      ),
    );
  }
}
