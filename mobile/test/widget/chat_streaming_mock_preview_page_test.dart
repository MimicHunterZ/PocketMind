import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show Surface;
import 'package:go_router/go_router.dart';
import 'package:pocketmind/demo/a2ui/chat_streaming_mock_preview_page.dart';
import 'package:pocketmind/page/chat/chat_page.dart';
import 'package:pocketmind/page/chat/widgets/chat_message_widgets.dart';
import 'package:pocketmind/providers/chat_providers.dart';
import 'package:pocketmind/util/theme_data.dart';

// 必须和 chat_streaming_mock_preview_page.dart 里的私有常量 _previewSessionUuid
// 保持一致——测试拿不到那个私有常量,只能照抄字面值。
const String _previewSessionUuid = 'debug-streaming-block-sequence-preview';

Future<void> _settle(WidgetTester tester, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets(
    '发送消息后流式态块序列依次出现(工具进度+A2UI 卡片),'
    '流式结束后交接为持久化历史,内容与流式时一致',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
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
                    builder: (_, __) => const ChatStreamingMockPreviewPage(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);

      // 输入栏尾部的摄像头/发送/停止图标之间用 AnimatedOpacity 做交叉淡入淡出,
      // 且默认测试画布跟真机比例不一致时二者的命中区域会重叠,点击坐标未必
      // 落在发送按钮上。这里不测"点按钮"这段跟本任务无关的既有交互逻辑,
      // 直接驱动真实发送流程背后的 [ChatSend] notifier,聚焦验证块序列流式
      // 渲染管线本身。
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChatPage)),
      );
      container
          .read(chatSendProvider(_previewSessionUuid).notifier)
          .send('帮我查一下上次讨论的方案');
      await tester.pump();

      // 发送后立刻应该看到待发用户气泡(乐观展示),流式回复尚未开始或刚开始。
      expect(find.text('帮我查一下上次讨论的方案'), findsOneWidget);

      // 逐帧推进,流式剧本按顺序吐出:文本 → 工具调用中/已完成 → 文本 → A2UI 卡片。
      // 用标志位记录整个流式过程中有没有出现过这些过渡态,而不是卡死在某一帧断言,
      // 因为过渡态只在某几帧短暂存在。
      var sawToolCalling = false;
      var sawToolDone = false;
      var sawLiveSurface = false;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 90));
        if (find.text('正在调用 searchMemory…').evaluate().isNotEmpty) {
          sawToolCalling = true;
        }
        if (find.text('searchMemory 已完成').evaluate().isNotEmpty) {
          sawToolDone = true;
        }
        if (find.byType(Surface, skipOffstage: false).evaluate().isNotEmpty) {
          sawLiveSurface = true;
        }
      }
      expect(tester.takeException(), isNull);
      expect(sawToolCalling, isTrue, reason: '流式过程中应该出现过"正在调用"过渡提示');
      expect(sawToolDone, isTrue, reason: '流式过程中应该出现过"已完成"过渡提示');
      expect(sawLiveSurface, isTrue, reason: '流式过程中应该出现过 A2UI 卡片(流式临时的)');

      // 再多推进几帧,确保 ChatDoneEvent 已处理、syncMessages 已把最终消息落库、
      // 状态切回 idle,流式占位气泡消失、变成持久化历史消息。
      await _settle(tester, frames: 10);
      expect(tester.takeException(), isNull);

      expect(find.text('好的，我先搜一下相关记忆。'), findsOneWidget);
      expect(find.text('找到了，给你一张卡片。'), findsOneWidget);
      expect(
        find.byType(ChatToolCallCard, skipOffstage: false),
        findsNWidgets(2),
      );
      expect(
        find.byType(A2uiCardMessage, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byType(Surface, skipOffstage: false), findsOneWidget);
    },
  );
}
