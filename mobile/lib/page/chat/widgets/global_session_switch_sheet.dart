import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/model/chat_session.dart';
import 'package:pocketmind/page/chat/widgets/chat_common_widgets.dart';

typedef GlobalSessionLoadMore = Future<void> Function();
typedef GlobalSessionTap = Future<void> Function(String sessionUuid);

/// 全局会话切换抽屉。
class GlobalSessionSwitchSheet extends StatelessWidget {
  const GlobalSessionSwitchSheet({
    super.key,
    required this.sessions,
    required this.currentSessionUuid,
    required this.latestMessageBySession,
    required this.onSessionTap,
    required this.onLoadMore,
    required this.hasMore,
    required this.isLoadingMore,
    this.isRefreshing = false,
  });

  final List<ChatSession> sessions;
  final String? currentSessionUuid;
  final Map<String, ChatMessage> latestMessageBySession;
  final GlobalSessionTap onSessionTap;
  final GlobalSessionLoadMore onLoadMore;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final sorted = [...sessions]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ChatBottomSheetHandle(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
            child: Row(
              children: [
                Text('切换会话', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          Flexible(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (!hasMore || isLoadingMore) {
                  return false;
                }
                if (notification is! ScrollUpdateNotification) {
                  return false;
                }
                if (notification.scrollDelta == null ||
                    notification.scrollDelta! <= 0) {
                  return false;
                }
                final metrics = notification.metrics;
                if (metrics.pixels >= metrics.maxScrollExtent - 80) {
                  onLoadMore();
                }
                return false;
              },
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: sorted.length + 1,
                separatorBuilder: (_, _) => Divider(height: 1.h),
                itemBuilder: (context, index) {
                  if (index == sorted.length) {
                    if (isRefreshing) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (isLoadingMore) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (!hasMore) {
                      return SizedBox(height: 8.h);
                    }
                    return SizedBox(height: 28.h);
                  }

                  final session = sorted[index];
                  final isCurrent = session.uuid == currentSessionUuid;
                  final title = session.title?.trim();
                  final displayTitle = (title == null || title.isEmpty)
                      ? 'AI 对话'
                      : title;
                  final preview =
                      latestMessageBySession[session.uuid]?.content ?? '';
                  final previewText = preview.replaceAll('\n', ' ').trim();

                  return ListTile(
                    onTap: () => onSessionTap(session.uuid),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 2.h,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayTitle,
                            key: ValueKey('session-title-${session.uuid}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          _formatTime(session.updatedAt),
                          key: ValueKey('session-time-${session.uuid}'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      previewText,
                      key: ValueKey('session-preview-${session.uuid}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: isCurrent
                        ? Icon(
                            Icons.check_circle,
                            size: 18.sp,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int timestampMs) {
    final time = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final now = DateTime.now();
    if (time.year != now.year) {
      return DateFormat('yyyy/M/d').format(time);
    }
    final diff = now.difference(time);
    if (diff.inDays >= 1) {
      return DateFormat('M/d').format(time);
    }
    return DateFormat('HH:mm').format(time);
  }
}
