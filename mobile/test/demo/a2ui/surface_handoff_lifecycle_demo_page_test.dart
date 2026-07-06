import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/demo/a2ui/surface_handoff_lifecycle_demo_page.dart';

void main() {
  testWidgets(
    'live SurfaceController hands off to a persisted SurfaceController '
    'without flicker or leaking the old controller',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SurfaceHandoffLifecycleDemoPage()),
      );

      expect(find.text('状态: 流式中'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 三条流式消息按 300ms 间隔逐条推送。
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      // 流式态应该已经能看到最终文本(三条消息都到齐了)。
      expect(find.text('生命周期交接测试'), findsOneWidget);
      expect(find.text('状态: 流式中'), findsOneWidget);

      // 等待触发交接的延时(300ms)。
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      // 交接发生在这次 pump 内的 setState 里:因为新 controller 是用同步的
      // handleMessage 灌入的,不经过 addChunk 的异步解析管线,交接瞬间应该
      // 立刻就能看到同样的文本,不会有一帧空白。
      expect(find.text('生命周期交接测试'), findsOneWidget);
      expect(find.textContaining('已交接'), findsOneWidget);

      // 再 pump 一帧让 addPostFrameCallback 触发流式 controller 的 dispose。
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('流式 controller 已释放: true'), findsOneWidget);

      // dispose 之后再 pump 几次,确认没有任何"used after dispose"之类的异常
      // 从已释放的流式 controller 里冒出来。
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(find.text('生命周期交接测试'), findsOneWidget);
    },
  );
}
