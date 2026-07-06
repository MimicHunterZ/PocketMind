import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show Surface;
import 'package:go_router/go_router.dart';
import 'package:pocketmind/data/repositories/isar_chat_message_repository.dart';
import 'package:pocketmind/data/repositories/isar_chat_session_repository.dart';
import 'package:pocketmind/demo/a2ui/chat_block_sequence_mock.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/model/chat_session.dart';
import 'package:pocketmind/page/chat/chat_page.dart';
import 'package:pocketmind/page/chat/widgets/chat_message_widgets.dart';
import 'package:pocketmind/providers/chat_providers.dart';
import 'package:pocketmind/service/chat_service.dart';
import 'package:pocketmind/util/theme_data.dart';

/// 验证块序列(文本 + 工具卡片 + A2UI 卡片)在真实 [ChatPage] 里混排渲染、
/// 滚动、消息增删都不崩溃。只接手写 mock 消息,不接后端、不接流式。
class _StubSessionRepo implements IsarChatSessionRepository {
  _StubSessionRepo(this.session);

  final ChatSession session;

  @override
  Future<ChatSession?> findByUuid(String uuid) async {
    if (uuid == session.uuid) return session;
    return null;
  }

  @override
  Stream<ChatSession?> watchByUuid(String uuid) async* {
    yield await findByUuid(uuid);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 可变的消息仓库 stub:支持测试中途 [update] 模拟消息增删,驱动
/// [chatMessagesProvider] 重新 emit,验证列表增删不崩溃。
class _MutableMessageRepo implements IsarChatMessageRepository {
  _MutableMessageRepo(List<ChatMessage> initial) : _current = initial;

  List<ChatMessage> _current;
  final _controller = StreamController<List<ChatMessage>>.broadcast();

  void update(List<ChatMessage> messages) {
    _current = messages;
    _controller.add(messages);
  }

  @override
  Stream<List<ChatMessage>> watchBySessionUuid(String sessionUuid) async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Stream<List<ChatMessage>> watchByLeafUuid(
    String sessionUuid,
    String leafUuid,
  ) async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<List<ChatMessage>> findBySessionUuid(String sessionUuid) async =>
      _current;

  @override
  Future<ChatMessage?> findByUuid(String uuid) async {
    for (final message in _current) {
      if (message.uuid == uuid) return message;
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

/// ASSISTANT 气泡用的 `StreamingTextMarkdown.chatGPT` 内部有一个默认开启、
/// 且未对外暴露开关的光标闪烁动画,只要有 ASSISTANT 消息挂载就会一直
/// repeat 下去,导致 [WidgetTester.pumpAndSettle] 永远等不到"不再有动画在
/// 跑"而超时。这里改用固定帧数的 pump 循环,只等布局/滚动落定,不等这个
/// 无限循环的动画收敛。
Future<void> _settle(WidgetTester tester, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('块序列混排:文本 + 工具卡片 + 多张 A2UI 卡片同屏渲染不崩溃', (
    tester,
  ) async {
    const sessionUuid = 's-1';
    final session = ChatSession()
      ..uuid = sessionUuid
      ..title = '测试会话';
    final messageRepo = _MutableMessageRepo(
      buildChatBlockSequenceMockMessages(sessionUuid),
    );

    await tester.pumpWidget(
      _buildChatPageApp(
        sessionUuid: sessionUuid,
        sessionRepo: _StubSessionRepo(session),
        messageRepo: messageRepo,
        chatService: _StubChatService(),
      ),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);

    // 本地分页初始窗口是最新 10 条,恰好覆盖最近一轮对话:2 张 A2UI 卡片 +
    // 1 组工具调用/结果(更早的历史文本被本地分页排除在首屏之外)。这里用
    // skipOffstage: false——只关心"这些行有没有被构建进树",不关心此刻
    // 具体滚动到哪个位置、谁正好在可视区域内(卡片内容变高之后,初始窗口
    // 未必所有行都在首屏可视范围内,但都应该被构建)。
    expect(
      find.byType(A2uiCardMessage, skipOffstage: false),
      findsNWidgets(2),
    );
    expect(find.byType(Surface, skipOffstage: false), findsNWidgets(2));
    expect(
      find.byType(ChatToolCallCard, skipOffstage: false),
      findsNWidgets(2),
    );

    // 上滑到顶部,触发本地分页加载更早的历史消息;卡片在列表最下方,滚到
    // 顶部后应该滚出视口,ListView.builder 应该正常 dispose 掉这些行(不是
    // 仅仅滚出屏幕外、Element 还留着),所以这里反而要用默认的
    // skipOffstage: true 之外再叠加一次不带 skipOffstage 的检查:两次都
    // 找不到才能证明是真的 dispose 了,不是碰巧还在树里但不可见。单次
    // drag 可能只把卡片推进 ListView 的 cacheExtent 缓冲区(还没真的
    // dispose),多拖几次确保真正滚出缓冲区。
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, 5000));
      await _settle(tester);
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(A2uiCardMessage), findsNothing);
    expect(find.byType(A2uiCardMessage, skipOffstage: false), findsNothing);

    // 再滚回卡片可见,验证虚拟化重新 mount 这些行时不崩溃、状态正确重建。
    // 用 uuid 派生的 Key 定位单个卡片——`dragUntilVisible` 收尾要对 finder
    // 取唯一 element,byType 在两张卡片同时进入视口时会因命中数 >1 报错。
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('a2ui-card-m-06')),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.byType(A2uiCardMessage, skipOffstage: false),
      findsNWidgets(2),
    );
    expect(find.byType(Surface, skipOffstage: false), findsNWidgets(2));
    expect(
      find.byType(ChatToolCallCard, skipOffstage: false),
      findsNWidgets(2),
    );

    // 模拟消息删除:去掉 A2UI 卡片一,列表应正常收缩、不崩溃。
    final withoutCardA = buildChatBlockSequenceMockMessages(sessionUuid)
        .where((m) => m.uuid != 'm-06')
        .toList();
    messageRepo.update(withoutCardA);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(
      find.byType(A2uiCardMessage, skipOffstage: false),
      findsNWidgets(1),
    );
    expect(find.byType(Surface, skipOffstage: false), findsNWidgets(1));
  });
}
