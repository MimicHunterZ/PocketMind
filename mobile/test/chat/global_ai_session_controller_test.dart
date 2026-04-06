import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketmind/api/chat_api_service.dart';
import 'package:pocketmind/api/models/chat_models.dart';
import 'package:pocketmind/data/repositories/isar_chat_message_repository.dart';
import 'package:pocketmind/data/repositories/isar_chat_session_repository.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/model/chat_session.dart';
import 'package:pocketmind/providers/chat_providers.dart';
import 'package:pocketmind/service/chat_service.dart';

class _StubSessionRepo implements IsarChatSessionRepository {
  _StubSessionRepo({List<ChatSession>? initial}) {
    if (initial != null) {
      _sessions = [...initial]..sort(_sortByUpdatedAtDesc);
    }
  }

  List<ChatSession> _sessions = <ChatSession>[];

  @override
  Future<List<ChatSession>> findGlobalSessions() async => List<ChatSession>.from(_sessions);

  @override
  Future<ChatSession?> findByUuid(String uuid) async {
    for (final session in _sessions) {
      if (session.uuid == uuid) {
        return session;
      }
    }
    return null;
  }

  @override
  Future<void> upsertFromModels(List<ChatSessionModel> models) async {
    for (final model in models) {
      final existingIndex = _sessions.indexWhere((e) => e.uuid == model.uuid);
      final next = _session(model.uuid, updatedAt: model.updatedAt, title: model.title);
      if (existingIndex >= 0) {
        _sessions[existingIndex] = next;
      } else {
        _sessions.add(next);
      }
    }
    _sessions.sort(_sortByUpdatedAtDesc);
  }

  @override
  Future<void> softDelete(String uuid) async {
    _sessions = _sessions.where((e) => e.uuid != uuid).toList();
  }

  static int _sortByUpdatedAtDesc(ChatSession a, ChatSession b) {
    return b.updatedAt.compareTo(a.updatedAt);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubMessageRepo implements IsarChatMessageRepository {
  final Map<String, List<ChatMessage>> bySession = <String, List<ChatMessage>>{};

  @override
  Stream<List<ChatMessage>> watchBySessionUuid(String sessionUuid) async* {
    yield List<ChatMessage>.from(bySession[sessionUuid] ?? const <ChatMessage>[]);
  }

  @override
  Future<List<ChatMessage>> findBySessionUuid(String sessionUuid) async {
    return List<ChatMessage>.from(bySession[sessionUuid] ?? const <ChatMessage>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubChatService implements ChatService {
  int syncSessionsCalls = 0;
  int syncGlobalSessionsCalls = 0;
  int syncGlobalSessionsAttempts = 0;
  int createSessionCalls = 0;
  int deleteSessionCalls = 0;
  final List<String> syncMessagesCalls = <String>[];
  final List<String> syncSessionMessagesIfNeededCalls = <String>[];
  final List<String> callTrace = <String>[];
  bool failSyncMessages = false;
  bool failSyncSessionMessagesIfNeeded = false;
  bool failSyncGlobalSessions = false;
  Completer<void>? syncSessionMessagesIfNeededCompleter;
  final Queue<ChatSession> sessionsToCreate = Queue<ChatSession>();

  @override
  Future<void> syncSessions({String? noteUuid}) async {
    syncSessionsCalls += 1;
    callTrace.add('syncSessions');
  }

  @override
  Future<void> syncGlobalSessions() async {
    syncGlobalSessionsAttempts += 1;
    if (failSyncGlobalSessions) {
      throw Exception('sync global failed');
    }
    syncGlobalSessionsCalls += 1;
    callTrace.add('syncGlobalSessions');
  }

  @override
  Future<void> syncMessages(String sessionUuid, {String? leafUuid}) async {
    syncMessagesCalls.add(sessionUuid);
    callTrace.add('syncMessages:$sessionUuid');
    if (failSyncMessages) {
      throw Exception('sync failed');
    }
  }

  @override
  Future<void> syncSessionMessagesIfNeeded(
    String sessionUuid, {
    bool force = false,
    Set<String>? syncedSessionUuids,
  }) async {
    syncSessionMessagesIfNeededCalls.add(sessionUuid);
    callTrace.add('syncSessionMessagesIfNeeded:$sessionUuid');
    if (syncSessionMessagesIfNeededCompleter != null) {
      await syncSessionMessagesIfNeededCompleter!.future;
    }
    if (failSyncSessionMessagesIfNeeded) {
      throw Exception('sync current failed');
    }
    syncedSessionUuids?.add(sessionUuid);
  }

  @override
  Future<ChatSession> createSession({String? noteUuid, String? title}) async {
    createSessionCalls += 1;
    callTrace.add('createSession');
    if (sessionsToCreate.isNotEmpty) {
      return sessionsToCreate.removeFirst();
    }
    return _session('created-$createSessionCalls', updatedAt: 100 + createSessionCalls);
  }

  @override
  Future<void> deleteSession(String uuid) async {
    deleteSessionCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubChatApiService implements ChatApiService {
  final Queue<List<ChatSessionModel>> pagedResponses = Queue<List<ChatSessionModel>>();
  final List<Map<String, int>> listSessionsCalls = <Map<String, int>>[];
  Object? listSessionsError;

  @override
  Future<List<ChatSessionModel>> listSessions({
    String? noteUuid,
    int page = 0,
    int size = 50,
  }) async {
    listSessionsCalls.add(<String, int>{'page': page, 'size': size});
    if (listSessionsError != null) {
      throw listSessionsError!;
    }
    if (pagedResponses.isNotEmpty) {
      return pagedResponses.removeFirst();
    }
    return const <ChatSessionModel>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ChatSession _session(String uuid, {required int updatedAt, String? title}) {
  return ChatSession()
    ..uuid = uuid
    ..updatedAt = updatedAt
    ..title = title;
}

ChatSessionModel _sessionModel(String uuid, {required int updatedAt, String? title}) {
  return ChatSessionModel(uuid: uuid, updatedAt: updatedAt, title: title);
}

ChatMessage _userMessage(String uuid, String sessionUuid) {
  return ChatMessage()
    ..uuid = uuid
    ..sessionUuid = sessionUuid
    ..role = 'USER'
    ..content = 'hello'
    ..updatedAt = 1;
}

ProviderContainer _container({
  required _StubSessionRepo sessionRepo,
  required _StubMessageRepo messageRepo,
  required _StubChatService chatService,
  required _StubChatApiService apiService,
}) {
  return ProviderContainer(
    overrides: [
      chatSessionRepositoryProvider.overrideWithValue(sessionRepo),
      chatMessageRepositoryProvider.overrideWithValue(messageRepo),
      chatServiceProvider.overrideWithValue(chatService),
      chatApiServiceProvider.overrideWithValue(apiService),
    ],
  );
}

void main() {
  test('ensureActiveSession local-hit priority', () async {
    final sessionRepo = _StubSessionRepo(
      initial: [_session('local-1', updatedAt: 20), _session('local-2', updatedAt: 10)],
    );
    final messageRepo = _StubMessageRepo();
    final chatService = _StubChatService();
    final apiService = _StubChatApiService();
    final container = _container(
      sessionRepo: sessionRepo,
      messageRepo: messageRepo,
      chatService: chatService,
      apiService: apiService,
    );
    addTearDown(container.dispose);

    final notifier = container.read(globalAiSessionControllerProvider.notifier);
    await notifier.ensureActiveSession();

    final state = container.read(globalAiSessionControllerProvider);
    expect(state.currentSessionUuid, 'local-1');
    expect(state.sessions.map((e) => e.uuid), <String>['local-1', 'local-2']);
    expect(chatService.createSessionCalls, 0);
  });

  test('empty-session anti-dup reuse path', () async {
    final empty = _session('empty-local', updatedAt: 30);
    final sessionRepo = _StubSessionRepo(initial: [empty]);
    final messageRepo = _StubMessageRepo()..bySession[empty.uuid] = <ChatMessage>[];
    final chatService = _StubChatService();
    final apiService = _StubChatApiService();
    final container = _container(
      sessionRepo: sessionRepo,
      messageRepo: messageRepo,
      chatService: chatService,
      apiService: apiService,
    );
    addTearDown(container.dispose);

    final notifier = container.read(globalAiSessionControllerProvider.notifier);
    await notifier.loadLocalSessions();
    await notifier.markSessionSynced(empty.uuid);
    await notifier.createOrReuseEmptySession();

    final state = container.read(globalAiSessionControllerProvider);
    expect(state.currentSessionUuid, empty.uuid);
    expect(chatService.createSessionCalls, 0);
  });

  test('empty-session anti-dup uncertain -> remote fallback -> re-sync before create', () async {
    final uncertain = _session('uncertain-1', updatedAt: 50);
    final sessionRepo = _StubSessionRepo(initial: [uncertain]);
    final messageRepo = _StubMessageRepo()..bySession[uncertain.uuid] = <ChatMessage>[];
    final chatService = _StubChatService();
    final apiService = _StubChatApiService();
    final container = _container(
      sessionRepo: sessionRepo,
      messageRepo: messageRepo,
      chatService: chatService,
      apiService: apiService,
    );
    addTearDown(container.dispose);

    final notifier = container.read(globalAiSessionControllerProvider.notifier);
    await notifier.loadLocalSessions();
    await notifier.createOrReuseEmptySession();

    final state = container.read(globalAiSessionControllerProvider);
    expect(chatService.syncMessagesCalls, <String>[uncertain.uuid]);
    expect(state.currentSessionUuid, uncertain.uuid);
    expect(chatService.createSessionCalls, 0);
    expect(state.syncedSessionUuids.contains(uncertain.uuid), isTrue);
  });

  test('remote fallback failure downgrade path', () async {
    final uncertain = _session('uncertain-fail', updatedAt: 60);
    final sessionRepo = _StubSessionRepo(initial: [uncertain]);
    final messageRepo = _StubMessageRepo()..bySession[uncertain.uuid] = <ChatMessage>[];
    final chatService = _StubChatService()..failSyncMessages = true;
    final apiService = _StubChatApiService();
    final container = _container(
      sessionRepo: sessionRepo,
      messageRepo: messageRepo,
      chatService: chatService,
      apiService: apiService,
    );
    addTearDown(container.dispose);

    final notifier = container.read(globalAiSessionControllerProvider.notifier);
    await notifier.loadLocalSessions();
    await notifier.createOrReuseEmptySession();

    final state = container.read(globalAiSessionControllerProvider);
    expect(state.currentSessionUuid, uncertain.uuid);
    expect(chatService.createSessionCalls, 0);
    expect(state.errorMessage, isNotNull);
  });

  test('delete current session auto-fallback or auto-create', () async {
    final first = _session('first', updatedAt: 100);
    final second = _session('second', updatedAt: 90);
    final sessionRepo = _StubSessionRepo(initial: [first, second]);
    final messageRepo = _StubMessageRepo();
    final chatService = _StubChatService()
      ..sessionsToCreate.add(_session('newly-created', updatedAt: 1));
    final apiService = _StubChatApiService();
    final container = _container(
      sessionRepo: sessionRepo,
      messageRepo: messageRepo,
      chatService: chatService,
      apiService: apiService,
    );
    addTearDown(container.dispose);
    final notifier = container.read(globalAiSessionControllerProvider.notifier);

    await notifier.ensureActiveSession();
    await notifier.deleteSession(first.uuid);
    var state = container.read(globalAiSessionControllerProvider);
    expect(state.currentSessionUuid, second.uuid);

    await notifier.deleteSession(second.uuid);
    state = container.read(globalAiSessionControllerProvider);
    expect(state.currentSessionUuid, 'newly-created');
    expect(chatService.createSessionCalls, 1);
  });

  test('draft isolation by session', () async {
    final sessionRepo = _StubSessionRepo(
      initial: [_session('a', updatedAt: 2), _session('b', updatedAt: 1)],
    );
    final messageRepo = _StubMessageRepo();
    final chatService = _StubChatService();
    final apiService = _StubChatApiService();
    final container = _container(
      sessionRepo: sessionRepo,
      messageRepo: messageRepo,
      chatService: chatService,
      apiService: apiService,
    );
    addTearDown(container.dispose);
    final notifier = container.read(globalAiSessionControllerProvider.notifier);

    await notifier.updateDraft('a', 'draft-a');
    await notifier.updateDraft('b', 'draft-b');

    expect(notifier.readDraft('a'), 'draft-a');
    expect(notifier.readDraft('b'), 'draft-b');
  });

  test('loadMoreSessionsInDrawer initial and incremental pagination stable + dedupe', () async {
    final sessionRepo = _StubSessionRepo();
    final messageRepo = _StubMessageRepo();
    final chatService = _StubChatService();
    final apiService = _StubChatApiService()
      ..pagedResponses.add([
        _sessionModel('s1', updatedAt: 100),
        _sessionModel('s2', updatedAt: 90),
      ])
      ..pagedResponses.add([
        _sessionModel('s2', updatedAt: 90),
        _sessionModel('s3', updatedAt: 80),
      ]);
    final container = _container(
      sessionRepo: sessionRepo,
      messageRepo: messageRepo,
      chatService: chatService,
      apiService: apiService,
    );
    addTearDown(container.dispose);
    final notifier = container.read(globalAiSessionControllerProvider.notifier);

    await notifier.loadMoreSessionsInDrawer(pageSize: 2);
    await notifier.loadMoreSessionsInDrawer(pageSize: 2);

    final state = container.read(globalAiSessionControllerProvider);
    expect(state.sessionUuidsVisibleInDrawer, <String>['s1', 's2', 's3']);
    expect(apiService.listSessionsCalls, <Map<String, int>>[
      <String, int>{'page': 0, 'size': 2},
      <String, int>{'page': 1, 'size': 2},
    ]);
  });

  test('loadMoreSessionsInDrawer 在 hasMore=false 时 no-op 守卫生效', () async {
    final sessionRepo = _StubSessionRepo();
    final messageRepo = _StubMessageRepo();
    final chatService = _StubChatService();
    final apiService = _StubChatApiService()
      ..pagedResponses.add([
        _sessionModel('only-1', updatedAt: 100),
      ]);
    final container = _container(
      sessionRepo: sessionRepo,
      messageRepo: messageRepo,
      chatService: chatService,
      apiService: apiService,
    );
    addTearDown(container.dispose);
    final notifier = container.read(globalAiSessionControllerProvider.notifier);

    await notifier.loadMoreSessionsInDrawer(pageSize: 2);
    await notifier.loadMoreSessionsInDrawer(pageSize: 2);

    final state = container.read(globalAiSessionControllerProvider);
    expect(state.hasMoreInDrawer, isFalse);
    expect(state.sessionUuidsVisibleInDrawer, <String>['only-1']);
    expect(apiService.listSessionsCalls, <Map<String, int>>[
      <String, int>{'page': 0, 'size': 2},
    ]);
  });

  test('uncertain session not reusable -> re-sync before create -> create session', () async {
    final uncertain = _session('uncertain-not-empty', updatedAt: 50);
    final sessionRepo = _StubSessionRepo(initial: [uncertain]);
    final messageRepo = _StubMessageRepo()
      ..bySession[uncertain.uuid] = <ChatMessage>[
        _userMessage('m1', uncertain.uuid),
      ];
    final chatService = _StubChatService()
      ..sessionsToCreate.add(_session('created-after-resync', updatedAt: 60));
    final apiService = _StubChatApiService();
    final container = _container(
      sessionRepo: sessionRepo,
      messageRepo: messageRepo,
      chatService: chatService,
      apiService: apiService,
    );
    addTearDown(container.dispose);

    final notifier = container.read(globalAiSessionControllerProvider.notifier);
    await notifier.loadLocalSessions();
    await notifier.createOrReuseEmptySession();

    final state = container.read(globalAiSessionControllerProvider);
    expect(chatService.syncMessagesCalls, <String>[uncertain.uuid]);
    expect(chatService.syncSessionsCalls, 1);
    expect(chatService.createSessionCalls, 1);
    expect(
      chatService.callTrace,
      containsAllInOrder(<String>[
        'syncMessages:${uncertain.uuid}',
        'syncSessions',
        'createSession',
      ]),
    );
    expect(state.currentSessionUuid, 'created-after-resync');
  });

  test('在线初始化时 current session 同步完成前禁发', () async {
    final current = _session('current-online', updatedAt: 20);
    final sessionRepo = _StubSessionRepo(initial: [current]);
    final messageRepo = _StubMessageRepo();
    final chatService = _StubChatService()
      ..syncSessionMessagesIfNeededCompleter = Completer<void>();
    final apiService = _StubChatApiService();
    final container = _container(
      sessionRepo: sessionRepo,
      messageRepo: messageRepo,
      chatService: chatService,
      apiService: apiService,
    );
    addTearDown(container.dispose);
    final sub = container.listen(
      globalAiSessionControllerProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    final notifier = container.read(globalAiSessionControllerProvider.notifier);
    await notifier.ensureActiveSession();

    final syncingFuture = notifier.onConnectivityChanged(true);
    await Future<void>.delayed(Duration.zero);

    var state = container.read(globalAiSessionControllerProvider);
    expect(state.currentSessionUuid, current.uuid);
    expect(state.canSendCurrentSession, isFalse);
    expect(state.isSyncingCurrentSession, isTrue);

    chatService.syncSessionMessagesIfNeededCompleter!.complete();
    await syncingFuture;

    state = container.read(globalAiSessionControllerProvider);
    expect(state.canSendCurrentSession, isTrue);
    expect(state.isSyncingCurrentSession, isFalse);
    expect(state.currentSessionSyncError, isNull);
  });

  test('当前会话首轮同步失败后保持禁发并可重试成功解锁发送', () async {
    final current = _session('current-retry', updatedAt: 30);
    final sessionRepo = _StubSessionRepo(initial: [current]);
    final messageRepo = _StubMessageRepo();
    final chatService = _StubChatService()
      ..failSyncSessionMessagesIfNeeded = true;
    final apiService = _StubChatApiService();
    final container = _container(
      sessionRepo: sessionRepo,
      messageRepo: messageRepo,
      chatService: chatService,
      apiService: apiService,
    );
    addTearDown(container.dispose);
    final sub = container.listen(
      globalAiSessionControllerProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    final notifier = container.read(globalAiSessionControllerProvider.notifier);
    await notifier.ensureActiveSession();
    await notifier.onConnectivityChanged(true);

    var state = container.read(globalAiSessionControllerProvider);
    expect(state.canSendCurrentSession, isFalse);
    expect(state.currentSessionSyncError, isNotNull);

    chatService.failSyncSessionMessagesIfNeeded = false;
    await notifier.retryCurrentSessionSync();

    state = container.read(globalAiSessionControllerProvider);
    expect(state.canSendCurrentSession, isTrue);
    expect(state.currentSessionSyncError, isNull);
  });

  test('打开切换抽屉时在线主动拉取第一页会话', () async {
    final sessionRepo = _StubSessionRepo(
      initial: [_session('local-only', updatedAt: 10)],
    );
    final messageRepo = _StubMessageRepo();
    final chatService = _StubChatService();
    final apiService = _StubChatApiService()
      ..pagedResponses.add([
        _sessionModel('remote-1', updatedAt: 200),
        _sessionModel('remote-2', updatedAt: 100),
      ]);
    final container = _container(
      sessionRepo: sessionRepo,
      messageRepo: messageRepo,
      chatService: chatService,
      apiService: apiService,
    );
    addTearDown(container.dispose);

    final notifier = container.read(globalAiSessionControllerProvider.notifier);
    await notifier.loadLocalSessions();
    await notifier.onConnectivityChanged(true);

    await notifier.refreshDrawerSessionsOnOpen(pageSize: 2);

    final state = container.read(globalAiSessionControllerProvider);
    expect(chatService.syncGlobalSessionsCalls, 1);
    expect(apiService.listSessionsCalls, <Map<String, int>>[
      <String, int>{'page': 0, 'size': 2},
    ]);
    expect(state.sessions.map((e) => e.uuid), containsAll(<String>['remote-1', 'remote-2']));
    expect(state.sessionUuidsVisibleInDrawer, containsAll(<String>['remote-1', 'remote-2']));
    expect(state.drawerNextPage, 1);
  });

  test('refreshDrawerSessionsOnOpen 远端同步失败时降级到本地并继续首屏分页', () async {
    final sessionRepo = _StubSessionRepo(
      initial: [_session('local-fallback', updatedAt: 88)],
    );
    final messageRepo = _StubMessageRepo();
    final chatService = _StubChatService()..failSyncGlobalSessions = true;
    final apiService = _StubChatApiService()
      ..pagedResponses.add([
        _sessionModel('remote-after-fallback', updatedAt: 188),
      ]);
    final container = _container(
      sessionRepo: sessionRepo,
      messageRepo: messageRepo,
      chatService: chatService,
      apiService: apiService,
    );
    addTearDown(container.dispose);

    final notifier = container.read(globalAiSessionControllerProvider.notifier);
    await notifier.loadLocalSessions();
    await notifier.onConnectivityChanged(true);
    await notifier.refreshDrawerSessionsOnOpen(pageSize: 2);

    final state = container.read(globalAiSessionControllerProvider);
    expect(chatService.syncGlobalSessionsAttempts, 1);
    expect(chatService.syncGlobalSessionsCalls, 0);
    expect(apiService.listSessionsCalls, <Map<String, int>>[
      <String, int>{'page': 0, 'size': 2},
    ]);
    expect(state.sessions.map((e) => e.uuid), contains('local-fallback'));
    expect(state.sessions.map((e) => e.uuid), contains('remote-after-fallback'));
    expect(
      state.sessionUuidsVisibleInDrawer,
      <String>['remote-after-fallback'],
    );
    expect(state.errorMessage, isNull);
  });
}
