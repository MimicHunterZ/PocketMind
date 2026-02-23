import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketmind/page/home/note_add_sheet.dart';
import 'package:pocketmind/page/widget/creative_toast.dart';
import 'package:pocketmind/providers/nav_providers.dart';
import 'package:pocketmind/providers/note_providers.dart';

/// 笔记编辑器逻辑 Mixin
/// 处理表单状态、控制器、保存和关闭逻辑
mixin NoteEditorLogicMixin on ConsumerState<NoteEditorSheet> {
  // 控制器
  late final TextEditingController titleController;
  late final TextEditingController contentController;

  // 状态
  int selectedCategoryId = 1; // 默认分类ID
  List<String> tags = []; // 标签列表

  // 图片相关
  String? localImagePath;
  String? uploadedImageUrl; // 模拟上传后的URL
  bool isImageInputVisible = false;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController();
    contentController = TextEditingController();

    // 初始化分类
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final activeId = await ref.read(activeCategoryIdProvider.future);
      if (mounted) {
        setState(() {
          selectedCategoryId = activeId;
        });
      }
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  /// 更新标签列表
  void updateTags(List<String> newTags) {
    setState(() {
      tags = newTags;
    });
  }

  /// 选择分类
  void selectCategory(int id) {
    setState(() {
      selectedCategoryId = id;
    });
  }

  /// 关闭编辑器
  Future<void> handleClose() async {
    // 简单的关闭动画或逻辑
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).pop();
    }
  }

  /// 保存笔记
  Future<void> onSave() async {
    final title = titleController.text.trim();
    final content = contentController.text.trim();

    if (content.isEmpty && title.isEmpty) {
      CreativeToast.error(
        context,
        title: '空笔记',
        message: '请至少输入标题或内容',
        direction: ToastDirection.top,
      );
      return;
    }

    final noteService = ref.read(noteServiceProvider);

    try {
      await noteService.addNote(
        title: title.isNotEmpty ? title : null,
        content: content,
        categoryId: selectedCategoryId,
        tags: tags,
        previewImageUrl: uploadedImageUrl ?? localImagePath,
      );

      if (!mounted) return;

      CreativeToast.success(
        context,
        title: '已保存',
        message: '笔记已成功保存',
        direction: ToastDirection.top,
      );
      await handleClose();
    } catch (e) {
      if (!mounted) return;
      CreativeToast.error(
        context,
        title: '保存失败',
        message: e.toString(),
        direction: ToastDirection.top,
      );
    }
  }

  /// 清除图片
  void clearImage() {
    setState(() {
      localImagePath = null;
      isImageInputVisible = false;
    });
  }
}
