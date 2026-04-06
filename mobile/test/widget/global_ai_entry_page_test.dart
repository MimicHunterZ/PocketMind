import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketmind/data/repositories/isar_chat_session_repository.dart';
import 'package:pocketmind/model/chat_session.dart';
import 'package:pocketmind/page/chat/global_ai_entry_page.dart';
import 'package:pocketmind/providers/chat_providers.dart';
import 'package:pocketmind/router/route_paths.dart';
import 'package:pocketmind/service/chat_service.dart';

class _StubSessionRepo implements IsarChatSessionRepository {
  _StubSessionRepo(this.onFindGlobalSessions);

  final Future<List<ChatSession>> Function() onFindGlobalSessions;
  int findGlobalSessionsCalls = 0;

  @override
  Future<List<ChatSession>> findGlobalSessions() {
    findGlobalSessionsCalls += 1;
    return onFindGlobalSessions();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubChatService implements ChatService {
  _StubChatService(this.onCreateSession);

  final Future<ChatSession> Function({String? noteUuid, String? title})
  onCreateSession;
  int createSessionCalls = 0;

  @override
  Future<ChatSession> createSession({String? noteUuid, String? title}) {
    createSessionCalls += 1;
    return onCreateSession(noteUuid: noteUuid, title: title);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ChatSession _session(String uuid) {
  return ChatSession()..uuid = uuid;
}

Widget _buildApp({
  required IsarChatSessionRepository repo,
  required ChatService chatService,
}) {
  final router = GoRouter(
    initialLocation: RoutePaths.globalAi,
    routes: [
      GoRoute(
        path: RoutePaths.globalAi,
        builder: (_, _) => const GlobalAiEntryPage(),
      ),
      GoRoute(
        path: RoutePaths.chat,
        builder: (_, state) {
          final sessionUuid = state.pathParameters['sessionUuid']!;
          return Scaffold(body: Text('chat:$sessionUuid'));
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      chatSessionRepositoryProvider.overrideWithValue(repo),
      chatServiceProvider.overrideWithValue(chatService),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('已有全局会话时重定向到对应聊天页', (tester) async {
    final repo = _StubSessionRepo(() async => [_session('global-1')]);
    final chatService = _StubChatService(
      ({String? noteUuid, String? title}) async => _session('unused'),
    );

    await tester.pumpWidget(_buildApp(repo: repo, chatService: chatService));
    await tester.pumpAndSettle();

    expect(find.text('chat:global-1'), findsOneWidget);
    expect(repo.findGlobalSessionsCalls, 1);
    expect(chatService.createSessionCalls, 0);
  });

  testWidgets('无全局会话时创建后重定向', (tester) async {
    final repo = _StubSessionRepo(() async => <ChatSession>[]);
    final chatService = _StubChatService(
      ({String? noteUuid, String? title}) async => _session('created-1'),
    );

    await tester.pumpWidget(_buildApp(repo: repo, chatService: chatService));
    await tester.pumpAndSettle();

    expect(find.text('chat:created-1'), findsOneWidget);
    expect(repo.findGlobalSessionsCalls, 1);
    expect(chatService.createSessionCalls, 1);
  });

  testWidgets('加载失败显示重试，重试成功后重定向', (tester) async {
    var attempts = 0;
    final repo = _StubSessionRepo(() async {
      attempts += 1;
      if (attempts == 1) {
        throw Exception('network error');
      }
      return [_session('retry-ok')];
    });
    final chatService = _StubChatService(
      ({String? noteUuid, String? title}) async => _session('unused'),
    );

    await tester.pumpWidget(_buildApp(repo: repo, chatService: chatService));
    await tester.pumpAndSettle();

    expect(find.text('加载全局会话失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.text('chat:retry-ok'), findsOneWidget);
    expect(repo.findGlobalSessionsCalls, 2);
    expect(chatService.createSessionCalls, 0);
  });
}
