import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketmind/providers/note_providers.dart';

/// 搜索逻辑复用 Mixin
/// 处理搜索框输入监听、防抖和状态更新
mixin SearchLogicMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    _debounceTimer?.cancel();
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    if (!mounted) return;

    final query = searchController.text.trim();

    // 如果输入为空，立即清空搜索结果
    if (query.isEmpty) {
      ref.read(searchQueryProvider.notifier).set(null);
      return;
    }

    // 设置防抖计时器
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && query.isNotEmpty) {
        ref.read(searchQueryProvider.notifier).set(query);
      }
    });
  }

  /// 立即提交搜索（用于回车键或点击搜索按钮）
  void submitSearch() {
    _debounceTimer?.cancel();
    final query = searchController.text.trim();
    if (query.isNotEmpty) {
      ref.read(searchQueryProvider.notifier).set(query);
    } else {
      ref.read(searchQueryProvider.notifier).set(null);
    }
  }

  /// 清空搜索
  void clearSearch() {
    _debounceTimer?.cancel();
    searchController.clear();
    // clear() 会触发 listener，listener 会处理 set(null)
    // 但为了保险和立即响应，这里也可以显式调用
    ref.read(searchQueryProvider.notifier).set(null);
  }
}
