import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show Surface;
import 'package:go_router/go_router.dart';
import 'package:pocketmind/data/repositories/isar_chat_message_repository.dart';
import 'package:pocketmind/data/repositories/isar_chat_session_repository.dart';
import 'package:pocketmind/demo/a2ui/chat_block_sequence_preview_page.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/model/chat_session.dart';
import 'package:pocketmind/page/chat/widgets/chat_message_widgets.dart';
import 'package:pocketmind/providers/chat_providers.dart';
import 'package:pocketmind/service/chat_service.dart';
import 'package:pocketmind/util/theme_data.dart';

/// 模拟真实 App 根 [ProviderScope] 里的"真实"实现——故意跟预览页想要的
/// mock 数据不一样(会话查不到、消息列表为空),这样才能验证预览页自己的
/// [ProviderScope] 覆盖是否真的生效,而不是不小心用到了外层这份。
class _RootSessionRepo implements IsarChatSessionRepository {
  @override
  Future<ChatSession?> findByUuid(String uuid) async => null;

  @override
  Stream<ChatSession?> watchByUuid(String uuid) async* {
    yield null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RootMessageRepo implements IsarChatMessageRepository {
  @override
  Stream<List<ChatMessage>> watchBySessionUuid(String sessionUuid) async* {
    yield const [];
  }

  @override
  Stream<List<ChatMessage>> watchByLeafUuid(
    String sessionUuid,
    String leafUuid,
  ) async* {
    yield const [];
  }

  @override
  Future<List<ChatMessage>> findBySessionUuid(String sessionUuid) async =>
      const [];

  @override
  Future<ChatMessage?> findByUuid(String uuid) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 记录是否被真的调用过——如果预览页的 provider 覆盖"漏"到了外层,
/// [initSession] 会调用到这个假实现,断言就能抓到。
class _RootChatService implements ChatService {
  bool syncCalled = false;

  @override
  Future<void> syncSessionByUuid(String sessionUuid) async {
    syncCalled = true;
  }

  @override
  Future<void> syncMessages(String sessionUuid, {String? leafUuid}) async {
    syncCalled = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _settle(WidgetTester tester, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets(
    '预览页嵌在真实根 ProviderScope 之下时,渲染的仍是自己的 mock 消息,'
    '不会漏到外层的"真实"实现',
    (tester) async {
      final rootChatService = _RootChatService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatSessionRepositoryProvider.overrideWithValue(
              _RootSessionRepo(),
            ),
            chatMessageRepositoryProvider.overrideWithValue(
              _RootMessageRepo(),
            ),
            chatServiceProvider.overrideWithValue(rootChatService),
          ],
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (_, __) => MaterialApp.router(
              theme: ThemeData(
                extensions: const <ThemeExtension<dynamic>>[
                  lightChatBubbleColors,
                ],
              ),
              routerConfig: GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, __) => const ChatBlockSequencePreviewPage(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);

      // 消息区不是空的——本地分页初始窗口(最新 10 条)里应该能看到 mock
      // 数据的 A2UI 卡片和工具卡片,证明读到的是预览页自己覆盖的假数据,
      // 不是外层根 scope 的"真实"空仓库。用 skipOffstage: false——只关心
      // 有没有构建进树,不关心当前滚动位置下谁刚好在可视区域内。
      expect(find.byType(A2uiCardMessage, skipOffstage: false), findsWidgets);
      expect(find.byType(Surface, skipOffstage: false), findsWidgets);
      expect(find.byType(ChatToolCallCard, skipOffstage: false), findsWidgets);

      // initSession() 里对 chatServiceProvider 的调用也应该落在预览页自己
      // 覆盖的假 ChatService 上,不应该碰到外层这份(否则会真的发起网络请求)。
      expect(rootChatService.syncCalled, isFalse);
    },
  );
}
