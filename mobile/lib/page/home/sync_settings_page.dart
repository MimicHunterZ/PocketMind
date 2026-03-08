import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../providers/sync_providers.dart';
import '../../sync/sync_state_provider.dart';
import '../../util/theme_data.dart';
import '../widget/pm_app_bar.dart';

/// 云同步状态页面
class SyncSettingsPage extends ConsumerWidget {
  const SyncSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const PMAppBar(title: Text('云端同步')),
      body: ListView(
        padding: EdgeInsets.all(16.r),
        children: [
          const _SyncStatusCard(),
          SizedBox(height: 16.h),
          const _SyncActionCard(),
        ],
      ),
    );
  }
}

class _SyncStatusCard extends ConsumerWidget {
  const _SyncStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncStateProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final status = _SyncStatusPresentation.fromState(
      state: state,
      colorScheme: colorScheme,
    );

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(status.icon, color: status.color, size: 24.r),
                SizedBox(width: 8.w),
                Text('同步状态', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            SizedBox(height: 12.h),
            Text(status.text, style: TextStyle(color: status.color)),
            if (state.pendingCount > 0) ...[
              SizedBox(height: 4.h),
              Text(
                '${state.pendingCount} 条变更等待同步',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (state.hasFailed) ...[
              SizedBox(height: 4.h),
              Text(
                '${state.failedCount} 条变更同步失败',
                style: TextStyle(color: appColors.errorText, fontSize: 12.sp),
              ),
            ],
            if (state.isSyncing) ...[
              SizedBox(height: 12.h),
              LinearProgressIndicator(
                backgroundColor: colorScheme.surfaceContainerLow,
                valueColor: AlwaysStoppedAnimation<Color>(status.color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncActionCard extends ConsumerWidget {
  const _SyncActionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncing = ref.watch(syncIsSyncingProvider);
    final syncEngine = ref.read(syncEngineProvider);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('操作', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isSyncing ? null : syncEngine.kick,
                icon: const Icon(Icons.sync),
                label: Text(isSyncing ? '同步中...' : '立即同步'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncStatusPresentation {
  const _SyncStatusPresentation({
    required this.text,
    required this.color,
    required this.icon,
  });

  final String text;
  final Color color;
  final IconData icon;

  factory _SyncStatusPresentation.fromState({
    required SyncState state,
    required ColorScheme colorScheme,
  }) {
    switch (state.phase) {
      case SyncPhase.idle:
        return _SyncStatusPresentation(
          text: state.lastSyncedAt != null
              ? '上次同步: ${_formatTime(state.lastSyncedAt!)}'
              : '尚未同步',
          color: colorScheme.tertiary,
          icon: Icons.cloud_done_outlined,
        );
      case SyncPhase.initialPull:
        return _SyncStatusPresentation(
          text: '首次全量同步中，请稍候...',
          color: colorScheme.primary,
          icon: Icons.cloud_download_outlined,
        );
      case SyncPhase.pulling:
        return _SyncStatusPresentation(
          text: '拉取云端数据...',
          color: colorScheme.primary,
          icon: Icons.cloud_download_outlined,
        );
      case SyncPhase.pushing:
        return _SyncStatusPresentation(
          text: '推送本地变更... (${state.pendingCount} 条)',
          color: colorScheme.secondary,
          icon: Icons.cloud_upload_outlined,
        );
      case SyncPhase.error:
        return _SyncStatusPresentation(
          text: '同步出错，将自动重试',
          color: colorScheme.error,
          icon: Icons.cloud_off_outlined,
        );
    }
  }
}

String _formatTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
}
