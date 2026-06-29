import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/demo/a2ui/genui_demo_hub_page.dart';
import 'package:pocketmind/demo/a2ui/genui_demo_page.dart';

void main() {
  testWidgets('GenUI demo hub renders demo entries', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: GenUiDemoHubPage())),
    );

    expect(find.text('A2UI / Markdown Demo'), findsOneWidget);
    expect(find.text('A2UI Stream Demo'), findsOneWidget);
    expect(find.text('Markdown SSE Mock Demo'), findsOneWidget);
  });

  testWidgets('A2UI stream demo renders local mock and action logs', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: GenUiDemoPage())),
    );

    await tester.tap(find.text('开始流式'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));

    expect(find.text('UI 展示'), findsOneWidget);
    expect(find.text('日志'), findsOneWidget);
    expect(find.text('周末读书会方案'), findsWidgets);
    expect(find.text('继续细化'), findsOneWidget);
    expect(find.text('确认方案'), findsOneWidget);

    final continueButton = find.ancestor(
      of: find.text('继续细化'),
      matching: find.byType(ElevatedButton),
    );
    await tester.ensureVisible(continueButton);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(continueButton);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('已继续细化'), findsWidgets);

    final approveButton = find.ancestor(
      of: find.text('确认方案'),
      matching: find.byType(ElevatedButton),
    );
    await tester.tap(approveButton);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('方案已确认'), findsWidgets);
  });
}
