import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketmind/api/chat_api_service.dart';
import 'package:pocketmind/api/models/chat_models.dart';
import 'package:pocketmind/data/repositories/isar_chat_message_repository.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/data/repositories/isar_chat_session_repository.dart';
import 'package:pocketmind/model/chat_session.dart';
import 'package:pocketmind/page/chat/chat_page.dart';
import 'package:pocketmind/page/chat/global_ai_chat_shell.dart';
import 'package:pocketmind/page/chat/widgets/global_session_switch_sheet.dart';
import 'package:pocketmind/providers/chat_providers.dart';
import 'package:pocketmind/service/chat_service.dart';
import 'package:pocketmind/util/theme_data.dart';

class _StubSessionRepo implements IsarChatSessionRepository {
  _StubSessionRepo(this.onFindGlobalSessions);

  final Future<List<ChatSession>> Function() onFindGlobalSessions;
  int findGlobalSessionsCalls = 0;
  final Map<String, ChatSession> _sessionsByUuid = <String, ChatSession>{};

  @override
  Future<List<ChatSession>> findGlobalSessions() {
    findGlobalSessionsCalls += 1;
    return onFindGlobalSessions().then((list) {
      for (final session in list) {
        _sessionsByUuid[session.uuid] = session;
      }
      return list;
    });
  }

  @override
  Future<ChatSession?> findByUuid(String uuid) async {
    if (_sessionsByUuid.containsKey(uuid)) {
      return _sessionsByUuid[uuid];
    }
    final sessions = await onFindGlobalSessions();
    for (final session in sessions) {
      _sessionsByUuid[session.uuid] = session;
    }
    return _sessionsByUuid[uuid];
  }

  @override
  Stream<ChatSession?> watchByUuid(String uuid) async* {
    yield await findByUuid(uuid);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubChatService implements ChatService {
  _StubChatService(this.onCreateSession);

  final Future<ChatSession> Function({String? noteUuid, String? title})
  onCreateSession;
  int createSessionCalls = 0;
  int syncSessionsCalls = 0;
  int syncSessionMessagesIfNeededCalls = 0;
  bool failSyncSessionMessagesIfNeeded = false;
  int syncGlobalSessionsCalls = 0;

  @override
  Future<ChatSession> createSession({String? noteUuid, String? title}) {
    createSessionCalls += 1;
    return onCreateSession(noteUuid: noteUuid, title: title);
  }

  @override
  Future<void> syncSessions({String? noteUuid}) async {
    syncSessionsCalls += 1;
  }

  @override
  Future<void> syncGlobalSessions() async {
    syncGlobalSessionsCalls += 1;
  }

  @override
  Future<void> syncSessionByUuid(String sessionUuid) async {}

  @override
  Future<void> syncMessages(String sessionUuid, {String? leafUuid}) async {}

  @override
  Future<void> syncSessionMessagesIfNeeded(
    String sessionUuid, {
    bool force = false,
    Set<String>? syncedSessionUuids,
  }) async {
    syncSessionMessagesIfNeededCalls += 1;
    if (failSyncSessionMessagesIfNeeded) {
      throw Exception('sync current failed');
    }
    syncedSessionUuids?.add(sessionUuid);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubMessageRepo implements IsarChatMessageRepository {
  _StubMessageRepo(this.latestBySession);

  final Map<String, ChatMessage> latestBySession;

  @override
  Future<Map<String, ChatMessage>> findLatestMessageBySessionUuids(
    Iterable<String> sessionUuids,
  ) async {
    final result = <String, ChatMessage>{};
    for (final uuid in sessionUuids) {
      final message = latestBySession[uuid];
      if (message != null) {
        result[uuid] = message;
      }
    }
    return result;
  }

  @override
  Stream<List<ChatMessage>> watchBySessionUuid(String sessionUuid) async* {
    yield const <ChatMessage>[];
  }

  @override
  Stream<List<ChatMessage>> watchByLeafUuid(
    String sessionUuid,
    String leafUuid,
  ) async* {
    yield const <ChatMessage>[];
  }

  @override
  Future<List<ChatMessage>> findBySessionUuid(String sessionUuid) async {
    return const <ChatMessage>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubChatApiService implements ChatApiService {
  _StubChatApiService(this.onListSessions);

  final Future<List<ChatSessionModel>> Function({
    String? noteUuid,
    int page,
    int size,
  })
  onListSessions;
  int listSessionsCalls = 0;

  @override
  Future<List<ChatSessionModel>> listSessions({
    String? noteUuid,
    int page = 0,
    int size = 50,
  }) {
    listSessionsCalls += 1;
    return onListSessions(noteUuid: noteUuid, page: page, size: size);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TrackingSessionSwitchSheet extends StatelessWidget {
  const _TrackingSessionSwitchSheet({
    required this.sessions,
    required this.currentSessionUuid,
    required this.latestMessageBySession,
    required this.onSessionTap,
    required this.onLoadMore,
    required this.hasMore,
    required this.isLoadingMore,
  });

  final List<ChatSession> sessions;
  final String? currentSessionUuid;
  final Map<String, ChatMessage> latestMessageBySession;
  final Future<void> Function(String sessionUuid) onSessionTap;
  final Future<void> Function() onLoadMore;
  final bool hasMore;
  final bool isLoadingMore;

  @override
  Widget build(BuildContext context) {
    return GlobalSessionSwitchSheet(
      sessions: sessions,
      currentSessionUuid: currentSessionUuid,
      latestMessageBySession: latestMessageBySession,
      onSessionTap: onSessionTap,
      onLoadMore: onLoadMore,
      hasMore: hasMore,
      isLoadingMore: isLoadingMore,
    );
  }
}

ChatSession _session(String uuid) => ChatSession()..uuid = uuid;

Widget _buildShellApp({
  required IsarChatSessionRepository repo,
  required IsarChatMessageRepository messageRepo,
  required ChatService chatService,
  ChatApiService? chatApiService,
  Stream<bool>? onlineStatus,
  bool useShellDefaultChatPage = false,
}) {
  return ProviderScope(
    overrides: [
      chatSessionRepositoryProvider.overrideWithValue(repo),
      chatMessageRepositoryProvider.overrideWithValue(messageRepo),
      chatServiceProvider.overrideWithValue(chatService),
      if (chatApiService != null)
        chatApiServiceProvider.overrideWithValue(chatApiService),
      if (onlineStatus != null)
        chatOnlineStatusProvider.overrideWith((ref) => onlineStatus),
    ],
    child: MaterialApp(
      theme: ThemeData.light().copyWith(
        extensions: const <ThemeExtension<dynamic>>[lightChatBubbleColors],
      ),
      darkTheme: ThemeData.dark().copyWith(
        extensions: const <ThemeExtension<dynamic>>[darkChatBubbleColors],
      ),
      home: useShellDefaultChatPage
          ? const GlobalAiChatShell()
          : GlobalAiChatShell(
              chatPageBuilder: ({required String sessionUuid, required Key key}) {
                return Scaffold(key: key, body: Text('chat:$sessionUuid'));
              },
            ),
    ),
  );
}

void main() {
  testWidgets('进入 shell 会触发 ensure 并展示当前会话聊天页', (tester) async {
    final repo = _StubSessionRepo(() async => [_session('global-1')]);
    final messageRepo = _StubMessageRepo({});
    final chatService = _StubChatService(
      ({String? noteUuid, String? title}) async => _session('unused'),
    );

    await tester.pumpWidget(
      _buildShellApp(
        repo: repo,
        messageRepo: messageRepo,
        chatService: chatService,
        onlineStatus: Stream<bool>.value(true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('chat:global-1'), findsOneWidget);
    expect(repo.findGlobalSessionsCalls, 1);
    expect(chatService.createSessionCalls, 0);

    await tester.pump();
    expect(repo.findGlobalSessionsCalls, 1);
  });

  testWidgets('会话尚未解析时显示 loading 状态', (tester) async {
    final completer = Completer<List<ChatSession>>();
    final repo = _StubSessionRepo(() => completer.future);
    final messageRepo = _StubMessageRepo({});
    final chatService = _StubChatService(
      ({String? noteUuid, String? title}) async => _session('unused'),
    );

    await tester.pumpWidget(
      _buildShellApp(
        repo: repo,
        messageRepo: messageRepo,
        chatService: chatService,
        onlineStatus: Stream<bool>.value(true),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete([_session('late-1')]);
    await tester.pumpAndSettle();
    expect(find.text('chat:late-1'), findsOneWidget);
  });

  testWidgets('本地无会话时会创建并展示新会话', (tester) async {
    final repo = _StubSessionRepo(() async => <ChatSession>[]);
    final messageRepo = _StubMessageRepo({});
    final chatService = _StubChatService(
      ({String? noteUuid, String? title}) async => _session('created-1'),
    );

    await tester.pumpWidget(
      _buildShellApp(
        repo: repo,
        messageRepo: messageRepo,
        chatService: chatService,
        onlineStatus: Stream<bool>.value(true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('chat:created-1'), findsOneWidget);
    expect(chatService.syncSessionsCalls, 1);
    expect(chatService.createSessionCalls, 1);
  });

  testWidgets('初始化失败展示错误并可重试触发重新初始化', (tester) async {
    var attempts = 0;
    final repo = _StubSessionRepo(() async {
      attempts += 1;
      if (attempts == 1) {
        throw Exception('network error');
      }
      return [_session('retry-ok')];
    });
    final messageRepo = _StubMessageRepo({});
    final chatService = _StubChatService(
      ({String? noteUuid, String? title}) async => _session('unused'),
    );

    await tester.pumpWidget(
      _buildShellApp(
        repo: repo,
        messageRepo: messageRepo,
        chatService: chatService,
        onlineStatus: Stream<bool>.value(true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('加载全局会话失败，请稍后重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.text('chat:retry-ok'), findsOneWidget);
    expect(repo.findGlobalSessionsCalls, 2);
  });

  testWidgets('切换会话抽屉按更新时间排序并展示摘要', (tester) async {
    final sessions = <ChatSession>[
      _session('s2')
        ..title = '第二个'
        ..updatedAt = 200,
      _session('s1')
        ..title = '第一个'
        ..updatedAt = 300,
    ];
    final latestBySession = <String, ChatMessage>{
      's1': ChatMessage()
        ..uuid = 'm1'
        ..sessionUuid = 's1'
        ..role = 'ASSISTANT'
        ..content = '第一条会话最后一条消息预览',
      's2': ChatMessage()
        ..uuid = 'm2'
        ..sessionUuid = 's2'
        ..role = 'USER'
        ..content = '第二条会话最后一条消息预览',
    };

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (_, __) => Scaffold(
              body: GlobalSessionSwitchSheet(
                sessions: sessions,
                currentSessionUuid: 's1',
                latestMessageBySession: latestBySession,
                onSessionTap: (_) async {},
                onLoadMore: () async {},
                hasMore: true,
                isLoadingMore: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('第一个'), findsOneWidget);
    expect(find.text('第二个'), findsOneWidget);
    expect(find.text('第一条会话最后一条消息预览'), findsOneWidget);
    expect(find.text('第二条会话最后一条消息预览'), findsOneWidget);

    final firstDy = tester.getTopLeft(find.text('第一个')).dy;
    final secondDy = tester.getTopLeft(find.text('第二个')).dy;
    expect(firstDy, lessThan(secondDy));
  });

  testWidgets('会话菜单包含新旧项且删除取消不触发删除回调', (tester) async {
    String? deletedSessionUuid;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ChatPage(
            sessionUuid: 'session-1',
            onCreateSessionTap: () async {},
            onSwitchSessionTap: () async {},
            onDeleteSessionTap: (sessionUuid) async {
              deletedSessionUuid = sessionUuid;
            },
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        child: ProviderScope(
          overrides: [
            chatSessionRepositoryProvider.overrideWithValue(
              _StubSessionRepo(() async => [_session('session-1')]),
            ),
            chatMessageRepositoryProvider.overrideWithValue(
              _StubMessageRepo({}),
            ),
            chatServiceProvider.overrideWithValue(
              _StubChatService(
                ({String? noteUuid, String? title}) async =>
                    _session('created-1'),
              ),
            ),
            chatOnlineStatusProvider.overrideWith((ref) => Stream<bool>.value(true)),
          ],
          child: MaterialApp.router(
            theme: ThemeData.light().copyWith(
              extensions: const <ThemeExtension<dynamic>>[lightChatBubbleColors],
            ),
            darkTheme: ThemeData.dark().copyWith(
              extensions: const <ThemeExtension<dynamic>>[darkChatBubbleColors],
            ),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('新建会话'), findsOneWidget);
    expect(find.text('切换会话'), findsOneWidget);
    expect(find.text('重命名会话'), findsOneWidget);
    expect(find.text('查看分支'), findsOneWidget);

    await tester.tap(find.text('删除会话'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(deletedSessionUuid, isNull);
    expect(find.byType(ChatPage), findsOneWidget);
  });

  testWidgets('离线状态下显示禁发提示', (tester) async {
    final repo = _StubSessionRepo(() async => [_session('offline-1')]);
    final messageRepo = _StubMessageRepo({});
    final chatService = _StubChatService(
      ({String? noteUuid, String? title}) async => _session('unused'),
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const GlobalAiChatShell(),
        ),
      ],
    );

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        child: ProviderScope(
          overrides: [
            chatSessionRepositoryProvider.overrideWithValue(repo),
            chatMessageRepositoryProvider.overrideWithValue(messageRepo),
            chatServiceProvider.overrideWithValue(chatService),
            chatOnlineStatusProvider.overrideWith((ref) => Stream<bool>.value(false)),
          ],
          child: MaterialApp.router(
            theme: ThemeData.light().copyWith(
              extensions: const <ThemeExtension<dynamic>>[lightChatBubbleColors],
            ),
            darkTheme: ThemeData.dark().copyWith(
              extensions: const <ThemeExtension<dynamic>>[darkChatBubbleColors],
            ),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chat-send-gate-hint')), findsOneWidget);
    expect(find.text('当前离线，暂不支持发送，请联网后重试'), findsOneWidget);
  });

  testWidgets('更多菜单触发切换会话会刷新抽屉并展示远端会话', (tester) async {
    final repo = _StubSessionRepo(
      () async => [
        _session('local-1')
          ..title = '本地会话'
          ..updatedAt = 10,
      ],
    );
    final messageRepo = _StubMessageRepo({});
    final chatService = _StubChatService(
      ({String? noteUuid, String? title}) async => _session('unused'),
    );
    final chatApiService = _StubChatApiService(({
      String? noteUuid,
      int page = 0,
      int size = 50,
    }) async {
      return const <ChatSessionModel>[
        ChatSessionModel(
          uuid: 'remote-1',
          title: '远端会话A',
          updatedAt: 100,
        ),
      ];
    });

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const GlobalAiChatShell(),
        ),
      ],
    );

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        child: ProviderScope(
          overrides: [
            chatSessionRepositoryProvider.overrideWithValue(repo),
            chatMessageRepositoryProvider.overrideWithValue(messageRepo),
            chatServiceProvider.overrideWithValue(chatService),
            chatApiServiceProvider.overrideWithValue(chatApiService),
            chatOnlineStatusProvider.overrideWith((ref) => Stream<bool>.value(true)),
          ],
          child: MaterialApp.router(
            theme: ThemeData.light().copyWith(
              extensions: const <ThemeExtension<dynamic>>[lightChatBubbleColors],
            ),
            darkTheme: ThemeData.dark().copyWith(
              extensions: const <ThemeExtension<dynamic>>[darkChatBubbleColors],
            ),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('切换会话'));
    await tester.pumpAndSettle();

    expect(chatService.syncGlobalSessionsCalls, 1);
    expect(chatApiService.listSessionsCalls, 1);
    expect(find.text('远端会话A'), findsOneWidget);
  });

  testWidgets('重命名会话弹窗包含 Material 祖先与输入框', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ChatPage(
            sessionUuid: 'session-1',
            onCreateSessionTap: () async {},
            onSwitchSessionTap: () async {},
            onDeleteSessionTap: (_) async {},
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        child: ProviderScope(
          overrides: [
            chatSessionRepositoryProvider.overrideWithValue(
              _StubSessionRepo(() async => [_session('session-1')]),
            ),
            chatMessageRepositoryProvider.overrideWithValue(_StubMessageRepo({})),
            chatServiceProvider.overrideWithValue(
              _StubChatService(
                ({String? noteUuid, String? title}) async => _session('created-1'),
              ),
            ),
            chatOnlineStatusProvider.overrideWith((ref) => Stream<bool>.value(true)),
          ],
          child: MaterialApp.router(
            theme: calmBeigeTheme,
            darkTheme: quietNightTheme,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名会话'));
    await tester.pumpAndSettle();

    expect(find.text('输入新标题'), findsOneWidget);
    expect(find.byType(Material), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
