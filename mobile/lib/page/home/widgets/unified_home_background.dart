import 'package:flutter/material.dart';
import 'package:pocketmind/util/theme_data.dart';

class UnifiedHomeBackground extends StatelessWidget {
  const UnifiedHomeBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ext = CategoryHomeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.9, -0.95),
          radius: 1.4,
          colors: ext.unifiedHomeGradient,
        ),
      ),
      child: child,
    );
  }
}
