import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/page/chat/widgets/chat_message_widgets.dart';
import 'package:pocketmind/util/theme_data.dart';

ChatMessage _message(String messageType, String content) {
  return ChatMessage()
    ..uuid = 'm-1'
    ..sessionUuid = 's-1'
    ..role = messageType
    ..messageType = messageType
    ..content = content;
}

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
  group('ChatToolCallCard', () {
    testWidgets('TOOL_CALL 折叠态显示"调用了 {工具名}",没有展开箭头', (tester) async {
      final message = _message(
        'TOOL_CALL',
        '{"toolCallId":"call_1","name":"searchMemory","arguments":"{\\"query\\":\\"x\\"}"}',
      );
      await tester.pumpWidget(_wrap(ChatToolCallCard(message: message)));

      expect(find.text('调用了 searchMemory'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsNothing);
    });

    testWidgets('TOOL_RESULT 折叠态显示"{工具名} 已完成",点击展开显示完整结果', (
      tester,
    ) async {
      final message = _message(
        'TOOL_RESULT',
        '{"toolCallId":"call_1","name":"searchMemory","result":"命中 3 条相关记忆"}',
      );
      await tester.pumpWidget(_wrap(ChatToolCallCard(message: message)));

      expect(find.text('searchMemory 已完成'), findsOneWidget);
      expect(find.text('命中 3 条相关记忆'), findsNothing);

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();

      expect(find.text('命中 3 条相关记忆'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
    });

    testWidgets('content 不是合法 JSON 时优雅降级,不崩溃', (tester) async {
      final message = _message('TOOL_RESULT', '不是 JSON 的纯文本');
      await tester.pumpWidget(_wrap(ChatToolCallCard(message: message)));

      expect(tester.takeException(), isNull);
      expect(find.text('工具 已完成'), findsOneWidget);
    });
  });
}
