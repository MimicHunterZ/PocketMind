import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show A2uiMessage;
import 'package:pocketmind/page/chat/widgets/chat_message_widgets.dart';
import 'package:pocketmind/util/a2ui_card_util.dart';
import 'package:pocketmind/util/theme_data.dart';

const String _surfaceId = 'lock-widget-test';
const String _standardCatalogId =
    'https://a2ui.org/specification/v0_9/standard_catalog.json';

List<A2uiMessage> _cardOperations() {
  final raw = [
    {
      'version': 'v0.9',
      'createSurface': {'surfaceId': _surfaceId, 'catalogId': _standardCatalogId},
    },
    {
      'version': 'v0.9',
      'updateComponents': {
        'surfaceId': _surfaceId,
        'components': [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['picker', 'openDocButton', 'submitButton'],
          },
          {
            'id': 'picker',
            'component': 'ChoicePicker',
            'variant': 'mutuallyExclusive',
            'value': {'path': '/choice/topic'},
            'options': [
              {'label': '热修复原理', 'value': '热修复原理'},
              {'label': '自定义 ClassLoader', 'value': '自定义 ClassLoader'},
            ],
          },
          {
            'id': 'openDocButton',
            'component': 'Button',
            'variant': 'secondary',
            'child': 'openDocLabel',
            'action': {
              'functionCall': {
                'call': 'openUrl',
                'args': {'url': 'https://a2ui.org'},
              },
            },
          },
          {'id': 'openDocLabel', 'component': 'Text', 'text': '查看相关文档'},
          {
            'id': 'submitButton',
            'component': 'Button',
            'variant': 'primary',
            'child': 'submitLabel',
            'action': {
              'event': {
                'name': 'submit_choice',
                'context': {
                  'topic': {'path': '/choice/topic'},
                },
              },
            },
          },
          {'id': 'submitLabel', 'component': 'Text', 'text': '提交选择'},
        ],
      },
    },
  ];
  return tryParseA2uiCard(jsonEncode(raw))!;
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
  group('A2uiCardMessage 卡片交互 + 提交锁定', () {
    testWidgets('未锁定:选方向(本地写值)不触发提交;查看文档(functionCall)不触发提交', (
      tester,
    ) async {
      var submittedCount = 0;
      await tester.pumpWidget(
        _wrap(
          A2uiCardMessage(
            operations: _cardOperations(),
            onSubmitted: (_, __) => submittedCount++,
          ),
        ),
      );

      expect(find.byKey(const Key('a2ui-card-lock-barrier')), findsNothing);

      await tester.tap(find.text('热修复原理'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(submittedCount, 0);

      await tester.tap(find.text('查看相关文档'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(submittedCount, 0, reason: 'functionCall 应该本地处理,不往返触发提交');
    });

    testWidgets('未锁定:选方向后点提交(event),触发 onSubmitted 并带上完整 dataModel', (
      tester,
    ) async {
      String? gotSurfaceId;
      Map<String, dynamic>? gotDataModel;
      await tester.pumpWidget(
        _wrap(
          A2uiCardMessage(
            operations: _cardOperations(),
            onSubmitted: (surfaceId, dataModel) {
              gotSurfaceId = surfaceId;
              gotDataModel = dataModel;
            },
          ),
        ),
      );

      await tester.tap(find.text('自定义 ClassLoader'));
      await tester.pump();
      await tester.tap(find.text('提交选择'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(gotSurfaceId, _surfaceId);
      expect(gotDataModel, isNotNull);
      expect(gotDataModel!['choice'], {
        'topic': ['自定义 ClassLoader'],
      });
    });

    testWidgets('已锁定:整体包一层 AbsorbPointer 拦截触摸,并按 lockedDataModel 定格显示', (
      tester,
    ) async {
      var submittedCount = 0;
      await tester.pumpWidget(
        _wrap(
          A2uiCardMessage(
            operations: _cardOperations(),
            lockedDataModel: {
              'choice': {'topic': '热修复原理'},
            },
            onSubmitted: (_, __) => submittedCount++,
          ),
        ),
      );

      expect(find.byKey(const Key('a2ui-card-lock-barrier')), findsOneWidget);

      // AbsorbPointer 拦截了触摸,点提交按钮不应该触发任何提交回调。
      await tester.tap(find.text('提交选择'), warnIfMissed: false);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(submittedCount, 0);
    });
  });
}
