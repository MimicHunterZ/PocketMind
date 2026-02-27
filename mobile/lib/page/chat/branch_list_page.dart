import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pocketmind/api/models/chat_models.dart';
import 'package:pocketmind/page/widget/pm_app_bar.dart';
import 'package:pocketmind/providers/chat_providers.dart';

/// 分支列表页。
///
/// 展示当前会话所有分支的摘要卡片，支持点击切换进入分支浏览模式。
class BranchListPage extends ConsumerWidget {
  final String sessionUuid;

  const BranchListPage({super.key, required this.sessionUuid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(chatBranchesProvider(sessionUuid));
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: PMAppBar(title: Text(
          '会话分支',
          style: textTheme.titleMedium?.copyWith(color: cs.onSurface),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
      )),
      body: branchesAsync.when(
        data: (branches) {
          if (branches.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    size: 48.sp,
                    color: cs.tertiary.withValues(alpha: 0.4),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    '暂无分支',
                    style: textTheme.bodyLarge?.copyWith(color: cs.onSurface),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '在对话中点击气泡底部的分支图标创建分支',
                    style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            itemCount: branches.length,
            separatorBuilder: (_, _) => SizedBox(height: 10.h),
            itemBuilder: (context, index) => _BranchCard(
              branch: branches[index],
              sessionUuid: sessionUuid,
              onTap: () {
                // 切换会话的激活叶子节点，然后返回聊天页
                ref
                    .read(chatServiceProvider)
                    .updateActiveLeaf(sessionUuid, branches[index].leafUuid);
                // 弹回到聊天页
                context.pop();
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 36.sp,
                color: cs.error.withValues(alpha: 0.6),
              ),
              SizedBox(height: 8.h),
              Text('加载失败，请重试', style: TextStyle(color: cs.error)),
              SizedBox(height: 8.h),
              TextButton(
                onPressed: () =>
                    ref.invalidate(chatBranchesProvider(sessionUuid)),
                child: const Text('重新加载'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 分支摘要卡片

class _BranchCard extends ConsumerWidget {
  final ChatBranchSummaryModel branch;
  final String sessionUuid;
  final VoidCallback onTap;

  const _BranchCard({
    required this.branch,
    required this.sessionUuid,
    required this.onTap,
  });

  /// 弹出别名编辑对话框。
  void _showEditAliasDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: branch.branchAlias ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑分支标签'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 10,
          decoration: const InputDecoration(hintText: '最多 10 个字符'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final alias = controller.text.trim();
              Navigator.pop(ctx);
              if (alias.isEmpty) return;
              await ref
                  .read(chatServiceProvider)
                  .updateBranchAlias(sessionUuid, branch.leafUuid, alias);
              ref.invalidate(chatBranchesProvider(sessionUuid));
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final updatedTime = DateTime.fromMillisecondsSinceEpoch(branch.updatedAt);
    final alias = branch.branchAlias;
    // 展示文本时将换行符替换为空格，避免内嵌换行占用行数
    final userText = branch.lastUserContent.replaceAll('\n', ' ').trim();
    final assistantText = branch.lastAssistantContent
        .replaceAll('\n', ' ')
        .trim();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: cs.outline.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标签行含别名 + 编辑按钮 + 时间
            Row(
              children: [
                if (alias != null) ...[
                  _BranchAliasTag(alias: alias),
                  SizedBox(width: 4.w),
                ] else ...[
                  _BranchAliasTag(alias: '主线', isMain: true),
                  SizedBox(width: 4.w),
                ],
                // 编辑别名按钮（仅分支卡片显示）
                if (alias != null)
                  GestureDetector(
                    onTap: () => _showEditAliasDialog(context, ref),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 14.sp,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                  ),
                const Spacer(),
                Text(
                  _formatTime(updatedTime),
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            // 最后一条用户消息
            if (userText.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 13.sp,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(
                      userText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.sp,
                        height: 1.4,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
            ],
            // 最后一条 AI 消息
            if (assistantText.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 13.sp,
                    color: cs.tertiary.withValues(alpha: 0.7),
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(
                      assistantText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.sp,
                        height: 1.4,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    if (t.year != now.year) {
      return DateFormat('yyyy/M/d').format(t);
    }
    final diff = now.difference(t);
    if (diff.inDays >= 2) {
      return DateFormat('M月d日').format(t);
    }
    if (diff.inDays >= 1) {
      return '昨天';
    }
    return DateFormat('HH:mm').format(t);
  }
}

// 分支别名标签

class _BranchAliasTag extends StatelessWidget {
  final String alias;
  final bool isMain;

  const _BranchAliasTag({required this.alias, this.isMain = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: isMain
            ? cs.surfaceContainerHighest
            : cs.tertiaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        alias,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: isMain ? cs.onSurfaceVariant : cs.onTertiaryContainer,
        ),
      ),
    );
  }
}
