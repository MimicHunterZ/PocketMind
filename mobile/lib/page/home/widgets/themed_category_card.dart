import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pocketmind/util/theme_data.dart';

bool disableThemedCategoryIconFloatAnimationForTest = false;

class ThemedCategoryCard extends StatefulWidget {
  const ThemedCategoryCard({
    super.key,
    required this.title,
    required this.description,
    required this.metaText,
    required this.iconPath,
    required this.accent,
    this.onTap,
  });

  final String title;
  final String description;
  final String metaText;
  final String iconPath;
  final Color accent;
  final VoidCallback? onTap;

  @override
  State<ThemedCategoryCard> createState() => _ThemedCategoryCardState();
}

class _ThemedCategoryCardState extends State<ThemedCategoryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _floatAnimation = Tween<double>(begin: 2, end: -2).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    if (!disableThemedCategoryIconFloatAnimationForTest) {
      _floatController.repeat(reverse: true);
    } else {
      _floatController.value = 0.5;
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = CategoryHomeColors.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _active = true),
      onExit: (_) => setState(() => _active = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _active = true),
        onTapCancel: () => setState(() => _active = false),
        onTapUp: (_) => setState(() => _active = false),
        child: SizedBox(
          height: 180,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 220),
                  offset: _active ? const Offset(0.08, 0.08) : const Offset(0, 0.06),
                  child: _buildLayer(ext.layerBackground.withValues(alpha: 0.45), ext.cardBorder),
                ),
              ),
              Positioned.fill(
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 220),
                  offset: _active ? const Offset(0.04, 0.04) : const Offset(0, 0.03),
                  child: _buildLayer(ext.layerBackground.withValues(alpha: 0.7), ext.cardBorder),
                ),
              ),
              AnimatedScale(
                duration: const Duration(milliseconds: 220),
                scale: _active ? 1.02 : 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: ext.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ext.cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: ext.cardShadow,
                        blurRadius: _active ? 24 : 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 2,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          gradient: LinearGradient(
                            colors: [widget.accent, widget.accent.withValues(alpha: 0.55)],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: widget.accent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.accent.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: ext.titleText,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          widget.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ext.bodyText,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.metaText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: ext.metaText, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: -8,
                top: -16,
                child: AnimatedBuilder(
                  animation: _floatAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _floatAnimation.value),
                      child: child,
                    );
                  },
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: RepaintBoundary(
                      child: SvgPicture.asset(widget.iconPath),
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

  Widget _buildLayer(Color background, Color border) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border.withValues(alpha: 0.6)),
      ),
    );
  }
}
