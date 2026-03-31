import 'package:flutter/material.dart';

enum HomeTab { everything, ai, category }

class HomeTabBar extends StatelessWidget {
  const HomeTabBar({
    super.key,
    required this.currentTab,
    required this.onChanged,
  });

  final HomeTab currentTab;
  final ValueChanged<HomeTab> onChanged;

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
                selected: currentTab == HomeTab.everything,
                onTap: () => onChanged(HomeTab.everything),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TabItem(
                label: 'AI',
                selected: currentTab == HomeTab.ai,
                onTap: () => onChanged(HomeTab.ai),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TabItem(
                label: '分类',
                selected: currentTab == HomeTab.category,
                onTap: () => onChanged(HomeTab.category),
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
