import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pocketmind/util/theme_data.dart';

/// 流动背景
class FlowingBackground extends StatefulWidget {
  const FlowingBackground({super.key});

  @override
  State<FlowingBackground> createState() => _FlowingBackgroundState();
}

class _FlowingBackgroundState extends State<FlowingBackground>
    with TickerProviderStateMixin {
  late AnimationController _slowController;
  late AnimationController _mediumController;
  late AnimationController _fastController;

  @override
  void initState() {
    super.initState();

    // 快速流动动画，适配 3 秒使用场景
    _slowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _mediumController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _fastController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _slowController.dispose();
    _mediumController.dispose();
    _fastController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 流动的渐变层
        AnimatedBuilder(
          animation: Listenable.merge([
            _slowController,
            _mediumController,
            _fastController,
          ]),
          builder: (context, child) {
            return CustomPaint(
              painter: FlowingGradientPainter(
                slowProgress: _slowController.value,
                mediumProgress: _mediumController.value,
                fastProgress: _fastController.value,
                isDark: isDark,
              ),
              size: Size.infinite,
            );
          },
        ),

        // 轻度模糊层 - 降低模糊度让底层更清晰
        BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 35.0,
            sigmaY: 35.0,
            tileMode: TileMode.clamp,
          ),
          child: Container(color: Colors.transparent),
        ),
      ],
    );
  }
}

/// 自定义画笔 - 绘制流动的渐变色块
class FlowingGradientPainter extends CustomPainter {
  final double slowProgress;
  final double mediumProgress;
  final double fastProgress;
  final bool isDark;

  FlowingGradientPainter({
    required this.slowProgress,
    required this.mediumProgress,
    required this.fastProgress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 从主题获取颜色
    final colors = isDark
        ? [
            DarkFlowingBackgroundColors.blob1.withValues(alpha: 0.6),
            DarkFlowingBackgroundColors.blob2.withValues(alpha: 0.5),
            DarkFlowingBackgroundColors.blob3.withValues(alpha: 0.45),
            DarkFlowingBackgroundColors.blob4.withValues(alpha: 0.4),
          ]
        : [
            LightFlowingBackgroundColors.blob1.withValues(alpha: 0.7),
            LightFlowingBackgroundColors.blob2.withValues(alpha: 0.6),
            LightFlowingBackgroundColors.blob3.withValues(alpha: 0.55),
            LightFlowingBackgroundColors.blob4.withValues(alpha: 0.5),
          ];

    // 绘制多个大型流动渐变球 - 增加到 5 个以增加丰富度
    _drawFlowingBlob(
      canvas,
      size,
      center: Offset(
        size.width * (0.2 + 0.3 * math.sin(slowProgress * 2 * math.pi)),
        size.height * (0.3 + 0.2 * math.cos(slowProgress * 2 * math.pi)),
      ),
      radius: size.width * (0.6 + 0.1 * math.sin(mediumProgress * 2 * math.pi)),
      colors: [colors[0], colors[0].withValues(alpha: 0)],
    );

    _drawFlowingBlob(
      canvas,
      size,
      center: Offset(
        size.width * (0.7 + 0.2 * math.cos(mediumProgress * 2 * math.pi + 1)),
        size.height * (0.5 + 0.25 * math.sin(mediumProgress * 2 * math.pi + 1)),
      ),
      radius: size.width * (0.7 + 0.15 * math.cos(fastProgress * 2 * math.pi)),
      colors: [colors[1], colors[1].withValues(alpha: 0)],
    );

    _drawFlowingBlob(
      canvas,
      size,
      center: Offset(
        size.width * (0.5 + 0.25 * math.sin(fastProgress * 2 * math.pi + 2)),
        size.height * (0.7 + 0.2 * math.cos(slowProgress * 2 * math.pi + 2)),
      ),
      radius: size.width * (0.5 + 0.12 * math.sin(slowProgress * 2 * math.pi)),
      colors: [colors[2], colors[2].withValues(alpha: 0)],
    );

    // 第四个球 - 增加色彩层次
    _drawFlowingBlob(
      canvas,
      size,
      center: Offset(
        size.width * (0.8 + 0.15 * math.cos(fastProgress * 2 * math.pi + 3)),
        size.height * (0.2 + 0.15 * math.sin(fastProgress * 2 * math.pi + 3)),
      ),
      radius: size.width * 0.45,
      colors: [colors[3], colors[3].withValues(alpha: 0)],
    );

    // 第五个球 - 进一步丰富色彩
    _drawFlowingBlob(
      canvas,
      size,
      center: Offset(
        size.width * (0.3 + 0.2 * math.sin(mediumProgress * 2 * math.pi + 4)),
        size.height * (0.15 + 0.18 * math.cos(fastProgress * 2 * math.pi + 4)),
      ),
      radius: size.width * 0.5,
      colors: [
        colors[0].withValues(alpha: 0.4),
        colors[0].withValues(alpha: 0),
      ],
    );
  }

  void _drawFlowingBlob(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double radius,
    required List<Color> colors,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: colors,
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(FlowingGradientPainter oldDelegate) {
    return slowProgress != oldDelegate.slowProgress ||
        mediumProgress != oldDelegate.mediumProgress ||
        fastProgress != oldDelegate.fastProgress;
  }
}
