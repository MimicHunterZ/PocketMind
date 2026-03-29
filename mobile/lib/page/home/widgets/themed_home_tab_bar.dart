import 'package:flutter/material.dart';

enum ThemedHomeTab { everything, ai, category }

class ThemedHomeTabBar extends StatelessWidget {
  const ThemedHomeTabBar({
    super.key,
    required this.currentTab,
    required this.onChanged,
  });

  final ThemedHomeTab currentTab;
  final ValueChanged<ThemedHomeTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _TabItem(
                label: 'Everything',
                selected: currentTab == ThemedHomeTab.everything,
                onTap: () => onChanged(ThemedHomeTab.everything),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TabItem(
                label: 'AI',
                selected: currentTab == ThemedHomeTab.ai,
                onTap: () => onChanged(ThemedHomeTab.ai),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TabItem(
                label: '分类',
                selected: currentTab == ThemedHomeTab.category,
                onTap: () => onChanged(ThemedHomeTab.category),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.surfaceContainerLow
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colorScheme.onSurface : colorScheme.secondary,
          ),
        ),
      ),
    );
  }
}
