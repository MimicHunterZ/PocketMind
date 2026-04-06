import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum ToastType { success, error, info, warning }

enum ToastDirection { top, bottom }

class _ToastConfig {
  final Gradient gradient;
  final Color ringColor;
  final IconData icon;

  const _ToastConfig({
    required this.gradient,
    required this.ringColor,
    required this.icon,
  });
}

const _toastConfigs = {
  ToastType.success: _ToastConfig(
    gradient: LinearGradient(
      colors: [Color(0xFFE58F6F), Color(0xFFFACC15)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    ringColor: Color(0xFFE58F6F),
    icon: Icons.check_rounded,
  ),
  ToastType.error: _ToastConfig(
    gradient: LinearGradient(
      colors: [Color(0xFFBA1A1A), Color(0xFF581C87)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    ringColor: Color(0xFFBA1A1A),
    icon: Icons.error_outline_rounded,
  ),
  ToastType.info: _ToastConfig(
    gradient: LinearGradient(
      colors: [Color(0xFF60A5FA), Color(0xFFEC4899)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    ringColor: Color(0xFF60A5FA),
    icon: Icons.info_outline_rounded,
  ),
  ToastType.warning: _ToastConfig(
    gradient: LinearGradient(
      colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    ringColor: Color(0xFFF59E0B),
    icon: Icons.warning_amber_rounded,
  ),
};

class CreativeToast {
  static final _instance = CreativeToast._();
  CreativeToast._();
  final _entries = <OverlayEntry>[];

  static void show(
    BuildContext context, {
    required ToastType type,
    required String title,
    required String message,
    required ToastDirection direction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        type: type,
        direction: direction,
        title: title,
        message: message,
        duration: duration,
        onRemove: () {
          entry.remove();
          _instance._entries.remove(entry);
        },
      ),
    );

    _instance._entries.add(entry);
    overlay.insert(entry);
  }

  static void success(
    BuildContext context, {
    required String title,
    required String message,
    required ToastDirection direction,
  }) => show(
    context,
    type: ToastType.success,
    title: title,
    message: message,
    direction: direction,
  );

  static void error(
    BuildContext context, {
    required String title,
    required String message,
    required ToastDirection direction,
  }) => show(
    context,
    type: ToastType.error,
    title: title,
    message: message,
    direction: direction,
  );

  static void info(
    BuildContext context, {
    required String title,
    required String message,
    required ToastDirection direction,
  }) => show(
    context,
    type: ToastType.info,
    title: title,
    message: message,
    direction: direction,
  );

  static void warning(
    BuildContext context, {
    required String title,
    required String message,
    required ToastDirection direction,
  }) => show(
    context,
    type: ToastType.warning,
    title: title,
    message: message,
    direction: direction,
  );
}

class _ToastWidget extends StatefulWidget {
  final ToastType type;
  final ToastDirection direction;
  final String title;
  final String message;
  final Duration duration;
  final VoidCallback onRemove;

  const _ToastWidget({
    required this.type,
    required this.title,
    required this.message,
    required this.duration,
    required this.onRemove,
    required this.direction,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  Timer? _timer;
  double _progress = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: widget.direction == ToastDirection.top
          ? const Offset(0, -1)
          : const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    _startTimer();
  }

  void _startTimer() {
    if (widget.duration.inMilliseconds <= 0) return;

    final start = DateTime.now();
    final end = start.add(widget.duration);

    _timer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final remaining = end.difference(DateTime.now()).inMilliseconds;
      final percent = (remaining / widget.duration.inMilliseconds).clamp(
        0.0,
        1.0,
      );
      setState(() => _progress = percent);

      if (remaining <= 0) {
        t.cancel();
        _close();
      }
    });
  }

  void _close() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onRemove();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _toastConfigs[widget.type]!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mq = MediaQuery.of(context);
    final width = math.min(mq.size.width - 32.w, 380.0.w);

    return Positioned(
      top: widget.direction == ToastDirection.top
          ? mq.padding.top + 16.h
          : null,
      bottom: widget.direction == ToastDirection.bottom ? 32.h : null,
      left: (mq.size.width - width) / 2,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Container(
            width: width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: config.ringColor.withValues(alpha: 0.25),
                  blurRadius: 24.r,
                  offset: Offset(0, 8.h),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.r),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      width: 1.5.w,
                      color: config.ringColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 20.w,
                        right: 20.w,
                        child: Container(
                          height: 1.h,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.5),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(14.w),
                        child: Row(
                          children: [
                            Container(
                              width: 44.w,
                              height: 44.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: config.gradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: config.ringColor.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 12.r,
                                  ),
                                ],
                              ),
                              child: Icon(
                                config.icon,
                                color: Colors.white,
                                size: 24.sp,
                              ),
                            ),
                            SizedBox(width: 14.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.title,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.none,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    widget.message,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: 13.sp,
                                      color: cs.secondary,
                                      decoration: TextDecoration.none,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 10.w),
                            GestureDetector(
                              onTap: _close,
                              child: SizedBox(
                                width: 28.w,
                                height: 28.w,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Transform.rotate(
                                      angle: -math.pi / 2,
                                      child: CustomPaint(
                                        size: Size(28.w, 28.w),
                                        painter: _RingPainter(
                                          progress: _progress,
                                          color: config.ringColor,
                                          bg: cs.outlineVariant,
                                          stroke: 2.w,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.close,
                                      size: 12.sp,
                                      color: cs.secondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bg;
  final double stroke;

  const _RingPainter({
    required this.progress,
    required this.color,
    required this.bg,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = bg
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = '确认',
  String cancelText = '取消',
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (ctx, a1, a2, child) {
      return FadeTransition(
        opacity: a1,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: a1, curve: Curves.easeOutBack),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, a1, a2) => _ConfirmDialog(
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
    ),
  );
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const gradient = LinearGradient(
      colors: [Color(0xFFE58F6F), Color(0xFFFACC15)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    const accentColor = Color(0xFFE58F6F);

    return Center(
      child: Container(
        width: 300.w,
        margin: EdgeInsets.symmetric(horizontal: 24.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.2),
              blurRadius: 32.r,
              offset: Offset(0, 12.h),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(
                  width: 1.5.w,
                  color: accentColor.withValues(alpha: 0.25),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 24.w,
                    right: 24.w,
                    child: Container(
                      height: 1.h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.5),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 28.h),
                      Container(
                        width: 56.w,
                        height: 56.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: gradient,
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.4),
                              blurRadius: 16.r,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.help_outline_rounded,
                          color: Colors.white,
                          size: 28.sp,
                        ),
                      ),
                      SizedBox(height: 20.h),
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: Text(
                          message,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14.sp,
                            color: cs.secondary,
                            height: 1.5,
                            decoration: TextDecoration.none,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 28.h),
                      Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.of(context).pop(false),
                                child: Container(
                                  height: 48.h,
                                  decoration: BoxDecoration(
                                    color: cs.outlineVariant.withValues(
                                      alpha: 0.3,
                                    ),
                                    borderRadius: BorderRadius.circular(14.r),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    cancelText,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontSize: 15.sp,
                                      color: cs.secondary,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.of(context).pop(true),
                                child: Container(
                                  height: 48.h,
                                  decoration: BoxDecoration(
                                    gradient: gradient,
                                    borderRadius: BorderRadius.circular(14.r),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accentColor.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 8.r,
                                        offset: Offset(0, 4.h),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    confirmText,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontSize: 15.sp,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<String?> showInputDialog(
  BuildContext context, {
  required String title,
  String? message,
  String? hintText,
  String? initialValue,
  String confirmText = '确认',
  String cancelText = '取消',
  int maxLines = 1,
  TextInputType keyboardType = TextInputType.text,
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (ctx, a1, a2, child) {
      return FadeTransition(
        opacity: a1,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: a1, curve: Curves.easeOutBack),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, a1, a2) => _InputDialog(
      title: title,
      message: message,
      hintText: hintText,
      initialValue: initialValue,
      confirmText: confirmText,
      cancelText: cancelText,
      maxLines: maxLines,
      keyboardType: keyboardType,
    ),
  );
}

class _InputDialog extends StatefulWidget {
  final String title;
  final String? message;
  final String? hintText;
  final String? initialValue;
  final String confirmText;
  final String cancelText;
  final int maxLines;
  final TextInputType keyboardType;

  const _InputDialog({
    required this.title,
    this.message,
    this.hintText,
    this.initialValue,
    required this.confirmText,
    required this.cancelText,
    required this.maxLines,
    required this.keyboardType,
  });

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const gradient = LinearGradient(
      colors: [Color(0xFF60A5FA), Color(0xFFEC4899)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    const accentColor = Color(0xFF60A5FA);

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: SingleChildScrollView(
          child: Container(
          width: 320.w,
          margin: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.r),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.2),
                blurRadius: 32.r,
                offset: Offset(0, 12.h),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.r),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(
                    width: 1.5.w,
                    color: accentColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 24.w,
                      right: 24.w,
                      child: Container(
                        height: 1.h,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.5),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 28.h),
                        Container(
                          width: 56.w,
                          height: 56.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: gradient,
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.4),
                                blurRadius: 16.r,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 26.sp,
                          ),
                        ),
                        SizedBox(height: 20.h),
                        Text(
                          widget.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (widget.message != null) ...[
                          SizedBox(height: 8.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.w),
                            child: Text(
                              widget.message!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 14.sp,
                                color: cs.secondary,
                                height: 1.5,
                                decoration: TextDecoration.none,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        SizedBox(height: 20.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Container(
                            decoration: BoxDecoration(
                              color: cs.outlineVariant.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.2),
                                width: 1.w,
                              ),
                            ),
                            child: TextField(
                              controller: _controller,
                              maxLines: widget.maxLines,
                              keyboardType: widget.keyboardType,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: 15.sp,
                                decoration: TextDecoration.none,
                              ),
                              decoration: InputDecoration(
                                hintText: widget.hintText,
                                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                                  fontSize: 15.sp,
                                  color: cs.secondary.withValues(alpha: 0.5),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 14.h,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 24.h),
                        Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => Navigator.of(context).pop(null),
                                  child: Container(
                                    height: 48.h,
                                    decoration: BoxDecoration(
                                      color: cs.outlineVariant.withValues(
                                        alpha: 0.3,
                                      ),
                                      borderRadius: BorderRadius.circular(14.r),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      widget.cancelText,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontSize: 15.sp,
                                            color: cs.secondary,
                                            fontWeight: FontWeight.w600,
                                            decoration: TextDecoration.none,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => Navigator.of(
                                    context,
                                  ).pop(_controller.text),
                                  child: Container(
                                    height: 48.h,
                                    decoration: BoxDecoration(
                                      gradient: gradient,
                                      borderRadius: BorderRadius.circular(14.r),
                                      boxShadow: [
                                        BoxShadow(
                                          color: accentColor.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 8.r,
                                          offset: Offset(0, 4.h),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      widget.confirmText,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontSize: 15.sp,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.none,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }
}
