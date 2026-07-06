import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show Surface;
import 'package:pocketmind/page/chat/widgets/chat_message_widgets.dart';
import 'package:pocketmind/providers/chat_providers.dart';
import 'package:pocketmind/util/theme_data.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => MaterialApp(
      theme: ThemeData(
        extensions: const <ThemeExtension<dynamic>>[lightChatBubbleColors],
      ),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('ChatStreamingBubble', () {
    testWidgets('空块列表显示占位省略号', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ChatStreamingBubble(blocks: [], colors: lightChatBubbleColors),
        ),
      );

      expect(find.text('…'), findsOneWidget);
    });

    testWidgets('文本块按累积内容渲染,工具调用块显示调用中/已完成,A2UI 块渲染 Surface', (
      tester,
    ) async {
      const surfaceId = 'live-card';
      final blocks = [
        const ChatLiveBlock.text('好的，我先搜一下'),
        const ChatLiveBlock.toolCall(
          toolCallId: 'call-1',
          toolName: 'searchMemory',
          done: false,
        ),
        ChatLiveBlock.a2ui([
          '{"version":"v0.9","createSurface":{"surfaceId":"$surfaceId",'
              '"catalogId":"https://a2ui.org/specification/v0_9/standard_catalog.json"}}',
        ]),
      ];

      await tester.pumpWidget(
        _wrap(
          ChatStreamingBubble(blocks: blocks, colors: lightChatBubbleColors),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('好的，我先搜一下'), findsOneWidget);
      expect(find.text('正在调用 searchMemory…'), findsOneWidget);
      expect(find.byType(Surface), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('工具调用块 done=true 时显示已完成', (tester) async {
      final blocks = [
        const ChatLiveBlock.toolCall(
          toolCallId: 'call-1',
          toolName: 'searchMemory',
          done: true,
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          ChatStreamingBubble(blocks: blocks, colors: lightChatBubbleColors),
        ),
      );

      expect(find.text('searchMemory 已完成'), findsOneWidget);
      expect(find.text('正在调用 searchMemory…'), findsNothing);
    });
  });
}
