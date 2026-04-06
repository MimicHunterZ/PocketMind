import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/page/chat/chat_page.dart';
import 'package:pocketmind/page/chat/widgets/global_session_switch_sheet.dart';
import 'package:pocketmind/providers/chat_providers.dart';

typedef GlobalAiChatPageBuilder =
    Widget Function({required String sessionUuid, required Key key});

/// 全局 AI Shell：负责确保并承载当前激活会话。
class GlobalAiChatShell extends ConsumerStatefulWidget {
  const GlobalAiChatShell({super.key, this.chatPageBuilder});

  final GlobalAiChatPageBuilder? chatPageBuilder;

  @override
  ConsumerState<GlobalAiChatShell> createState() => _GlobalAiChatShellState();
}

class _GlobalAiChatShellState extends ConsumerState<GlobalAiChatShell> {
  ProviderSubscription<AsyncValue<bool>>? _onlineSub;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(globalAiSessionControllerProvider.notifier)
          .ensureActiveSession();
    });

    _onlineSub = ref.listenManual<AsyncValue<bool>>(
      chatOnlineStatusProvider,
      (_, next) {
        final online = next.asData?.value;
        if (online == null) {
          return;
        }
        ref
            .read(globalAiSessionControllerProvider.notifier)
            .onConnectivityChanged(online);
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _onlineSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSessionUuid = ref.watch(
      globalAiSessionControllerProvider.select(
        (state) => state.currentSessionUuid,
      ),
    );
    final isEnsuringActiveSession = ref.watch(
      globalAiSessionControllerProvider.select(
        (state) => state.isEnsuringActiveSession,
      ),
    );
    final errorMessage = ref.watch(
      globalAiSessionControllerProvider.select((state) => state.errorMessage),
    );
    final canSendCurrentSession = ref.watch(
      globalAiSessionControllerProvider.select(
        (state) => state.canSendCurrentSession,
      ),
    );
    final isSyncingCurrentSession = ref.watch(
      globalAiSessionControllerProvider.select(
        (state) => state.isSyncingCurrentSession,
      ),
    );
    final currentSessionSyncError = ref.watch(
      globalAiSessionControllerProvider.select(
        (state) => state.currentSessionSyncError,
      ),
    );
    final isOnline = ref.watch(
      globalAiSessionControllerProvider.select((state) => state.isOnline),
    );

    if (currentSessionUuid != null) {
      final stableKey = ValueKey('global-ai-chat-$currentSessionUuid');
      final builder = widget.chatPageBuilder;
      if (builder != null) {
        return builder(sessionUuid: currentSessionUuid, key: stableKey);
      }
      final sendGateHint = _buildSendGateHint(
        isOnline: isOnline,
        isSyncingCurrentSession: isSyncingCurrentSession,
        currentSessionSyncError: currentSessionSyncError,
      );
      return ChatPage(
        key: stableKey,
        sessionUuid: currentSessionUuid,
        canSend: canSendCurrentSession,
        isSyncingBeforeSend: isSyncingCurrentSession,
        sendGateHint: sendGateHint,
        onRetrySendGate: () {
          ref
              .read(globalAiSessionControllerProvider.notifier)
              .retryCurrentSessionSync();
        },
        onCreateSessionTap: _handleCreateSession,
        onSwitchSessionTap: () => _showSessionSwitchSheet(context),
        onDeleteSessionTap: _handleDeleteSession,
      );
    }

    if (errorMessage != null && !isEnsuringActiveSession) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('加载全局会话失败，请稍后重试'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  ref
                      .read(globalAiSessionControllerProvider.notifier)
                      .ensureActiveSession();
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  Future<void> _handleCreateSession() async {
    await ref
        .read(globalAiSessionControllerProvider.notifier)
        .createOrReuseEmptySession();
  }

  Future<void> _handleDeleteSession(String sessionUuid) async {
    final state = ref.read(globalAiSessionControllerProvider);
    if (state.currentSessionUuid == sessionUuid) {
      await ref.read(chatSendProvider(sessionUuid).notifier).stop();
    }
    await ref
        .read(globalAiSessionControllerProvider.notifier)
        .deleteSession(sessionUuid);
  }

  Future<void> _showSessionSwitchSheet(BuildContext outerContext) async {
    final notifier = ref.read(globalAiSessionControllerProvider.notifier);
    final snapshot = ref.read(globalAiSessionControllerProvider);
    if (snapshot.sessions.isEmpty) {
      await notifier.loadLocalSessions();
    }
    await notifier.refreshDrawerSessionsOnOpen();
    await notifier.ensureDrawerVisibleFromSessions();
    if (!outerContext.mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: outerContext,
      isScrollControlled: true,
      backgroundColor: Theme.of(outerContext).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final sheetState = ref.watch(globalAiSessionControllerProvider);
            final uuids = sheetState.sessionUuidsVisibleInDrawer.toSet();
            final sessions =
                sheetState.sessions
                    .where((session) => uuids.contains(session.uuid))
                    .toList()
                  ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            return FutureBuilder<Map<String, ChatMessage>>(
              future: ref
                  .read(chatMessageRepositoryProvider)
                  .findLatestMessageBySessionUuids(sessions.map((e) => e.uuid)),
              builder: (context, snapshot) {
                final latest = snapshot.data ?? const <String, ChatMessage>{};
                return FractionallySizedBox(
                  heightFactor: 0.78,
                  child: GlobalSessionSwitchSheet(
                    sessions: sessions,
                    currentSessionUuid: sheetState.currentSessionUuid,
                    latestMessageBySession: latest,
                    onSessionTap: (sessionUuid) async {
                      await notifier.switchSession(sessionUuid);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                    },
                    onLoadMore: () async {
                      await notifier.loadMoreSessionsInDrawer();
                    },
                    hasMore: sheetState.hasMoreInDrawer,
                    isLoadingMore: sheetState.isLoadingMoreInDrawer,
                    isRefreshing: sheetState.isLoadingMoreInDrawer &&
                        sheetState.sessionUuidsVisibleInDrawer.isEmpty,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String? _buildSendGateHint({
    required bool isOnline,
    required bool isSyncingCurrentSession,
    required String? currentSessionSyncError,
  }) {
    if (!isOnline) {
      return '当前离线，暂不支持发送，请联网后重试';
    }
    if (isSyncingCurrentSession) {
      return '正在同步当前会话，完成后即可发送';
    }
    if (currentSessionSyncError != null && currentSessionSyncError.isNotEmpty) {
      return '当前会话同步失败，请重试后发送';
    }
    return null;
  }
}
