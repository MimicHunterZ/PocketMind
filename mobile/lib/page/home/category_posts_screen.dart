import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketmind/model/category.dart';
import 'package:pocketmind/page/home/home_screen.dart';
import 'package:pocketmind/page/home/widgets/unified_home_background.dart';
import 'package:pocketmind/page/widget/creative_toast.dart';
import 'package:pocketmind/providers/category_providers.dart';
import 'package:pocketmind/providers/note_providers.dart';
import 'package:pocketmind/util/theme_data.dart';

class CategoryPostsScreen extends ConsumerStatefulWidget {
  const CategoryPostsScreen({super.key, required this.categoryId});

  final int categoryId;

  @override
  ConsumerState<CategoryPostsScreen> createState() => _CategoryPostsScreenState();
}

class _CategoryPostsScreenState extends ConsumerState<CategoryPostsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final ext = CategoryHomeColors.of(context);

    return categoriesAsync.when(
      data: (categories) {
        final category = resolveCategoryById(categories, widget.categoryId);

        return Scaffold(
          backgroundColor: ext.unifiedHomeBackground,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(category.name),
            centerTitle: false,
            actions: [
              PopupMenuButton<_CategoryMenuAction>(
                key: const ValueKey('category_posts_menu_button'),
                onSelected: (action) => _handleMenuAction(action, category),
                itemBuilder: (context) => const [
                  PopupMenuItem<_CategoryMenuAction>(
                    value: _CategoryMenuAction.rename,
                    child: Text('修改分类名字'),
                  ),
                  PopupMenuItem<_CategoryMenuAction>(
                    value: _CategoryMenuAction.description,
                    child: Text('修改分类描述'),
                  ),
                  PopupMenuItem<_CategoryMenuAction>(
                    value: _CategoryMenuAction.delete,
                    child: Text('删除分类'),
                  ),
                ],
              ),
            ],
          ),
          body: UnifiedHomeBackground(
            child: CategoryPostsBody(
              categoryId: widget.categoryId,
              scrollController: _scrollController,
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const Scaffold(body: Center(child: Text('分类加载失败'))),
    );
  }

  Future<void> _handleMenuAction(_CategoryMenuAction action, Category category) async {
    switch (action) {
      case _CategoryMenuAction.rename:
        await _showRenameDialog(category);
        return;
      case _CategoryMenuAction.description:
        await _showDescriptionDialog(category);
        return;
      case _CategoryMenuAction.delete:
        await _deleteCategory(category);
        return;
    }
  }

  Future<void> _showRenameDialog(Category category) async {
    final text = await showInputDialog(
      context,
      title: '修改分类名字',
      hintText: '请输入新的分类名字',
      initialValue: category.name,
    );
    if (text == null || text.trim().isEmpty) return;

    await ref
        .read(categoryActionsProvider.notifier)
        .updateCategory(categoryId: widget.categoryId, name: text.trim());
  }

  Future<void> _showDescriptionDialog(Category category) async {
    final text = await showInputDialog(
      context,
      title: '修改分类描述',
      hintText: '请输入新的分类描述',
      initialValue: category.description,
      maxLines: 3,
    );
    if (text == null) return;

    await ref.read(categoryActionsProvider.notifier).updateCategory(
      categoryId: widget.categoryId,
      description: text.trim(),
    );
  }

  Future<void> _deleteCategory(Category category) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除分类',
      message: '确定删除分类 "${category.name}" 以及该分类下所有帖子吗？',
      confirmText: '确认删除',
      cancelText: '取消',
    );
    if (confirmed != true) return;

    await ref.read(noteServiceProvider).deleteAllNoteByCategoryId(widget.categoryId);
    await ref.read(categoryActionsProvider.notifier).deleteCategory(widget.categoryId);

    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

enum _CategoryMenuAction { rename, description, delete }
