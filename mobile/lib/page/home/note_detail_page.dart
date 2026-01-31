import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/providers/category_providers.dart';
import 'package:pocketmind/providers/app_config_provider.dart';
import 'package:pocketmind/providers/note_providers.dart';
import 'package:pocketmind/util/responsive_breakpoints.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widget/creative_toast.dart';
import '../widget/note_detail/note_detail_top_bar.dart';
import '../widget/note_detail/note_detail_sidebar.dart';
import '../widget/note_detail/note_tags_section.dart';
import '../widget/note_detail/note_ai_insight_section.dart';
import '../widget/note_detail/note_original_data_section.dart';
import '../../util/date_formatter.dart';

/// 笔记详情页
/// 桌面端：左右分栏布局
/// 移动端：垂直滚动布局
class NoteDetailPage extends ConsumerStatefulWidget {
  final Note note;

  /// 桌面端返回回调 - 用于清除选中状态
  final VoidCallback? onBack;

  const NoteDetailPage({super.key, required this.note, this.onBack});

  @override
  ConsumerState<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends ConsumerState<NoteDetailPage> {
  late final ScrollController _scrollController;
  TextEditingController? _titleController;
  TextEditingController? _contentController;
  late Note _currentNote;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    _currentNote = widget.note;
    _initControllers(_currentNote);
  }

  void _initControllers(Note note) {
    _contentController = TextEditingController(text: note.content ?? '');
    _titleController = TextEditingController(text: note.title ?? '');

    // 监听输入变化并更新 Notifier
    _titleController!.addListener(() {
      ref
          .read(noteDetailProvider(note).notifier)
          .updateNote(title: _titleController!.text);
    });
    _contentController!.addListener(() {
      ref
          .read(noteDetailProvider(note).notifier)
          .updateNote(content: _contentController!.text);
    });

    // Future.microtask(() {
    //   if (!mounted) return;
    //
    //   // 仅当内容为空且从未尝试过（status == null）时才自动加载
    //   // 如果 status != null (说明已尝试过，无论是 SUCCESS 还是 FAILED)，都不再自动重试
    //   final shouldFetchBackendContent =
    //       (note.previewContent == null || note.previewContent!.isEmpty) &&
    //       note.resourceStatus == null;
    //   // 用 预览 兜底
    //   final shouldFetchPreview =
    //       (note.previewDescription == null &&
    //       note.previewDescription!.isEmpty ||
    //       note.previewTitle == null ||
    //       note.previewTitle!.isEmpty);
    //   if ((shouldFetchPreview || shouldFetchBackendContent) &&
    //       _currentNote.url != null) {
    //     ref.read(metadataManagerProvider).fetchAndProcessMetadata([
    //       _currentNote.url!,
    //     ]);
    //   }
    // });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _contentController?.dispose();
    _titleController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final showSidebar = ResponsiveBreakpoints.shouldShowNoteDetailSidebar(
      screenWidth,
    );

    // 监听详情状态
    final detailState = ref.watch(noteDetailProvider(_currentNote));

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部导航栏
            NoteDetailTopBar(
              onBack: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
              onShare: _onSharePressed,
              onEdit: () {}, // TODO: 编辑模式切换
              onDelete: _onDeletePressed,
            ),

            // 主内容区域
            Expanded(
              child: showSidebar
                  ? _buildDesktopLayout(detailState, colorScheme, textTheme)
                  : _buildMobileLayout(detailState, colorScheme, textTheme),
            ),
          ],
        ),
      ),
    );
  }

  /// 桌面端布局 - 左右分栏
  Widget _buildDesktopLayout(
    NoteDetailState state,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧内容区 (占 2/3)
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.only(bottom: 80.h),
            child: NoteOriginalDataSection(
              note: state.note,
              titleController: _titleController!,
              contentController: _contentController!,
              onCategorySelected: (id) => ref
                  .read(noteDetailProvider(_currentNote).notifier)
                  .updateCategory(id),
              categoryName: _getCategoryName(state.note.categoryId),
              formattedDate: DateFormatter.formatChinese(state.note.time),

              previewTitle: state.note.previewTitle,
              previewContent:
                  state.note.previewContent ?? state.note.previewDescription,
              isLoadingPreview: state.isLoading,
              onSave: () => ref
                  .read(noteDetailProvider(_currentNote).notifier)
                  .saveNote(),
              onLaunchUrl: _launchUrl,
              isDesktop: true,
              titleEnabled: ref.watch(appConfigProvider).titleEnabled,
            ),
          ),
        ),

        // 右侧元信息区 (固定宽度约 360)
        Container(
          width: 360,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: NoteDetailSidebar(
              note: state.note,
              onLaunchUrl: _launchUrl,
              tags: state.tags,
              onTagsChanged: (newTags) {
                final oldTags = state.tags;
                final added = newTags.toSet().difference(oldTags.toSet());
                final removed = oldTags.toSet().difference(newTags.toSet());

                final notifier = ref.read(
                  noteDetailProvider(_currentNote).notifier,
                );

                for (var tag in added) {
                  notifier.addTag(tag);
                }
                for (var tag in removed) {
                  notifier.removeTag(tag);
                }
              },
              formattedDate: DateFormatter.formatChinese(state.note.time),
            ),
          ),
        ),
      ],
    );
  }

  /// 移动端布局 - 垂直滚动
  Widget _buildMobileLayout(
    NoteDetailState state,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.only(bottom: 80.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 原始数据区
          NoteOriginalDataSection(
            note: state.note,
            titleController: _titleController!,
            contentController: _contentController!,
            onCategorySelected: (id) => ref
                .read(noteDetailProvider(_currentNote).notifier)
                .updateCategory(id),
            categoryName: _getCategoryName(state.note.categoryId),
            formattedDate: DateFormatter.formatChinese(state.note.time),
            previewTitle: state.note.previewTitle,
            previewContent:
                state.note.previewContent ?? state.note.previewDescription,
            isLoadingPreview: state.isLoading,
            onSave: () =>
                ref.read(noteDetailProvider(_currentNote).notifier).saveNote(),
            onLaunchUrl: _launchUrl,
            isDesktop: false,
            titleEnabled: ref.watch(appConfigProvider).titleEnabled,
          ),

          SizedBox(height: 24.h),

          // 2. AI 洞察区
          if (state.note.aiSummary != null && state.note.aiSummary!.isNotEmpty)
            NoteAIInsightSection(aiSummary: state.note.aiSummary!), //

          SizedBox(height: 32.h),

          // 3. 元数据/标签区
          NoteTagsSection(
            tags: state.tags,
            onTagsChanged: (newTags) {
              // 找出新增的或删除的
              // 简单处理：直接更新整个列表
              // 但 NoteDetailNotifier 可能只有 addTag 和 removeTag
              // 我们需要适配一下
              final oldTags = state.tags;
              final added = newTags.toSet().difference(oldTags.toSet());
              final removed = oldTags.toSet().difference(newTags.toSet());

              final notifier = ref.read(
                noteDetailProvider(_currentNote).notifier,
              );

              for (var tag in added) {
                notifier.addTag(tag);
              }
              for (var tag in removed) {
                notifier.removeTag(tag);
              }
            },
          ),

          SizedBox(height: 32.h),
        ],
      ),
    );
  }

  /// 分享笔记
  void _onSharePressed() {
    ref.read(noteDetailProvider(_currentNote).notifier).shareNote(context);
  }

  /// 删除笔记
  void _onDeletePressed() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除笔记',
      message: '确定要删除这条笔记吗？此操作无法撤销',
      cancelText: '取消',
      confirmText: '确认',
    );
    if (confirmed == true) {
      await ref.read(noteDetailProvider(_currentNote).notifier).deleteNote();
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
        CreativeToast.success(
          context,
          title: '笔记已删除',
          message: '该笔记已被永久删除',
          direction: ToastDirection.top,
        );
      }
    }
  }

  /// 获取分类名称
  String _getCategoryName(int categoryId) {
    final categoriesAsync = ref.read(allCategoriesProvider);
    if (!categoriesAsync.hasValue) return 'HOME';
    final categories = categoriesAsync.value;
    if (categories != null) {
      final category = categories.firstWhere(
        (c) => c.id == categoryId,
        orElse: () => categories.first,
      );
      return category.name.toUpperCase();
    }
    return 'HOME';
  }

  /// 跳转 URL
  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
