import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/page/widget/note_item.dart';
import 'package:pocketmind/page/widget/desktop/desktop_header.dart';
import 'package:pocketmind/page/home/note_add_sheet.dart';
import 'package:pocketmind/page/home/mixin/search_logic_mixin.dart';
import 'package:pocketmind/providers/nav_providers.dart';
import 'package:pocketmind/providers/note_providers.dart';
import 'package:pocketmind/providers/ui_providers.dart';
import 'package:pocketmind/providers/app_config_provider.dart';
import 'package:pocketmind/util/logger_service.dart';

final String tag = 'DesktopHomeScreen';

/// 桌面端主屏幕布局
/// 左侧固定侧边栏 + 右侧自适应内容区
class DesktopHomeScreen extends ConsumerStatefulWidget {
  const DesktopHomeScreen({super.key});

  @override
  ConsumerState<DesktopHomeScreen> createState() => _DesktopHomeScreenState();
}

class _DesktopHomeScreenState extends ConsumerState<DesktopHomeScreen>
    with SearchLogicMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 动态计算网格列数
  /// 基于内容区域宽度自适应调整
  /// 桌面端使用更少的列数，让卡片更宽更矮（类似杂志排版风格）
  int _calculateCrossAxisCount(double width) {
    if (width < 600) return 1;
    if (width < 900) return 2;
    if (width < 1400) return 3;
    if (width < 1800) return 4;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final noteByCategory = ref.watch(noteByCategoryProvider);
    final noteService = ref.watch(noteServiceProvider);
    final currentLayout = ref.watch(appConfigProvider).waterfallLayoutEnabled
        ? NoteLayout.grid
        : NoteLayout.list;
    final searchQuery = ref.watch(searchQueryProvider);
    final searchResults = ref.watch(searchResultsProvider);
    final isAddingNote = ref.watch(isAddingNoteProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: isAddingNote
          ? NoteEditorSheet(
              onClose: () {
                ref.read(isAddingNoteProvider.notifier).set(false);
              },
            )
          : Column(
              children: [
                // macOS 顶部预留空间 (窗口控制按钮)
                if (Platform.isMacOS) SizedBox(height: 28.h),

                // 顶部导航栏
                DesktopHeader(
                  searchController: searchController,
                  searchFocusNode: searchFocusNode,
                  onSearchSubmit: submitSearch,
                  onClear: clearSearch,
                ),

                // 内容区域
                Expanded(
                  child: (searchQuery != null && searchQuery.isNotEmpty)
                      ? _buildSearchResults(
                          searchResults,
                          currentLayout,
                          noteService,
                        )
                      : noteByCategory.when(
                          skipLoadingOnRefresh: true,
                          data: (notes) => _buildNotesContent(
                            notes,
                            currentLayout,
                            noteService,
                          ),
                          error: (error, stack) {
                            PMlog.e(tag, 'stack: $error,stack:$stack');
                            return const Center(child: Text('加载笔记失败'));
                          },
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                        ),
                ),
              ],
            ),
      // FAB - 桌面端放在右下角
      floatingActionButton: !isAddingNote
          ? FloatingActionButton(
              onPressed: () => _showAddNotePage(context),
              elevation: 8,
              child: Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.tertiary,
                      colorScheme.tertiary.withValues(alpha: 0.85),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.tertiary.withValues(alpha: 0.4),
                      blurRadius: 16.r,
                      offset: Offset(0, 6.h),
                    ),
                  ],
                ),
                child: Icon(Icons.add, size: 28.sp),
              ),
            )
          : null,
    );
  }

  /// 显示添加笔记页面（嵌入式）
  void _showAddNotePage(BuildContext context) {
    ref.read(isAddingNoteProvider.notifier).set(true);
  }

  /// 构建笔记内容区域
  Widget _buildNotesContent(
    List<Note> notes,
    NoteLayout currentLayout,
    noteService,
  ) {
    if (notes.isEmpty) {
      return _buildEmptyState();
    }
    return _buildNotesList(notes, currentLayout, noteService);
  }

  /// 构建空状态占位
  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add_outlined,
            size: 100.sp,
            color: colorScheme.secondary.withValues(alpha: 0.4),
          ),
          SizedBox(height: 24.h),
          Text(
            '你的思绪将汇聚于此',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: colorScheme.secondary),
          ),
          SizedBox(height: 12.h),
          Text(
            '点击右下角，捕捉第一个灵感',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.secondary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建搜索结果
  Widget _buildSearchResults(
    AsyncValue<List<Note>> searchResults,
    NoteLayout currentLayout,
    noteService,
  ) {
    return searchResults.when(
      data: (notes) {
        if (notes.isEmpty) {
          return _buildSearchEmptyState();
        }
        return _buildNotesList(notes, currentLayout, noteService);
      },
      error: (error, stack) {
        PMlog.e(tag, '搜索错误: $error, stack:$stack');
        return const Center(child: Text('搜索失败'));
      },
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  /// 构建搜索结果为空状态
  Widget _buildSearchEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 100.sp,
            color: colorScheme.secondary.withValues(alpha: 0.4),
          ),
          SizedBox(height: 24.h),
          Text(
            '未找到相关笔记',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: colorScheme.secondary),
          ),
          SizedBox(height: 12.h),
          Text(
            '尝试使用其他关键词',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.secondary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建笔记列表
  /// 复用 NoteItem 组件，支持网格和列表两种布局
  Widget _buildNotesList(
    List<Note> notes,
    NoteLayout currentLayout,
    noteService,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth;

        if (currentLayout == NoteLayout.grid) {
          // 瀑布流布局 - 动态列数
          final crossAxisCount = _calculateCrossAxisCount(contentWidth);
          return MasonryGridView.count(
            controller: _scrollController,
            key: const PageStorageKey('desktop_masonry_grid_view'),
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8.w,
            mainAxisSpacing: 8.h,
            cacheExtent: 500.h,
            padding: EdgeInsets.all(24.r),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return RepaintBoundary(
                child: NoteItem(
                  note: note,
                  noteService: noteService,
                  isWaterfall: true,
                  isDesktop: true,
                  key: ValueKey('desktop_note_${note.id}'),
                ),
              );
            },
          );
        } else {
          // 列表布局 - 限制最大宽度使其居中
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 800.w),
              child: ListView.builder(
                controller: _scrollController,
                key: const PageStorageKey('desktop_list_view'),
                cacheExtent: 500.h,
                padding: EdgeInsets.all(24.r),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  return Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: RepaintBoundary(
                      child: NoteItem(
                        note: note,
                        noteService: noteService,
                        isWaterfall: false,
                        isDesktop: true,
                        key: ValueKey('desktop_note_${note.id}'),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }
      },
    );
  }
}
