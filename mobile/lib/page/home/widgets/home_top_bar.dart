import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketmind/router/route_paths.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.onAvatarTap,
    required this.onSearchTap,
    required this.onAddTap,
    this.showSearchInput = false,
    this.searchController,
    this.searchFocusNode,
    this.onSearchBackTap,
  }) : assert(
         !showSearchInput ||
             (searchController != null &&
                 searchFocusNode != null &&
                 onSearchBackTap != null),
       );

  final VoidCallback onAvatarTap;
  final VoidCallback onSearchTap;
  final VoidCallback onAddTap;

  final bool showSearchInput;
  final TextEditingController? searchController;
  final FocusNode? searchFocusNode;
  final VoidCallback? onSearchBackTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: SizedBox(
          height: 48,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.16, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: showSearchInput
                ? _SearchBar(
                    key: const ValueKey('themed-home-search-bar'),
                    controller: searchController!,
                    focusNode: searchFocusNode!,
                    onBackTap: onSearchBackTap!,
                  )
                : _ActionsBar(
                    key: const ValueKey('themed-home-actions-bar'),
                    colorScheme: colorScheme,
                    onAvatarTap: onAvatarTap,
                    onSearchTap: onSearchTap,
                    onAddTap: onAddTap,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ActionsBar extends StatelessWidget {
  const _ActionsBar({
    super.key,
    required this.colorScheme,
    required this.onAvatarTap,
    required this.onSearchTap,
    required this.onAddTap,
  });

  final ColorScheme colorScheme;
  final VoidCallback onAvatarTap;
  final VoidCallback onSearchTap;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onAvatarTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Icon(
              Icons.account_circle_outlined,
              size: 24,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        const Spacer(),
        if (kDebugMode)
          IconButton(
            onPressed: () => context.push(RoutePaths.genuiDemo),
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'A2UI Demo',
          ),
        IconButton(
          onPressed: onSearchTap,
          icon: const Icon(Icons.search),
          tooltip: '搜索',
        ),
        IconButton(
          onPressed: onAddTap,
          icon: const Icon(Icons.add),
          tooltip: '新增',
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onBackTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.08),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onBackTap,
            color: colorScheme.primary,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '搜索笔记...',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              style: TextStyle(color: colorScheme.onSurface),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              if (value.text.isEmpty) {
                return const SizedBox(width: 48);
              }
              return IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.clear();
                  focusNode.requestFocus();
                },
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                iconSize: 20,
              );
            },
          ),
        ],
      ),
    );
  }
}
