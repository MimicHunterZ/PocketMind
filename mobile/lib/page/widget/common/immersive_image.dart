import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/page/widget/pm_image.dart';
import 'package:pocketmind/util/image_prefetcher.dart';

/// 沉浸式图片展示组件（用于详情页图片区域）。
///
/// 注意：这里“只负责展示”，不做任何图片尺寸解析。
/// - 图片完整展示：BoxFit.contain
/// - 空白区域随主题变色：亮色白底、暗色黑底
class ImmersiveImage extends StatelessWidget {
  final String pathOrUrl;

  /// 固定尺寸模式：给定 width/height 后直接填充。
  final double? width;
  final double? height;

  const ImmersiveImage({
    super.key,
    required this.pathOrUrl,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    // 空白填充按主题变色：亮色更偏白，暗色更偏黑。
    // 这里用纯黑/白是为了更接近“沉浸式图文预览”的观感。
    final bg = Theme.of(context).brightness == Brightness.dark
        ? Colors.black
        : Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 用父容器的实际尺寸渲染，避免把 double.infinity 传进 Image/CachedNetworkImage。
        final resolvedWidth = width ?? constraints.maxWidth;
        final resolvedHeight = height ?? constraints.maxHeight;

        // 按目标展示尺寸解码，减少大图解码内存占用，降低返回列表时“重载”的概率。
        final dpr = MediaQuery.of(context).devicePixelRatio;
        final decodeW = resolvedWidth.isFinite
            ? (resolvedWidth * dpr).round()
            : null;
        final decodeH = resolvedHeight.isFinite
            ? (resolvedHeight * dpr).round()
            : null;

        final image = DecoratedBox(
          decoration: BoxDecoration(color: bg),
          child: Align(
            alignment: Alignment.center,
            child: PMImage(
              pathOrUrl: pathOrUrl,
              fit: BoxFit.contain,
              width: resolvedWidth.isFinite ? resolvedWidth : null,
              height: resolvedHeight.isFinite ? resolvedHeight : null,
              // 网络图走 memCache，文件/asset 走 cacheWidth/cacheHeight
              memCacheWidth: decodeW,
              memCacheHeight: decodeH,
              cacheWidth: decodeW,
              cacheHeight: decodeH,
            ),
          ),
        );

        return SizedBox(width: width, height: height, child: image);
      },
    );
  }
}

/// 沉浸式多图轮播（详情页使用）。
///
/// 关键点：
/// - 不使用默认/兜底高度：必须先完成尺寸解析后再展示
/// - 缩放规则：以组件宽度为基准缩放，取所有图片缩放后的最大高度作为组件高度
/// - 最大高度限制：不超过一屏，避免超长图撑爆布局
/// - 保留底部指示点
class ImmersiveImageCarousel extends StatefulWidget {
  final List<String> images;
  final bool isDesktop;

  /// 最大高度约束（避免极端长图撑满屏幕）
  final double? maxHeight;

  const ImmersiveImageCarousel({
    super.key,
    required this.images,
    required this.isDesktop,
    this.maxHeight,
  });

  @override
  State<ImmersiveImageCarousel> createState() => _ImmersiveImageCarouselState();
}

class _ImmersiveImageCarouselState extends State<ImmersiveImageCarousel> {
  late final PageController _controller;
  int _index = 0;

  /// max(h/w)，用于 height = width * max(h/w)
  double? _maxHeightOverWidth;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController();

    final cached = ImagePrefetcher.getCachedMaxHeightOverWidth(widget.images);
    if (cached != null) {
      _maxHeightOverWidth = cached;
    }
    // _resolveMaxHeightRatio() 在 didChangeDependencies 中调用，确保 MediaQuery 可用
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_maxHeightOverWidth == null && !_resolving) {
      _resolveMaxHeightRatio();
    }
  }

  @override
  void didUpdateWidget(covariant ImmersiveImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images != widget.images) {
      _maxHeightOverWidth = null;
      _resolving = false;

      final cached = ImagePrefetcher.getCachedMaxHeightOverWidth(widget.images);
      if (cached != null) {
        _maxHeightOverWidth = cached;
      } else {
        _resolveMaxHeightRatio();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // 最大高度限制：不超过“一屏高度”，避免超长图撑爆布局。
        final screenHeight = 1.0.sh;
        final hardMax = widget.maxHeight ?? screenHeight;
        final maxHeight = hardMax > screenHeight ? screenHeight : hardMax;

        // 不做兜底高度：尺寸没算完就不展示轮播，避免任何二次重排造成的跳动。
        if (_maxHeightOverWidth == null) {
          final bg = Theme.of(context).brightness == Brightness.dark
              ? Colors.black
              : Colors.white;
          return SizedBox(
            width: double.infinity,
            height: maxHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(color: bg),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final width = constraints.maxWidth;
        final computedHeight = width.isFinite
            ? width * _maxHeightOverWidth!
            : maxHeight;

        final targetHeight = computedHeight.clamp(160.0, maxHeight);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: targetHeight,
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.images.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  return SizedBox.expand(
                    child: ImmersiveImage(
                      pathOrUrl: widget.images[i],
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  );
                },
              ),
            ),
            if (widget.images.length > 1) ...[
              SizedBox(height: 10.h),
              _DotsIndicator(count: widget.images.length, index: _index),
            ],
          ],
        );
      },
    );
  }

  Future<void> _resolveMaxHeightRatio() async {
    if (_resolving) return;
    _resolving = true;

    // 直接复用预热器：同一套逻辑、同一份缓存。
    await ImagePrefetcher.prewarm(
      context,
      widget.images,
      computeCarouselRatio: true,
    );

    if (!mounted) return;

    setState(() {
      _maxHeightOverWidth = ImagePrefetcher.getCachedMaxHeightOverWidth(
        widget.images,
      );
      _resolving = false;
    });
  }
}

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int index;

  const _DotsIndicator({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    // 指示点现在在图片下方（非图片叠层），使用主题色确保可见。
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          width: active ? 16.w : 6.w,
          height: 6.w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4.r),
            color: active
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        );
      }),
    );
  }
}
