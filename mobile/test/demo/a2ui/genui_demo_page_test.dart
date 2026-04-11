import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/demo/a2ui/genui_demo_page.dart';

void main() {
  testWidgets('GenUI Demo renders and shows start action', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: GenUiDemoPage())),
    );

    expect(find.text('GenUI Demo'), findsOneWidget);
    expect(find.text('开始流式'), findsOneWidget);
    expect(find.text('新会话'), findsOneWidget);
  });
}
