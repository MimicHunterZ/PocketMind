import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketmind/core/constants.dart';
import 'package:pocketmind/model/category.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/page/chat/chat_page.dart';
import 'package:pocketmind/page/home/mixin/search_logic_mixin.dart';
import 'package:pocketmind/page/home/note_add_sheet.dart';
import 'package:pocketmind/page/home/widgets/note_feed_paged_view.dart';
import 'package:pocketmind/page/home/widgets/category_grid.dart';
import 'package:pocketmind/page/home/widgets/home_tab_bar.dart';
import 'package:pocketmind/page/home/widgets/home_top_bar.dart';
import 'package:pocketmind/page/home/widgets/unified_home_background.dart';
import 'package:pocketmind/page/widget/add_category_dialog.dart';
import 'package:pocketmind/providers/app_config_provider.dart';
import 'package:pocketmind/providers/category_providers.dart';
import 'package:pocketmind/providers/chat_providers.dart';
import 'package:pocketmind/providers/nav_providers.dart';
import 'package:pocketmind/providers/note_providers.dart';
import 'package:pocketmind/router/route_paths.dart';
import 'package:pocketmind/sync/sync_state_provider.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'package:pocketmind/util/theme_data.dart';

final String tag = 'HomeScreen';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.openChatSession,
    this.resolveGlobalSessionUuid,
  });

  final Future<void> Function(BuildContext context, String sessionUuid)?
      openChatSession;
  final Future<String> Function()? resolveGlobalSessionUuid;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SearchLogicMixin {
  HomeTab _tab = HomeTab.everything;
  final ScrollController _scrollController = ScrollController();
  bool _isSearchMode = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = CategoryHomeColors.of(context);

    return Scaffold(
      backgroundColor: ext.unifiedHomeBackground,
      body: UnifiedHomeBackground(
        child: Column(
          children: [
            if (_tab != HomeTab.everything)
              const SafeArea(top: true, bottom: false, child: SizedBox.shrink()),
            if (_tab == HomeTab.everything)
              HomeTopBar(
                showSearchInput: _isSearchMode,
                searchController: searchController,
                searchFocusNode: searchFocusNode,
                onSearchBackTap: _exitSearchMode,
                onAvatarTap: () => context.push(RoutePaths.settings),
                onSearchTap: _enterSearchMode,
                onAddTap: () => Navigator.of(context).push(NoteEditorRoute()),
              ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: _tab == HomeTab.category
          ? FloatingActionButton(
              onPressed: _showAddCategory,
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: HomeTabBar(
        currentTab: _tab,
        onChanged: _handleTabChange,
      ),
    );
  }

  Widget _buildBody() {
    return switch (_tab) {
      HomeTab.everything => _EverythingPane(scrollController: _scrollController),
      HomeTab.ai => const SizedBox.shrink(),
      HomeTab.category => const _CategoryTab(),
    };
  }

  Future<void> _handleTabChange(HomeTab tab) async {
    if (tab == HomeTab.ai) {
      final previousTab = _tab;
      if (_isSearchMode) {
        setState(() {
          _isSearchMode = false;
        });
        clearSearch();
      }

      setState(() {
        _tab = HomeTab.ai;
      });
      await _openGlobalAiSession();
      if (!mounted) return;
      setState(() {
        _tab = previousTab == HomeTab.ai
            ? HomeTab.everything
            : previousTab;
      });
      return;
    }

    setState(() {
      _tab = tab;
      if (tab != HomeTab.everything && _isSearchMode) {
        _isSearchMode = false;
        clearSearch();
      }
    });
  }

  void _enterSearchMode() {
    setState(() => _isSearchMode = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      searchFocusNode.requestFocus();
    });
  }

  void _exitSearchMode() {
    setState(() => _isSearchMode = false);
    clearSearch();
    searchFocusNode.unfocus();
  }

  Future<void> _showAddCategory() async {
    final result = await showAddCategoryDialog(context);
    if (result == null) return;
    await ref.read(categoryActionsProvider.notifier).addCategory(
          name: result.name,
          description: result.description,
          iconPath: result.iconPath,
        );
  }

  Future<void> _openGlobalAiSession() async {
    final customResolver = widget.resolveGlobalSessionUuid;
    final sessionUuid = customResolver != null
        ? await customResolver()
        : await _resolveGlobalSessionUuid();

    if (!mounted) return;
    final customOpenChat = widget.openChatSession;
    if (customOpenChat != null) {
      await customOpenChat(context, sessionUuid);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(sessionUuid: sessionUuid),
      ),
    );
  }

  Future<String> _resolveGlobalSessionUuid() async {
    final repo = ref.read(chatSessionRepositoryProvider);
    final service = ref.read(chatServiceProvider);
    final globalSessions = await repo.findGlobalSessions();
    if (globalSessions.isNotEmpty) {
      return globalSessions.first.uuid;
    }
    final created = await service.createSession(noteUuid: null);
    return created.uuid;
  }
}

class _EverythingPane extends ConsumerWidget {
  const _EverythingPane({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLayout = ref.watch(
      appConfigProvider.select(
        (config) =>
            config.waterfallLayoutEnabled ? NoteLayout.grid : NoteLayout.list,
      ),
    );
    final searchQuery = ref.watch(searchQueryProvider);

    if (searchQuery != null) {
      final searchResults = ref.watch(searchResultsProvider);
      return searchResults.when(
        data: (notes) {
          if (notes.isEmpty) {
            return const Center(child: Text('未找到相关笔记'));
          }
          final noteService = ref.read(noteServiceProvider);
          return NoteFeedPagedView(
            notes: notes,
            currentLayout: currentLayout,
            noteService: noteService,
            scrollController: scrollController,
            itemKeyPrefix: 'search_note',
          );
        },
        error: (error, stack) {
          PMlog.e(tag, '搜索错误: $error, stack:$stack');
          return const Center(child: Text('搜索失败'));
        },
        loading: () => const Center(child: CircularProgressIndicator()),
      );
    }

    final isInitialPull = ref.watch(syncIsInitialPullProvider);
    if (isInitialPull) {
      return const Center(child: CircularProgressIndicator());
    }

    final allNotesAsync = ref.watch(allNotesProvider);
    return allNotesAsync.when(
      data: (notes) {
        if (notes.isEmpty) {
          return Center(
            child: Text(
              '你的思绪将汇聚于此',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }
        final noteService = ref.read(noteServiceProvider);

        return NoteFeedPagedView(
          notes: notes,
          currentLayout: currentLayout,
          noteService: noteService,
          scrollController: scrollController,
          itemKeyPrefix: 'note',
        );
      },
      error: (error, stack) {
        PMlog.e(tag, '加载失败: $error, stack:$stack');
        return const Center(child: Text('加载笔记失败'));
      },
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _CategoryTab extends ConsumerWidget {
  const _CategoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryAsync = ref.watch(allCategoriesProvider);
    return categoryAsync.when(
      data: (categories) {
        if (categories.isEmpty) {
          return const SizedBox.shrink();
        }
        final visibleCategories = categories
            .where((item) => item.id != AppConstants.homeCategoryId)
            .toList();
        if (visibleCategories.isEmpty) {
          return const SizedBox.shrink();
        }
        return CategoryGrid(categories: visibleCategories);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('分类加载失败')),
    );
  }
}

class CategoryPostsBody extends ConsumerWidget {
  const CategoryPostsBody({
    super.key,
    required this.categoryId,
    required this.scrollController,
    this.emptyText = '暂无帖子',
  });

  final int categoryId;
  final ScrollController scrollController;
  final String emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLayout = ref.watch(
      appConfigProvider.select(
        (config) =>
            config.waterfallLayoutEnabled ? NoteLayout.grid : NoteLayout.list,
      ),
    );
    final noteService = ref.read(noteServiceProvider);

    return StreamBuilder<List<Note>>(
      stream: noteService.watchCategoryNotes(categoryId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final notes = snapshot.data!;
        if (notes.isEmpty) {
          return Center(child: Text(emptyText));
        }

        return NoteFeedPagedView(
          notes: notes,
          currentLayout: currentLayout,
          noteService: noteService,
          scrollController: scrollController,
          itemKeyPrefix: 'category_note',
        );
      },
    );
  }
}

Category resolveCategoryById(List<Category> categories, int categoryId) {
  return categories.firstWhere(
    (item) => item.id == categoryId,
    orElse: () => Category()
      ..id = categoryId
      ..name = '分类',
  );
}
