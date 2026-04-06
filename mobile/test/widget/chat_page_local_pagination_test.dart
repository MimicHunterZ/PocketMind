import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketmind/data/repositories/isar_chat_message_repository.dart';
import 'package:pocketmind/data/repositories/isar_chat_session_repository.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/model/chat_session.dart';
import 'package:pocketmind/page/chat/chat_page.dart';
import 'package:pocketmind/page/chat/widgets/chat_message_list.dart';
import 'package:pocketmind/providers/chat_providers.dart';
import 'package:pocketmind/service/chat_service.dart';
import 'package:pocketmind/util/theme_data.dart';

class _StubSessionRepo implements IsarChatSessionRepository {
  _StubSessionRepo(this.session);

  final ChatSession session;

  @override
  Future<ChatSession?> findByUuid(String uuid) async {
    if (uuid == session.uuid) {
      return session;
    }
    return null;
  }

  @override
  Stream<ChatSession?> watchByUuid(String uuid) async* {
    yield await findByUuid(uuid);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubMessageRepo implements IsarChatMessageRepository {
  _StubMessageRepo(this.messagesBySession);

  final Map<String, List<ChatMessage>> messagesBySession;

  @override
  Stream<List<ChatMessage>> watchBySessionUuid(String sessionUuid) async* {
    yield messagesBySession[sessionUuid] ?? const <ChatMessage>[];
  }

  @override
  Stream<List<ChatMessage>> watchByLeafUuid(
    String sessionUuid,
    String leafUuid,
  ) async* {
    yield messagesBySession[sessionUuid] ?? const <ChatMessage>[];
  }

  @override
  Future<List<ChatMessage>> findBySessionUuid(String sessionUuid) async {
    return messagesBySession[sessionUuid] ?? const <ChatMessage>[];
  }

  @override
  Future<ChatMessage?> findByUuid(String uuid) async {
    for (final messages in messagesBySession.values) {
      for (final message in messages) {
        if (message.uuid == uuid) {
          return message;
        }
      }
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubChatService implements ChatService {
  @override
  Future<void> syncSessionByUuid(String sessionUuid) async {}

  @override
  Future<void> syncMessages(String sessionUuid, {String? leafUuid}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ChatMessage _message(String sessionUuid, int index, int updatedAt) {
  final padded = index.toString().padLeft(2, '0');
  return ChatMessage()
    ..uuid = 'm-$padded'
    ..sessionUuid = sessionUuid
    ..role = 'USER'
    ..content = 'msg-$padded'
    ..updatedAt = updatedAt;
}

Widget _buildChatPageApp({
  required String sessionUuid,
  required IsarChatSessionRepository sessionRepo,
  required IsarChatMessageRepository messageRepo,
  required ChatService chatService,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => ChatPage(sessionUuid: sessionUuid),
      ),
    ],
  );

  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => ProviderScope(
      overrides: [
        chatSessionRepositoryProvider.overrideWithValue(sessionRepo),
        chatMessageRepositoryProvider.overrideWithValue(messageRepo),
        chatServiceProvider.overrideWithValue(chatService),
      ],
      child: MaterialApp.router(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A6572)),
          extensions: const <ThemeExtension<dynamic>>[lightChatBubbleColors],
        ),
        routerConfig: router,
      ),
    ),
  );
}

void main() {
  testWidgets('初始仅渲染会话最新 10 条消息', (tester) async {
    const sessionUuid = 's-1';
    final session = ChatSession()
      ..uuid = sessionUuid
      ..title = '测试会话';
    final messages = List<ChatMessage>.generate(
      25,
      (i) => _message(sessionUuid, i + 1, 1000 + i * 1000),
    );

    await tester.pumpWidget(
      _buildChatPageApp(
        sessionUuid: sessionUuid,
        sessionRepo: _StubSessionRepo(session),
        messageRepo: _StubMessageRepo({sessionUuid: messages}),
        chatService: _StubChatService(),
      ),
    );
    await tester.pumpAndSettle();

    final listWidget = tester.widget<ChatMessageList>(
      find.byType(ChatMessageList),
    );
    expect(listWidget.asyncValue.asData?.value.length, 10);
  });

  testWidgets('滚动到顶部会触发本地加载更多消息', (tester) async {
    const sessionUuid = 's-1';
    final session = ChatSession()
      ..uuid = sessionUuid
      ..title = '测试会话';
    final messages = List<ChatMessage>.generate(
      25,
      (i) => _message(sessionUuid, i + 1, 1000 + i * 1000),
    );

    await tester.pumpWidget(
      _buildChatPageApp(
        sessionUuid: sessionUuid,
        sessionRepo: _StubSessionRepo(session),
        messageRepo: _StubMessageRepo({sessionUuid: messages}),
        chatService: _StubChatService(),
      ),
    );
    await tester.pumpAndSettle();

    var listWidget = tester.widget<ChatMessageList>(find.byType(ChatMessageList));
    expect(listWidget.asyncValue.asData?.value.length, 10);

    await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
    await tester.pumpAndSettle();

    listWidget = tester.widget<ChatMessageList>(find.byType(ChatMessageList));
    expect(listWidget.asyncValue.asData?.value.length, 20);
  });
}
