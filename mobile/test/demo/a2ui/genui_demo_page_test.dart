import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/demo/a2ui/genui_demo_hub_page.dart';

void main() {
  testWidgets('GenUI demo hub renders demo entries', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: GenUiDemoHubPage())),
    );

    expect(find.text('A2UI / Markdown Demo'), findsOneWidget);
    expect(find.text('A2UI Stream Demo'), findsOneWidget);
    expect(find.text('Markdown SSE Mock Demo'), findsOneWidget);
  });
}
