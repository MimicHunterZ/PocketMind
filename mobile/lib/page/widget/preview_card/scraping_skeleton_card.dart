import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/page/widget/creative_toast.dart';
import 'package:pocketmind/util/theme_data.dart';
import 'package:pocketmind/util/url_helper.dart';

class ScrapingSkeletonCard extends StatefulWidget {
  final bool isVertical;
  final String? url;
  final String? publishDate;
  final VoidCallback? onForceComplete;

  const ScrapingSkeletonCard({
    super.key,
    required this.isVertical,
    required this.url,
    this.publishDate,
    this.onForceComplete,
  });

  @override
  State<ScrapingSkeletonCard> createState() => _ScrapingSkeletonCardState();
}

class _ScrapingSkeletonCardState extends State<ScrapingSkeletonCard>
    with TickerProviderStateMixin {
  late final AnimationController _borderController;
  late final AnimationController _pulseController;
  static const double _kHorizontalSkeletonHeight = 160;

  @override
  void initState() {
    super.initState();
    _borderController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.isVertical ? 3 : 4),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
      lowerBound: 0.08,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _borderController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final domain = UrlHelper.extractDomain(widget.url).isEmpty
        ? ''
        : UrlHelper.extractDomain(widget.url);
    final date = widget.publishDate ?? '';
    final outerRadius = widget.isVertical ? 24.r : 20.r;
    final innerInset = 1.5.w;
    final innerRadius = widget.isVertical ? 22.r : 18.r;

    final onForceComplete = widget.onForceComplete;
    final content = widget.isVertical
        ? _WaterfallScrapingContent(
            pulseController: _pulseController,
            domain: domain,
            publishDate: date,
            topImageRadius: innerRadius,
            onForceComplete: onForceComplete,
          )
        : _ClassicListScrapingContent(
            pulseController: _pulseController,
            domain: domain,
            publishDate: date,
            leftImageRadius: innerRadius,
            onForceComplete: onForceComplete,
          );

    final shell = ClipRRect(
      clipBehavior: Clip.antiAliasWithSaveLayer,
      borderRadius: BorderRadius.circular(outerRadius),
      child: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _borderController,
                builder: (context, _) {
                  return Transform.rotate(
                    angle: _borderController.value * 2 * math.pi,
                    child: FractionallySizedBox(
                      widthFactor: 4,
                      heightFactor: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: SweepGradient(
                            colors: [
                              Colors.transparent,
                              colorScheme.tertiary.withValues(alpha: 0.26),
                              colorScheme.tertiary.withValues(alpha: 0.72),
                              colorScheme.tertiary.withValues(alpha: 0.98),
                              colorScheme.tertiary.withValues(alpha: 0.72),
                              colorScheme.tertiary.withValues(alpha: 0.26),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.4, 0.45, 0.5, 0.55, 0.6, 1.0],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(innerInset),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(innerRadius),
                    border: Border.all(
                      color: appColors.cardBorder.withValues(
                        alpha: isDark ? 0.6 : 0.42,
                      ),
                      width: 1.8,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: content,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return ExcludeSemantics(
      child: widget.isVertical
          ? AspectRatio(aspectRatio: 4 / 5.5, child: shell)
          : SizedBox(height: _kHorizontalSkeletonHeight, child: shell),
    );
  }
}

/// 瀑布流抓取中样式（原 vertical）。
class _WaterfallScrapingContent extends StatelessWidget {
  final AnimationController pulseController;
  final String domain;
  final String publishDate;
  final double topImageRadius;
  final VoidCallback? onForceComplete;

  const _WaterfallScrapingContent({
    required this.pulseController,
    required this.domain,
    required this.publishDate,
    required this.topImageRadius,
    required this.onForceComplete,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Column(
      children: [
        Expanded(
          flex: 55,
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(topImageRadius),
              topRight: Radius.circular(topImageRadius),
            ),
            child: _BreathingBlock(
              controller: pulseController,
              baseColor: appColors.skeletonBase,
              highlightColor: appColors.skeletonHighlight,
            ),
          ),
        ),
        Expanded(
          flex: 45,
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PulseLine(
                  controller: pulseController,
                  widthFactor: 0.78,
                  height: 14.w,
                ),
                SizedBox(height: 12.w),
                _PulseLine(
                  controller: pulseController,
                  widthFactor: 1,
                  height: 8.w,
                ),
                SizedBox(height: 8.w),
                _PulseLine(
                  controller: pulseController,
                  widthFactor: 0.72,
                  height: 8.w,
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        domain,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: textColor.withValues(alpha: 0.42),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    if (onForceComplete != null)
                      _ForceCompleteAction(onForceComplete: onForceComplete!),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: Text(
                        publishDate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: textColor.withValues(alpha: 0.24),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 经典单列抓取中样式（原 horizontal）。
class _ClassicListScrapingContent extends StatelessWidget {
  final AnimationController pulseController;
  final String domain;
  final String publishDate;
  final double leftImageRadius;
  final VoidCallback? onForceComplete;

  const _ClassicListScrapingContent({
    required this.pulseController,
    required this.domain,
    required this.publishDate,
    required this.leftImageRadius,
    required this.onForceComplete,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Row(
      children: [
        Flexible(
          flex: 35,
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(leftImageRadius),
              bottomLeft: Radius.circular(leftImageRadius),
            ),
            child: SizedBox.expand(
              child: _BreathingBlock(
                controller: pulseController,
                baseColor: appColors.skeletonBase,
                highlightColor: appColors.skeletonHighlight,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 65,
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PulseLine(
                  controller: pulseController,
                  widthFactor: 0.8,
                  height: 14.w,
                ),
                SizedBox(height: 12.w),
                _PulseLine(
                  controller: pulseController,
                  widthFactor: 1,
                  height: 8.w,
                ),
                SizedBox(height: 8.w),
                _PulseLine(
                  controller: pulseController,
                  widthFactor: 0.76,
                  height: 8.w,
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        domain,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: textColor.withValues(alpha: 0.42),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (onForceComplete != null) ...[
                      SizedBox(width: 8.w),
                      _ForceCompleteAction(onForceComplete: onForceComplete!),
                      SizedBox(width: 8.w),
                    ],
                    Flexible(
                      child: Text(
                        publishDate,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: textColor.withValues(alpha: 0.24),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ForceCompleteAction extends StatelessWidget {
  final VoidCallback onForceComplete;

  const _ForceCompleteAction({required this.onForceComplete});

  Future<void> _confirmForceComplete(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '强制完成',
      message: '确认强制结束 loading 并进入预览吗？该状态将同步到其他设备。',
      cancelText: '取消',
      confirmText: '强制完成',
    );
    if (confirmed != true) return;
    onForceComplete();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onLongPress: () => _confirmForceComplete(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '长按强制完成',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.tertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _BreathingBlock extends StatelessWidget {
  final AnimationController controller;
  final Color baseColor;
  final Color highlightColor;

  const _BreathingBlock({
    required this.controller,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final pulse = controller.value;
        final shimmerOffset = (pulse * 2) - 1;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.6 + shimmerOffset, -0.3),
              end: Alignment(0.2 + shimmerOffset, 0.3),
              colors: [
                Color.lerp(baseColor, highlightColor, pulse * 0.35)!,
                Color.lerp(baseColor, highlightColor, pulse)!,
                Color.lerp(baseColor, highlightColor, 0.2)!,
              ],
              stops: const [0.0, 0.48, 1.0],
            ),
          ),
        );
      },
    );
  }
}

class _PulseLine extends StatelessWidget {
  final AnimationController controller;
  final double widthFactor;
  final double height;

  const _PulseLine({
    required this.controller,
    required this.widthFactor,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);

    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final pulse = controller.value;
          return Container(
            height: height,
            decoration: BoxDecoration(
              color: Color.lerp(
                appColors.skeletonBase,
                appColors.skeletonHighlight,
                pulse,
              ),
              borderRadius: BorderRadius.circular(6.r),
            ),
          );
        },
      ),
    );
  }
}
