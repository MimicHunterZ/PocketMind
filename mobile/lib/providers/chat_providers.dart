import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketmind/api/chat_api_service.dart';
import 'package:pocketmind/api/models/chat_models.dart';
import 'package:pocketmind/data/repositories/isar_chat_message_repository.dart';
import 'package:pocketmind/data/repositories/isar_chat_session_repository.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/model/chat_session.dart';
import 'package:pocketmind/providers/infrastructure_providers.dart';
import 'package:pocketmind/service/chat_service.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_providers.freezed.dart';
part 'chat_providers.g.dart';

// 数据层 Providers

/// 聊天会话 Isar 仓库 Provider。
@Riverpod(keepAlive: true)
IsarChatSessionRepository chatSessionRepository(Ref ref) {
  return IsarChatSessionRepository(ref.watch(isarProvider));
}

/// 聊天消息 Isar 仓库 Provider。
@Riverpod(keepAlive: true)
IsarChatMessageRepository chatMessageRepository(Ref ref) {
  return IsarChatMessageRepository(ref.watch(isarProvider));
}

// 业务层 Provider

/// 聊天业务 Service Provider（全局单例）。
@Riverpod(keepAlive: true)
ChatService chatService(Ref ref) {
  return ChatService(
    sessionRepo: ref.watch(chatSessionRepositoryProvider),
    messageRepo: ref.watch(chatMessageRepositoryProvider),
    apiService: ref.watch(chatApiServiceProvider),
  );
}

// 流数据 Providers（UI 持久化驱动）

/// 聊天会话列表流。
@riverpod
Stream<List<ChatSession>> chatSessions(Ref ref, String? noteUuid) {
  return ref
      .watch(chatSessionRepositoryProvider)
      .watchSessions(noteUuid: noteUuid);
}

/// 实时监听单个会话（用于 [BranchBanner] 订阅 activeLeafUuid 变化）。
@riverpod
Stream<ChatSession?> chatSessionStream(Ref ref, String sessionUuid) {
  return ref.watch(chatSessionRepositoryProvider).watchByUuid(sessionUuid);
}

/// 指定会话的消息列表流（按时间轴升序）。
///
/// 自动感知会话的 [ChatSession.activeLeafUuid]：
/// - null → 主线（watchBySessionUuid）
/// - 非 null → 分支链路（watchByLeafUuid）
@riverpod
Stream<List<ChatMessage>> chatMessages(Ref ref, String sessionUuid) {
  final sessionAsync = ref.watch(chatSessionStreamProvider(sessionUuid));
  final leafUuid = sessionAsync.asData?.value?.activeLeafUuid;
  final messageRepo = ref.watch(chatMessageRepositoryProvider);

  if (leafUuid != null) {
    return messageRepo.watchByLeafUuid(sessionUuid, leafUuid);
  }
  return messageRepo.watchBySessionUuid(sessionUuid);
}

/// 按 UUID 查找单个会话（一次性 Future，用于取标题）。
@riverpod
Future<ChatSession?> chatSessionByUuid(Ref ref, String uuid) {
  return ref.watch(chatSessionRepositoryProvider).findByUuid(uuid);
}

/// 获取会话所有分支摘要列表（按需拉取，BranchListPage 使用）。
@riverpod
Future<List<ChatBranchSummaryModel>> chatBranches(Ref ref, String sessionUuid) {
  return ref.watch(chatServiceProvider).fetchBranches(sessionUuid);
}

/// 实时监听单条消息（用于分支芯片显示 AI 生成的别名）。
@riverpod
Stream<ChatMessage?> chatMessageByUuid(Ref ref, String uuid) {
  return ref.watch(chatMessageRepositoryProvider).watchByUuid(uuid);
}

@riverpod
Stream<bool> chatOnlineStatus(Ref ref) async* {
  final connectivity = Connectivity();
  final initialResults = await connectivity.checkConnectivity();
  yield initialResults.any((result) => result != ConnectivityResult.none);

  yield* connectivity.onConnectivityChanged
      .map((results) => results.any((result) => result != ConnectivityResult.none))
      .distinct();
}

@freezed
sealed class GlobalAiSessionState with _$GlobalAiSessionState {
  const factory GlobalAiSessionState({
    String? currentSessionUuid,
    @Default(<ChatSession>[]) List<ChatSession> sessions,
    @Default(<String>[]) List<String> sessionUuidsVisibleInDrawer,
    @Default(<String, String>{}) Map<String, String> draftBySession,
    @Default(<String>{}) Set<String> syncedSessionUuids,
    @Default(true) bool isOnline,
    @Default(false) bool isSyncingCurrentSession,
    @Default(false) bool canSendCurrentSession,
    String? currentSessionSyncError,
    @Default(false) bool isEnsuringActiveSession,
    @Default(false) bool isCreatingOrReusingSession,
    @Default(false) bool isLoadingMoreInDrawer,
    @Default(true) bool hasMoreInDrawer,
    @Default(0) int drawerNextPage,
    String? errorMessage,
  }) = _GlobalAiSessionState;
}

@riverpod
class GlobalAiSessionController extends _$GlobalAiSessionController {
  bool _ensuringInFlight = false;
  bool _creatingInFlight = false;
  bool _syncCurrentInFlight = false;

  @override
  GlobalAiSessionState build() => const GlobalAiSessionState();

  Future<void> loadLocalSessions() async {
    final local = await ref
        .read(chatSessionRepositoryProvider)
        .findGlobalSessions();
    state = state.copyWith(
      sessions: local,
      currentSessionUuid: _resolveCurrentSessionUuid(
        local,
        preferred: state.currentSessionUuid,
      ),
    );
  }

  Future<void> ensureActiveSession() async {
    if (_ensuringInFlight) return;
    _ensuringInFlight = true;
    state = state.copyWith(isEnsuringActiveSession: true, errorMessage: null);
    try {
      await loadLocalSessions();
      if (state.currentSessionUuid != null) {
        await _evaluateSendGateForCurrent();
        return;
      }
      await createOrReuseEmptySession();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    } finally {
      state = state.copyWith(isEnsuringActiveSession: false);
      _ensuringInFlight = false;
    }
  }

  Future<void> createOrReuseEmptySession() async {
    if (_creatingInFlight) return;
    _creatingInFlight = true;
    state = state.copyWith(
      isCreatingOrReusingSession: true,
      errorMessage: null,
    );
    try {
      await loadLocalSessions();

      final reused = await _tryReuseEmptyFromCurrentSessions();
      if (reused) {
        return;
      }

      await ref.read(chatServiceProvider).syncSessions(noteUuid: null);
      await loadLocalSessions();

      final reusedAfterResync = await _tryReuseEmptyFromCurrentSessions();
      if (reusedAfterResync) {
        return;
      }

      final created = await ref
          .read(chatServiceProvider)
          .createSession(noteUuid: null);
      final merged = _mergeSessions(state.sessions, [created]);
      state = state.copyWith(
        sessions: merged,
        currentSessionUuid: created.uuid,
      );
      await _evaluateSendGateForCurrent();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    } finally {
      state = state.copyWith(isCreatingOrReusingSession: false);
      _creatingInFlight = false;
    }
  }

  Future<bool> _tryReuseEmptyFromCurrentSessions() async {
    for (final session in state.sessions) {
      final sessionUuid = session.uuid;
      if (state.syncedSessionUuids.contains(sessionUuid)) {
        if (await _isSessionEmpty(sessionUuid)) {
          await switchSession(sessionUuid);
          return true;
        }
        continue;
      }

      try {
        await ref.read(chatServiceProvider).syncMessages(sessionUuid);
        await markSessionSynced(sessionUuid);
        if (await _isSessionEmpty(sessionUuid)) {
          await switchSession(sessionUuid);
          return true;
        }
      } catch (e) {
        state = state.copyWith(
          currentSessionUuid: sessionUuid,
          errorMessage: e.toString(),
        );
        return true;
      }
    }
    return false;
  }

  Future<void> switchSession(String sessionUuid) async {
    state = state.copyWith(
      currentSessionUuid: sessionUuid,
      errorMessage: null,
      currentSessionSyncError: null,
    );
    await _evaluateSendGateForCurrent();
  }

  Future<void> onConnectivityChanged(bool isOnline) async {
    if (state.isOnline == isOnline && state.currentSessionUuid == null) {
      return;
    }

    if (!isOnline) {
      state = state.copyWith(
        isOnline: false,
        canSendCurrentSession: false,
        isSyncingCurrentSession: false,
      );
      return;
    }

    state = state.copyWith(isOnline: true);
    await syncCurrentSessionForSend(force: true);

    final current = state.currentSessionUuid;
    if (current != null) {
      unawaited(_syncOtherSessionsInBackground(excludeSessionUuid: current));
    }
  }

  Future<void> retryCurrentSessionSync() {
    return syncCurrentSessionForSend(force: true);
  }

  Future<void> syncCurrentSessionForSend({bool force = false}) async {
    if (_syncCurrentInFlight) {
      return;
    }

    final current = state.currentSessionUuid;
    if (current == null) {
      return;
    }

    if (!state.isOnline) {
      state = state.copyWith(
        canSendCurrentSession: false,
        isSyncingCurrentSession: false,
      );
      return;
    }

    if (!force && state.syncedSessionUuids.contains(current)) {
      state = state.copyWith(
        canSendCurrentSession: true,
        isSyncingCurrentSession: false,
        currentSessionSyncError: null,
      );
      return;
    }

    _syncCurrentInFlight = true;
    state = state.copyWith(
      canSendCurrentSession: false,
      isSyncingCurrentSession: true,
      currentSessionSyncError: null,
    );

    try {
      final nextSynced = Set<String>.from(state.syncedSessionUuids);
      await ref.read(chatServiceProvider).syncSessionMessagesIfNeeded(
        current,
        force: force,
        syncedSessionUuids: nextSynced,
      );
      state = state.copyWith(
        syncedSessionUuids: nextSynced,
        canSendCurrentSession: true,
        isSyncingCurrentSession: false,
        currentSessionSyncError: null,
      );
    } catch (e) {
      state = state.copyWith(
        canSendCurrentSession: false,
        isSyncingCurrentSession: false,
        currentSessionSyncError: e.toString(),
      );
    } finally {
      _syncCurrentInFlight = false;
    }
  }

  Future<void> deleteSession(String sessionUuid) async {
    try {
      await ref.read(chatServiceProvider).deleteSession(sessionUuid);
      final remained = state.sessions
          .where((session) => session.uuid != sessionUuid)
          .toList();
      final nextDrafts = Map<String, String>.from(state.draftBySession)
        ..remove(sessionUuid);
      final nextSynced = Set<String>.from(state.syncedSessionUuids)
        ..remove(sessionUuid);
      final nextVisible = state.sessionUuidsVisibleInDrawer
          .where((uuid) => uuid != sessionUuid)
          .toList();

      if (state.currentSessionUuid == sessionUuid) {
        if (remained.isNotEmpty) {
          state = state.copyWith(
            sessions: remained,
            currentSessionUuid: remained.first.uuid,
            draftBySession: nextDrafts,
            syncedSessionUuids: nextSynced,
            sessionUuidsVisibleInDrawer: nextVisible,
          );
          await _evaluateSendGateForCurrent();
          return;
        }
        final created = await ref
            .read(chatServiceProvider)
            .createSession(noteUuid: null);
        state = state.copyWith(
          sessions: [created],
          currentSessionUuid: created.uuid,
          draftBySession: nextDrafts,
          syncedSessionUuids: nextSynced,
          sessionUuidsVisibleInDrawer: nextVisible,
        );
        await _evaluateSendGateForCurrent();
        return;
      }

      state = state.copyWith(
        sessions: remained,
        draftBySession: nextDrafts,
        syncedSessionUuids: nextSynced,
        sessionUuidsVisibleInDrawer: nextVisible,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> loadMoreSessionsInDrawer({int pageSize = 50}) async {
    if (state.isLoadingMoreInDrawer || !state.hasMoreInDrawer) {
      return;
    }

    state = state.copyWith(isLoadingMoreInDrawer: true, errorMessage: null);
    try {
      final page = state.drawerNextPage;
      final models = await ref
          .read(chatApiServiceProvider)
          .listSessions(noteUuid: null, page: page, size: pageSize);
      final fetched = models.map(_fromSessionModel).toList();
      final merged = _mergeSessions(state.sessions, fetched);

      final existingVisible = state.sessionUuidsVisibleInDrawer;
      final toAppend = fetched
          .map((session) => session.uuid)
          .where((uuid) => !existingVisible.contains(uuid))
          .toList();

      state = state.copyWith(
        sessions: merged,
        sessionUuidsVisibleInDrawer: [...existingVisible, ...toAppend],
        drawerNextPage: page + 1,
        hasMoreInDrawer: models.length >= pageSize,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    } finally {
      state = state.copyWith(isLoadingMoreInDrawer: false);
    }
  }

  Future<void> updateDraft(String sessionUuid, String draft) async {
    final next = Map<String, String>.from(state.draftBySession);
    if (draft.isEmpty) {
      next.remove(sessionUuid);
    } else {
      next[sessionUuid] = draft;
    }
    state = state.copyWith(draftBySession: next);
  }

  String readDraft(String sessionUuid) {
    return state.draftBySession[sessionUuid] ?? '';
  }

  Future<void> markSessionSynced(String sessionUuid) async {
    final next = Set<String>.from(state.syncedSessionUuids)..add(sessionUuid);
    state = state.copyWith(syncedSessionUuids: next);
  }

  Future<void> ensureDrawerVisibleFromSessions() async {
    if (state.sessionUuidsVisibleInDrawer.isNotEmpty) {
      return;
    }
    final sorted = [...state.sessions]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = state.copyWith(
      sessionUuidsVisibleInDrawer: sorted.map((e) => e.uuid).toList(),
    );
  }

  Future<bool> _isSessionEmpty(String sessionUuid) async {
    final messages = await ref
        .read(chatMessageRepositoryProvider)
        .findBySessionUuid(sessionUuid);
    return messages.isEmpty;
  }

  Future<void> _evaluateSendGateForCurrent() async {
    final current = state.currentSessionUuid;
    if (current == null) {
      state = state.copyWith(
        canSendCurrentSession: false,
        isSyncingCurrentSession: false,
        currentSessionSyncError: null,
      );
      return;
    }

    if (!state.isOnline) {
      state = state.copyWith(
        canSendCurrentSession: false,
        isSyncingCurrentSession: false,
        currentSessionSyncError: null,
      );
      return;
    }

    if (state.syncedSessionUuids.contains(current)) {
      state = state.copyWith(
        canSendCurrentSession: true,
        isSyncingCurrentSession: false,
        currentSessionSyncError: null,
      );
      return;
    }

    unawaited(syncCurrentSessionForSend());
  }

  Future<void> _syncOtherSessionsInBackground({
    required String excludeSessionUuid,
  }) async {
    if (!state.isOnline) {
      return;
    }

    final nextSynced = Set<String>.from(state.syncedSessionUuids);
    bool changed = false;
    for (final session in state.sessions) {
      final sessionUuid = session.uuid;
      if (sessionUuid == excludeSessionUuid || nextSynced.contains(sessionUuid)) {
        continue;
      }
      try {
        await ref.read(chatServiceProvider).syncSessionMessagesIfNeeded(
          sessionUuid,
          syncedSessionUuids: nextSynced,
        );
        changed = true;
      } catch (_) {
        // 后台同步失败不打断当前会话可发状态。
      }
    }

    if (changed) {
      state = state.copyWith(syncedSessionUuids: nextSynced);
    }
  }

  Future<void> refreshDrawerSessionsOnOpen({int pageSize = 50}) async {
    if (state.isLoadingMoreInDrawer) {
      return;
    }

    state = state.copyWith(isLoadingMoreInDrawer: true, errorMessage: null);
    try {
      if (state.isOnline) {
        try {
          await ref.read(chatServiceProvider).syncGlobalSessions();
        } catch (_) {
          // 远端同步失败时继续展示本地会话，避免阻塞抽屉打开。
        }
      }

      await loadLocalSessions();

      final models = await ref
          .read(chatApiServiceProvider)
          .listSessions(noteUuid: null, page: 0, size: pageSize);
      final fetched = models.map(_fromSessionModel).toList();
      final merged = _mergeSessions(state.sessions, fetched);
      final visible = fetched.isNotEmpty
          ? fetched.map((e) => e.uuid).toList()
          : merged.take(pageSize).map((e) => e.uuid).toList();

      state = state.copyWith(
        sessions: merged,
        sessionUuidsVisibleInDrawer: visible,
        drawerNextPage: 1,
        hasMoreInDrawer: models.length >= pageSize,
      );
    } catch (e) {
      final sorted = [...state.sessions]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      state = state.copyWith(
        sessionUuidsVisibleInDrawer: sorted.map((e) => e.uuid).toList(),
        errorMessage: e.toString(),
      );
    } finally {
      state = state.copyWith(isLoadingMoreInDrawer: false);
    }
  }

  String? _resolveCurrentSessionUuid(
    List<ChatSession> sessions, {
    required String? preferred,
  }) {
    if (sessions.isEmpty) {
      return null;
    }
    if (preferred != null &&
        sessions.any((session) => session.uuid == preferred)) {
      return preferred;
    }
    return sessions.first.uuid;
  }

  List<ChatSession> _mergeSessions(
    List<ChatSession> current,
    List<ChatSession> incoming,
  ) {
    final map = <String, ChatSession>{};
    for (final session in current) {
      map[session.uuid] = session;
    }
    for (final session in incoming) {
      map[session.uuid] = session;
    }
    final merged = map.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return merged;
  }

  ChatSession _fromSessionModel(ChatSessionModel model) {
    return ChatSession()
      ..uuid = model.uuid
      ..scopeNoteUuid = model.scopeNoteUuid
      ..title = model.title
      ..updatedAt = model.updatedAt
      ..isDeleted = false;
  }
}

// 发送状态

/// 消息发送状态，描述当前会话的 SSE 流状态。
@freezed
sealed class ChatSendState with _$ChatSendState {
  /// 空闲，无发送中的请求。
  const factory ChatSendState.idle() = ChatSendIdle;

  /// 流式接收中，[content] 为目前已累积的助手回复文本（用于实时预览）。
  const factory ChatSendState.streaming({
    required String content,
    required String pendingUserMessage,
  }) = ChatSendStreaming;

  /// 发生错误。
  const factory ChatSendState.error({required String message}) = ChatSendError;
}

/// 消息发送 Notifier，按 [sessionUuid] 分组（family）。
@riverpod
class ChatSend extends _$ChatSend {
  static const String _tag = 'ChatSend';

  CancelToken? _activeCancelToken;
  String? _activeRequestId;

  @override
  ChatSendState build(String sessionUuid) {
    ref.onDispose(() {
      _activeCancelToken?.cancel('provider disposed');
      _cleanupActiveRequest();
    });
    return const ChatSendState.idle();
  }

  String _newRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final b = bytes;
    String hex(int start, int end) => b
        .sublist(start, end)
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  void _startStreaming({required String pendingUserMessage}) {
    _activeCancelToken?.cancel('replace request');
    _activeCancelToken = CancelToken();
    _activeRequestId = _newRequestId();
    state = ChatSendState.streaming(
      content: '',
      pendingUserMessage: pendingUserMessage,
    );
  }

  bool _matchRequest(String expectedRequestId, String? eventRequestId) {
    if (eventRequestId == null || eventRequestId.isEmpty) {
      return true;
    }
    return eventRequestId == expectedRequestId;
  }

  void _cleanupActiveRequest() {
    _activeCancelToken = null;
    _activeRequestId = null;
  }

  Future<bool> _handleTerminalEvent({
    required ChatService service,
    required String requestId,
    required String? eventRequestId,
    required bool inBranch,
    String? messageUuid,
  }) async {
    if (!_matchRequest(requestId, eventRequestId)) {
      return false;
    }

    if (inBranch && messageUuid != null) {
      await service.syncMessages(sessionUuid, leafUuid: messageUuid);
      await service.updateActiveLeaf(sessionUuid, messageUuid);
    } else {
      await service.syncMessages(sessionUuid);
    }
    state = const ChatSendState.idle();
    return true;
  }

  Future<void> _consumeStreamEvents({
    required Stream<ChatStreamEvent> stream,
    required ChatService service,
    required String requestId,
    required bool inBranch,
    required String pendingUserMessage,
    required String errorLogLabel,
    Future<void> Function()? onDone,
  }) async {
    final buffer = StringBuffer();
    await for (final event in stream) {
      switch (event) {
        case ChatDeltaEvent(:final delta):
          buffer.write(delta);
          state = ChatSendState.streaming(
            content: buffer.toString(),
            pendingUserMessage: pendingUserMessage,
          );
        case ChatDoneEvent(:final messageUuid, requestId: final eventRequestId):
          final handled = await _handleTerminalEvent(
            service: service,
            requestId: requestId,
            eventRequestId: eventRequestId,
            inBranch: inBranch,
            messageUuid: messageUuid,
          );
          if (handled && onDone != null) {
            await onDone();
          }
        case ChatPausedEvent(
          requestId: final eventRequestId,
          messageUuid: final pausedMessageUuid,
        ):
          await _handleTerminalEvent(
            service: service,
            requestId: requestId,
            eventRequestId: eventRequestId,
            inBranch: inBranch,
            messageUuid: pausedMessageUuid,
          );
        case ChatErrorEvent(:final message):
          PMlog.w(_tag, '$errorLogLabel: $message');
          state = ChatSendState.error(message: message);
      }
    }
  }

  Future<void> _runStreamingRequest({
    required ChatService service,
    required String pendingUserMessage,
    required bool inBranch,
    required String errorLogLabel,
    Future<void> Function()? onDone,
    required Stream<ChatStreamEvent> Function(
      String requestId,
      CancelToken? cancelToken,
    )
    streamFactory,
  }) async {
    _startStreaming(pendingUserMessage: pendingUserMessage);
    final requestId = _activeRequestId!;
    final cancelToken = _activeCancelToken;

    try {
      await _consumeStreamEvents(
        stream: streamFactory(requestId, cancelToken),
        service: service,
        requestId: requestId,
        inBranch: inBranch,
        pendingUserMessage: pendingUserMessage,
        errorLogLabel: errorLogLabel,
        onDone: onDone,
      );
    } catch (e) {
      if (cancelToken?.isCancelled == true) {
        if (state is ChatSendStreaming) {
          state = const ChatSendState.idle();
        }
        return;
      }
      PMlog.e(_tag, '$errorLogLabel: $e');
      state = ChatSendState.error(message: e.toString());
    } finally {
      if (_activeRequestId == requestId) {
        _cleanupActiveRequest();
      }
    }
  }

  Future<void> _generateTitleIfNeeded(
    ChatService service,
    String firstPrompt,
  ) async {
    final session = await ref
        .read(chatSessionRepositoryProvider)
        .findByUuid(sessionUuid);
    final currentTitle = session?.title?.trim();
    final shouldGenerate =
        currentTitle == null || currentTitle.isEmpty || currentTitle == '新对话';
    if (!shouldGenerate) {
      return;
    }
    try {
      await service.generateSessionTitle(sessionUuid, firstPrompt);
    } catch (e) {
      PMlog.w(_tag, '生成会话标题失败（忽略）: $e');
    }
  }

  /// 进入聊天页面时调用，从服务端拉取历史消息同步到本地。
  Future<void> initSession() async {
    final service = ref.read(chatServiceProvider);
    try {
      await service.syncSessionByUuid(sessionUuid);
    } catch (e) {
      PMlog.w(_tag, '初始化会话标题失败（使用本地缓存）: $e');
    }

    try {
      final session = await ref
          .read(chatSessionRepositoryProvider)
          .findByUuid(sessionUuid);
      await service.syncMessages(
        sessionUuid,
        leafUuid: session?.activeLeafUuid,
      );
    } catch (e) {
      PMlog.w(_tag, '初始化消息失败（已有本地缓存）: $e');
    }
  }

  /// 发送一条用户消息，驱动 SSE 流式回复。
  ///
  /// [parentUuid] 不为 null 时，从该节点分叉创建新分支。
  /// [showPendingBubble] false 时不显示待发用户气泡（编辑重发时避免重复）。
  Future<void> send(
    String content, {
    List<String> attachmentUuids = const [],
    String? parentUuid,
    bool showPendingBubble = true,
  }) async {
    if (state is ChatSendStreaming) return;
    final service = ref.read(chatServiceProvider);

    // 分支模式：发送前切换视图到分岔点，避免流式期间展示全量消息
    if (parentUuid != null) {
      await service.updateActiveLeaf(sessionUuid, parentUuid);
    }

    await _runStreamingRequest(
      service: service,
      pendingUserMessage: showPendingBubble ? content : '',
      inBranch: parentUuid != null,
      errorLogLabel: '发送消息异常',
      onDone: parentUuid == null
          ? () => _generateTitleIfNeeded(service, content)
          : null,
      streamFactory: (requestId, cancelToken) => service.streamMessage(
        sessionUuid,
        content,
        attachmentUuids: attachmentUuids,
        parentUuid: parentUuid,
        requestId: requestId,
        cancelToken: cancelToken,
      ),
    );
  }

  /// 编辑 USER 消息内容，并对同一 USER 消息重新触发 AI 回复（不创建新 USER 消息）。
  ///
  /// 服务端编辑消息内容并删除旧 ASSISTANT 回复，再对原 userUuid 重新生成，避免重复对话条目。
  Future<void> editAndResend(String messageUuid, String newContent) async {
    if (state is ChatSendStreaming) return;
    final service = ref.read(chatServiceProvider);

    // 编辑前检查分支模式状态，避免编辑和删除 ASSISTANT 后 UI 空预
    final currentSession = await ref
        .read(chatSessionRepositoryProvider)
        .findByUuid(sessionUuid);
    final wasInBranch = currentSession?.activeLeafUuid != null;

    try {
      await service.editMessage(sessionUuid, messageUuid, newContent);
    } catch (e) {
      PMlog.e(_tag, '编辑消息失败: $e');
      state = ChatSendState.error(message: '编辑失败: $e');
      return;
    }

    // 分支模式下，ASSISTANT 已被 editMessage 删除，activeLeafUuid 仍指向旧删除节点
    // 立即切换到 USER 消息节点，避免 watchByLeafUuid 返回空链
    if (wasInBranch) {
      await service.updateActiveLeaf(sessionUuid, messageUuid);
    }

    // 对原 USER 消息直接调用重新生成（后端识别 USER UUID，不再创建新资源）
    await _runStreamingRequest(
      service: service,
      pendingUserMessage: '',
      inBranch: wasInBranch,
      errorLogLabel: '编辑重发异常',
      streamFactory: (requestId, cancelToken) => service.streamRegenerate(
        sessionUuid,
        messageUuid,
        requestId: requestId,
        cancelToken: cancelToken,
      ),
    );
  }

  /// 重新生成指定 ASSISTANT 消息，替换为新的 SSE 流式回复。
  Future<void> regenerate(String assistantMessageUuid) async {
    if (state is ChatSendStreaming) return;

    final messageRepo = ref.read(chatMessageRepositoryProvider);
    // 提前获取父节点 UUID 和当前分支状态，避免删除后无法查询
    final assistantMsg = await messageRepo.findByUuid(assistantMessageUuid);
    final currentSession = await ref
        .read(chatSessionRepositoryProvider)
        .findByUuid(sessionUuid);
    final wasInBranch = currentSession?.activeLeafUuid != null;

    // 若当前处于分支模式，先将视图切换到 USER 父节点，
    // 避免软删除后 watchByLeafUuid 指向已删除的 ASSISTANT 消息导致 UI 空链
    if (wasInBranch && assistantMsg?.parentUuid != null) {
      await ref
          .read(chatServiceProvider)
          .updateActiveLeaf(sessionUuid, assistantMsg!.parentUuid!);
    }

    // 本地立即删除旧 AI 消息，使气泡即刻从 UI 消失
    await messageRepo.softDeleteByUuids([assistantMessageUuid]);

    final service = ref.read(chatServiceProvider);

    await _runStreamingRequest(
      service: service,
      pendingUserMessage: '',
      inBranch: wasInBranch,
      errorLogLabel: '重新生成异常',
      streamFactory: (requestId, cancelToken) => service.streamRegenerate(
        sessionUuid,
        assistantMessageUuid,
        requestId: requestId,
        cancelToken: cancelToken,
      ),
    );
  }

  /// 暂停当前流式回复。
  Future<void> stop() async {
    if (state is! ChatSendStreaming) return;
    final requestId = _activeRequestId;
    if (requestId == null || requestId.isEmpty) {
      state = const ChatSendState.idle();
      _cleanupActiveRequest();
      return;
    }

    await _notifyStop(requestId);

    if (state is ChatSendStreaming) {
      _activeCancelToken?.cancel('user stop fallback');
      state = const ChatSendState.idle();
      _cleanupActiveRequest();
    }
  }

  Future<void> _notifyStop(String requestId) async {
    try {
      await ref.read(chatServiceProvider).stopStream(sessionUuid, requestId);
    } catch (e) {
      PMlog.w(_tag, '通知服务端暂停失败: $e');
    }
  }

  /// 对消息评分。[rating] = 1/0/-1，与当前值相同时切换为 0（取消）。
  Future<void> rateMessage(String messageUuid, int rating) async {
    try {
      await ref
          .read(chatServiceProvider)
          .rateMessage(sessionUuid, messageUuid, rating);
    } catch (e) {
      PMlog.e(_tag, '评分失败: $e');
    }
  }

  /// 清除错误状态，恢复 idle。
  void reset() => state = const ChatSendState.idle();
}
