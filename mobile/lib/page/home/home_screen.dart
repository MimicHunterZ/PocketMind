import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/page/widget/glass_nav_bar.dart';
import 'package:pocketmind/page/widget/note_item.dart';
import 'package:pocketmind/page/home/note_add_sheet.dart';
import 'package:pocketmind/page/home/mixin/search_logic_mixin.dart';
import 'package:pocketmind/providers/nav_providers.dart';
import 'package:pocketmind/providers/note_providers.dart';
import 'package:pocketmind/providers/app_config_provider.dart';
import 'package:pocketmind/service/note_service.dart';
import 'package:pocketmind/sync/sync_state_provider.dart';
import 'package:pocketmind/util/theme_data.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'package:pocketmind/providers/sync_providers.dart';

final String tag = 'HomeScreen';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin, SearchLogicMixin {
  // 滚动控制器，用于保持滚动位置
  final ScrollController _scrollController = ScrollController();

  bool _isSearchMode = false;
  late AnimationController _searchAnimationController;
  late Animation<Offset> _navBarSlideAnimation;
  late Animation<Offset> _searchBarSlideAnimation;

  @override
  void initState() {
    super.initState();

    // 初始化动画控制器
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // NavBar 向左滑出的动画
    _navBarSlideAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(-1.0, 0.0)).animate(
          CurvedAnimation(
            parent: _searchAnimationController,
            curve: Curves.easeInOut,
          ),
        );

    // 搜索框从右滑入的动画
    _searchBarSlideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _searchAnimationController,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchAnimationController.dispose();
    super.dispose();
  }

  // 切换搜索模式
  void _toggleSearchMode() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      if (_isSearchMode) {
        _searchAnimationController.forward();
        // 延迟一点让动画先执行，然后再聚焦
        Future.delayed(const Duration(milliseconds: 100), () {
          searchFocusNode.requestFocus();
        });
      } else {
        _searchAnimationController.reverse();
        clearSearch();
        searchFocusNode.unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 确保自适应同步调度器处于激活状态（30s 定时器 + 网络恢复触发）
    ref.watch(adaptiveSyncSchedulerProvider);

    return Scaffold(
      // 使用主题背景色
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 顶部导航栏 / 搜索栏 切换区域
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: SizedBox(
                height: 56.h, // 固定高度，防止切换时跳动
                child: Stack(
                  children: [
                    // GlassNavBar - 向左滑出
                    SlideTransition(
                      position: _navBarSlideAnimation,
                      child: Padding(
                        padding: EdgeInsets.only(right: 8.w), // 添加右侧间距
                        child: GlassNavBar(onSearchPressed: _toggleSearchMode),
                      ),
                    ),
                    // 搜索栏 - 从右滑入
                    SlideTransition(
                      position: _searchBarSlideAnimation,
                      child: Padding(
                        padding: EdgeInsets.only(left: 8.w), // 添加左侧间距
                        child: _buildSearchBar(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 12.h),

            // 笔记列表（根据布局模式切换 或 搜索结果）
            Expanded(
              child: _HomeNotesPane(scrollController: _scrollController),
            ),
          ],
        ),
      ),

      // FAB - 使用主题样式（药丸形状）
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddNotePage(context);
        },
        elevation: 12,
        child: Container(
          width: 56.w,
          height: 56.w,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.tertiary,
                Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.85),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.tertiary.withValues(alpha: 0.4),
                blurRadius: 16.r,
                offset: Offset(0, 6.h),
              ),
            ],
          ),
          child: Icon(Icons.add, size: 28.sp),
        ),
      ),
    );
  }

  // 显示添加笔记页面（全屏）
  void _showAddNotePage(BuildContext context) {
    Navigator.of(context).push(NoteEditorRoute());
  }

  // 构建搜索栏
  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.08),
          width: 1.0.w,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _toggleSearchMode,
            color: colorScheme.primary,
          ),

          // 搜索输入框
          Expanded(
            child: TextField(
              controller: searchController,
              focusNode: searchFocusNode,
              decoration: InputDecoration(
                hintText: '搜索笔记...',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              style: TextStyle(color: colorScheme.onSurface),
              // 实时搜索，不需要提交动作
            ),
          ),

          // 清空按钮（当有输入时显示）
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: searchController,
            builder: (context, value, child) {
              if (value.text.isEmpty) {
                return SizedBox(width: 48.w); // 占位，保持布局稳定
              }
              return IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  clearSearch();
                  searchFocusNode.requestFocus();
                },
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                iconSize: 20.sp,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HomeNotesPane extends ConsumerWidget {
  const _HomeNotesPane({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteService = ref.read(noteServiceProvider);
    final currentLayout = ref.watch(
      appConfigProvider.select(
        (config) =>
            config.waterfallLayoutEnabled ? NoteLayout.grid : NoteLayout.list,
      ),
    );
    final searchQuery = ref.watch(searchQueryProvider);

    if (searchQuery != null) {
      final searchResults = ref.watch(searchResultsProvider);
      return _HomeSearchResults(
        searchResults: searchResults,
        currentLayout: currentLayout,
        noteService: noteService,
        scrollController: scrollController,
      );
    }

    final isInitialPull = ref.watch(syncIsInitialPullProvider);
    if (isInitialPull) {
      return const _InitialPullSkeleton();
    }

    final noteByCategory = ref.watch(noteByCategoryProvider);
    return noteByCategory.when(
      skipLoadingOnRefresh: true,
      data: (notes) {
        if (notes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.note_add_outlined,
                  size: 80.sp,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                SizedBox(height: 16.h),
                Text(
                  '你的思绪将汇聚于此',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '点击右下角，捕捉第一个灵感',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        }

        return _NotesListView(
          notes: notes,
          currentLayout: currentLayout,
          noteService: noteService,
          scrollController: scrollController,
        );
      },
      error: (error, stack) {
        PMlog.e(tag, 'stack: $error,stack:$stack');
        return const Center(child: Text('加载笔记失败'));
      },
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _HomeSearchResults extends StatelessWidget {
  const _HomeSearchResults({
    required this.searchResults,
    required this.currentLayout,
    required this.noteService,
    required this.scrollController,
  });

  final AsyncValue<List<Note>> searchResults;
  final NoteLayout currentLayout;
  final NoteService noteService;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return searchResults.when(
      data: (notes) {
        if (notes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 80.sp,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                SizedBox(height: 16.h),
                Text(
                  '未找到相关笔记',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                SizedBox(height: 8.h),
                Text('尝试使用其他关键词', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          );
        }

        return _NotesListView(
          notes: notes,
          currentLayout: currentLayout,
          noteService: noteService,
          scrollController: scrollController,
        );
      },
      error: (error, stack) {
        PMlog.e(tag, '搜索错误: $error, stack:$stack');
        return const Center(child: Text('搜索失败'));
      },
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _NotesListView extends StatelessWidget {
  const _NotesListView({
    required this.notes,
    required this.currentLayout,
    required this.noteService,
    required this.scrollController,
  });

  final List<Note> notes;
  final NoteLayout currentLayout;
  final NoteService noteService;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (currentLayout == NoteLayout.grid) {
      return MasonryGridView.count(
        controller: scrollController,
        key: const PageStorageKey('masonry_grid_view'),
        crossAxisCount: 2,
        cacheExtent: 500.h,
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          return RepaintBoundary(
            child: NoteItem(
              note: note,
              noteService: noteService,
              isWaterfall: true,
              key: ValueKey('note_${note.id}'),
            ),
          );
        },
      );
    }

    return ListView.builder(
      controller: scrollController,
      key: const PageStorageKey('list_view'),
      cacheExtent: 500.h,
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return RepaintBoundary(
          child: NoteItem(
            note: note,
            noteService: noteService,
            isWaterfall: false,
            key: ValueKey('note_${note.id}'),
          ),
        );
      },
    );
  }
}

class _InitialPullSkeleton extends StatelessWidget {
  const _InitialPullSkeleton();

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      itemCount: 6,
      separatorBuilder: (_, _) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        return Container(
          height: 112.h,
          decoration: BoxDecoration(
            color: appColors.skeletonBase,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: appColors.cardBorder),
          ),
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: (0.55 + (index % 3) * 0.12).sw,
                height: 16.h,
                decoration: BoxDecoration(
                  color: appColors.skeletonHighlight,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
              SizedBox(height: 14.h),
              Container(
                width: double.infinity,
                height: 12.h,
                decoration: BoxDecoration(
                  color: appColors.skeletonHighlight,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                width: 0.72.sw,
                height: 12.h,
                decoration: BoxDecoration(
                  color: appColors.skeletonHighlight,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  width: 64.w,
                  height: 22.h,
                  decoration: BoxDecoration(
                    color: appColors.skeletonHighlight,
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
