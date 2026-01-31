import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pocketmind/page/widget/add_category_dialog.dart';
import 'package:pocketmind/page/widget/category_selector.dart';
import 'package:pocketmind/providers/note_providers.dart';
import 'package:pocketmind/providers/category_providers.dart';
import 'package:pocketmind/providers/app_config_provider.dart';
import 'package:pocketmind/providers/infrastructure_providers.dart';
import 'package:intl/intl.dart';

import 'package:pocketmind/page/widget/creative_time_picker.dart';

// 标签页枚举
enum EditTab { title, content, tags, category, ai, reminder }

class EditNotePage extends ConsumerStatefulWidget {
  final String? initialTitle;
  final String? initialContent;
  final void Function(Map<String, String> data) onDone;
  final int id;
  final String? webUrl;

  const EditNotePage({
    super.key,
    required this.initialTitle,
    required this.initialContent,
    required this.onDone,
    this.webUrl,
    required this.id,
  });

  @override
  ConsumerState<EditNotePage> createState() => EditNotePageState();
}

class EditNotePageState extends ConsumerState<EditNotePage> {
  late final TextEditingController _contentController;
  late final TextEditingController _tagController;
  late final TextEditingController _titleController;
  late final TextEditingController _aiController;

  bool _titleEnabled = false;

  EditTab _currentTab = EditTab.content; // 默认从内容标签开始

  String _selectedCategory = 'home';
  int _selectedCategoryId = 1;
  DateTime? _scheduledTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _contentController = TextEditingController(text: widget.initialContent);
    _tagController = TextEditingController();
    _aiController = TextEditingController();
    // 在下一帧获取配置，因为 initState 中不能直接 watch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTitleSetting();
    });
  }

  Future<void> _loadTitleSetting() async {
    final config = ref.read(appConfigProvider);
    setState(() {
      _titleEnabled = config.titleEnabled;
      // 根据标题启用状态选择初始标签页
      _currentTab = _titleEnabled ? EditTab.title : EditTab.content;
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _tagController.dispose();
    _titleController.dispose();
    _aiController.dispose();
    super.dispose();
  }

  void _onDone() async {
    final noteService = ref.read(noteServiceProvider);
    await noteService.updateNote(
      id: widget.id,
      title: _titleEnabled ? _titleController.text : null, // 根据设置决定是否保存标题
      content: _contentController.text,
      url: widget.webUrl,
      categoryId: _selectedCategoryId, // 使用选中的分类ID
      tag: _tagController.text,
    );

    if (_scheduledTime != null) {
      final notificationService = ref.read(notificationServiceProvider);
      final config = ref.read(appConfigProvider);
      await notificationService.requestPermissions();
      await notificationService.scheduleNotification(
        id: widget.id,
        title: _titleEnabled && _titleController.text.isNotEmpty
            ? _titleController.text
            : '笔记提醒',
        body: _contentController.text.isNotEmpty
            ? _contentController.text
            : '您有一条笔记提醒。',
        scheduledDate: _scheduledTime!,
        highPrecision: config.highPrecisionNotification,
      );
    }

    Map<String, String> result = {'uq': _aiController.text};

    widget.onDone(result);
  }

  // 构建顶部导航栏
  Widget _buildTopNavBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: Colors.transparent, // 透明背景以显示底层 FlowingBackground
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 只在启用标题时显示标题标签
            if (_titleEnabled) ...[
              _buildNavTab(
                icon: Icons.title_outlined,
                label: '标题',
                tab: EditTab.title,
                colorScheme: colorScheme,
              ),
              SizedBox(width: 40.w),
            ],
            _buildNavTab(
              icon: Icons.note_outlined,
              label: '正文',
              tab: EditTab.content,
              colorScheme: colorScheme,
            ),
            SizedBox(width: 40.w),
            _buildNavTab(
              icon: Icons.circle_outlined,
              label: '分类',
              tab: EditTab.category,
              colorScheme: colorScheme,
            ),
            SizedBox(width: 40.w),
            _buildNavTab(
              icon: Icons.local_offer_outlined,
              label: '标签',
              tab: EditTab.tags,
              colorScheme: colorScheme,
            ),
            SizedBox(width: 40.w),
            _buildNavTab(
              icon: Icons.question_answer_outlined,
              label: 'AI',
              tab: EditTab.ai,
              colorScheme: colorScheme,
            ),
            SizedBox(width: 40.w),
            _buildNavTab(
              icon: Icons.alarm,
              label: '提醒',
              tab: EditTab.reminder,
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  // 构建单个导航标签
  Widget _buildNavTab({
    required IconData icon,
    required String label,
    required EditTab tab,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _currentTab == tab;
    final color = isSelected ? colorScheme.primary : colorScheme.secondary;

    return GestureDetector(
      onTap: () => setState(() => _currentTab = tab),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24.sp),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14.sp,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // 构建内容/标题/AI编辑页面
  Widget _buildNotesContent(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      alignment: Alignment.topLeft,
      child: TextField(
        controller: _currentTab == EditTab.content
            ? _contentController
            : _currentTab == EditTab.title
            ? _titleController
            : _aiController,
        decoration: InputDecoration(
          hintText: '开始输入...',
          hintStyle: TextStyle(color: colorScheme.secondary, fontSize: 16.sp),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        style: TextStyle(
          fontSize: 16.sp,
          color: colorScheme.onSurface,
          height: 1.5,
        ),
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget _buildTagsContent(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _tagController,
            decoration: InputDecoration(
              hintText: '添加标签...',
              hintStyle: TextStyle(
                color: colorScheme.secondary,
                fontSize: 16.sp,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            style: TextStyle(fontSize: 16.sp, color: colorScheme.onSurface),
          ),
          SizedBox(height: 24.h),
          Text(
            '最近标签',
            style: TextStyle(
              color: colorScheme.secondary.withValues(alpha: 0.6),
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            '暂无最近使用的标签',
            style: TextStyle(
              color: colorScheme.secondary.withValues(alpha: 0.4),
              fontSize: 14.sp,
            ),
          ),
        ],
      ),
    );
  }

  /// 显示添加分类对话框（通过 Provider 处理业务逻辑）
  Future<void> _showAddCategoryDialog() async {
    final result = await showAddCategoryDialog(context);
    if (result != null) {
      await ref
          .read(categoryActionsProvider.notifier)
          .addCategory(name: result.name, iconPath: result.iconPath);
    }
  }

  // 构建分类选择页面
  Widget _buildCategoryContent(ColorScheme colorScheme) {
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          categoriesAsync.when(
            data: (categories) {
              if (categories.isEmpty) {
                return Text(
                  '暂无分类',
                  style: TextStyle(color: colorScheme.secondary),
                );
              }

              // 如果当前未选择分类，或默认分类找不到，选中第一个分类
              final fallbackCategory = categories.first;
              final matchedCategory = categories.firstWhere(
                (category) => category.name == _selectedCategory,
                orElse: () => fallbackCategory,
              );

              // 异步更新选中的分类ID
              if (_selectedCategoryId != matchedCategory.id) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() {
                    _selectedCategoryId = matchedCategory.id ?? 0;
                    _selectedCategory = matchedCategory.name;
                  });
                });
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...categories.map((category) {
                    final iconPath = getCategoryIcon(category);
                    return RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      secondary: SvgPicture.asset(
                        iconPath,
                        width: 20.w,
                        height: 20.w,
                        colorFilter: ColorFilter.mode(
                          _selectedCategory == category.name
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          BlendMode.srcIn,
                        ),
                      ),
                      title: Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      value: category.name,
                      groupValue: _selectedCategory,
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value!;
                          _selectedCategoryId = category.id ?? 0;
                        });
                      },
                      activeColor: colorScheme.primary,
                    );
                  }),
                  // 添加分类按钮 - 使用统一对话框
                  SizedBox(height: 16.h),
                  GestureDetector(
                    onTap: _showAddCategoryDialog,
                    child: Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(50.r),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.2),
                          width: 1.w,
                        ),
                      ),
                      child: Icon(
                        Icons.add,
                        color: colorScheme.primary,
                        size: 24.sp,
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Text(
              '加载分类失败: $error',
              style: TextStyle(color: colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderContent(ColorScheme colorScheme) {
    final shortcuts = ref.watch(appConfigProvider).reminderShortcuts;

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_scheduledTime != null) ...[
            // 已设置提醒的展示卡片
            Container(
              padding: EdgeInsets.all(24.r),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.15,
                ),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  width: 1.w,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    size: 48.sp,
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    '已设置提醒',
                    style: TextStyle(
                      color: colorScheme.secondary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    DateFormat('MMM d, y • h:mm a').format(_scheduledTime!),
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'SF Pro Display',
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 修改时间按钮
                      TextButton.icon(
                        onPressed: _pickCustomTime,
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 18.sp,
                          color: colorScheme.primary,
                        ),
                        label: Text(
                          '修改',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                          backgroundColor: colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // 删除提醒按钮
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _scheduledTime = null;
                          });
                        },
                        icon: Icon(
                          Icons.close,
                          size: 18.sp,
                          color: colorScheme.error,
                        ),
                        label: Text(
                          '删除',
                          style: TextStyle(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                          backgroundColor: colorScheme.error.withValues(
                            alpha: 0.1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            // 未设置提醒时的选项
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '设置提醒',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (shortcuts.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      // 简单的清除所有快捷方式逻辑，或者弹窗管理
                      // 这里为了简化，长按快捷方式删除，或者在设置里管理
                      // 暂时不提供一键清除，避免误触
                    },
                    child: Text(
                      '长按删除快捷方式',
                      style: TextStyle(
                        color: colorScheme.secondary.withValues(alpha: 0.5),
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 24.h),
            // 快速选项网格
            LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 12.w,
                  runSpacing: 12.h,
                  children: [
                    // 稍后 (固定)
                    _buildQuickOption(
                      colorScheme,
                      icon: Icons.wb_twilight,
                      label: '稍后',
                      timeLabel: _formatTime(
                        DateTime.now().add(const Duration(hours: 3)),
                      ),
                      onTap: () {
                        setState(() {
                          _scheduledTime = DateTime.now().add(
                            const Duration(hours: 3),
                          );
                        });
                      },
                      width: (constraints.maxWidth - 12.w) / 2,
                    ),
                    // 动态快捷方式
                    ...shortcuts.asMap().entries.map((entry) {
                      final index = entry.key;
                      final shortcut = entry.value;
                      final name = shortcut['name'] ?? '未命名';
                      final timeStr = shortcut['time'] ?? '09:00';

                      return GestureDetector(
                        onLongPress: () async {
                          // 长按删除
                          await ref
                              .read(appConfigProvider.notifier)
                              .removeReminderShortcut(index);
                          setState(() {}); // 刷新界面
                        },
                        child: _buildQuickOption(
                          colorScheme,
                          icon: Icons.alarm,
                          label: name,
                          timeLabel: timeStr,
                          onTap: () {
                            final now = DateTime.now();
                            final timeParts = timeStr.split(':');
                            final hour = int.parse(timeParts[0]);
                            final minute = int.parse(timeParts[1]);
                            // 如果时间已过，设为明天，否则设为今天
                            var scheduled = DateTime(
                              now.year,
                              now.month,
                              now.day,
                              hour,
                              minute,
                            );
                            if (scheduled.isBefore(now)) {
                              scheduled = scheduled.add(
                                const Duration(days: 1),
                              );
                            }
                            setState(() {
                              _scheduledTime = scheduled;
                            });
                          },
                          width: (constraints.maxWidth - 12.w) / 2,
                        ),
                      );
                    }),
                    // 自定义时间 (固定)
                    _buildQuickOption(
                      colorScheme,
                      icon: Icons.calendar_month_outlined,
                      label: '自定义时间',
                      timeLabel: '选择...',
                      onTap: _pickCustomTime,
                      width: (constraints.maxWidth - 12.w) / 2,
                      isPrimary: true,
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  Widget _buildQuickOption(
    ColorScheme colorScheme, {
    required IconData icon,
    required String label,
    required String timeLabel,
    required VoidCallback onTap,
    required double width,
    bool isPrimary = false,
  }) {
    final bgColor = isPrimary
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.1);
    final fgColor = isPrimary
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;
    final iconColor = isPrimary ? colorScheme.onPrimary : colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          width: width,
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16.r),
            border: isPrimary
                ? null
                : Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.1),
                    width: 1.w,
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 24.sp),
              SizedBox(height: 12.h),
              Text(
                label,
                style: TextStyle(
                  color: fgColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                timeLabel,
                style: TextStyle(
                  color: fgColor.withValues(alpha: 0.7),
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickCustomTime() async {
    final now = DateTime.now();
    final initialTime = _scheduledTime ?? now;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreativeTimePicker(
          initialTime: initialTime,
          onTimeSelected: (selectedTime, name) async {
            setState(() {
              _scheduledTime = selectedTime;
            });
            Navigator.pop(context);

            if (name != null && name.isNotEmpty) {
              final timeStr = DateFormat('HH:mm').format(selectedTime);
              await ref
                  .read(appConfigProvider.notifier)
                  .addReminderShortcut(name, timeStr);
              if (mounted) setState(() {});
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: topPadding, // 从系统状态栏下方开始
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 浮动透明导航栏
          Positioned(top: 0, left: 0, right: 0, child: _buildTopNavBar()),

          // 背景容器（从导航栏下方开始）
          Positioned(
            top: 72.h, // 导航栏高度
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 当前标签页内容区域
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottomInset, top: 8.h),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        layoutBuilder:
                            (
                              Widget? currentChild,
                              List<Widget> previousChildren,
                            ) {
                              return Stack(
                                alignment: Alignment.topCenter,
                                children: <Widget>[
                                  ...previousChildren,
                                  if (currentChild != null) currentChild,
                                ],
                              );
                            },
                        child: Container(
                          key: ValueKey(_currentTab),
                          child:
                              _currentTab == EditTab.content ||
                                  _currentTab == EditTab.title ||
                                  _currentTab == EditTab.ai
                              ? _buildNotesContent(colorScheme)
                              : SingleChildScrollView(
                                  child: _currentTab == EditTab.tags
                                      ? _buildTagsContent(colorScheme)
                                      : _currentTab == EditTab.reminder
                                      ? _buildReminderContent(colorScheme)
                                      : _buildCategoryContent(colorScheme),
                                ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // Done 按钮
                  ElevatedButton(
                    onPressed: _onDone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.tertiary,
                      foregroundColor: colorScheme.onTertiary,
                      padding: EdgeInsets.symmetric(
                        horizontal: 64.w,
                        vertical: 16.h,
                      ),
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 17.sp,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  SizedBox(height: bottomPadding > 0 ? bottomPadding : 40.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
