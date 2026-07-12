import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:pocketmind/util/a2ui_card_util.dart';

void main() {
  group('tryParseA2uiCard', () {
    test('单条合法 A2UI createSurface JSON → 解析成功', () {
      const content = '''
      {
        "version": "v0.9",
        "createSurface": {
          "surfaceId": "s1",
          "catalogId": "$basicCatalogId"
        }
      }
      ''';
      final messages = tryParseA2uiCard(content);
      expect(messages, isNotNull);
      expect(messages, hasLength(1));
      expect(messages!.single, isA<CreateSurface>());
    });

    test('createSurface + updateComponents + updateDataModel 数组 → 依序解析成功', () {
      const content = '''
      [
        {"version":"v0.9","createSurface":{"surfaceId":"s1",
          "catalogId":"$basicCatalogId"}},
        {"version":"v0.9","updateComponents":{"surfaceId":"s1",
          "components":[{"id":"root","component":"Column","children":["title"]},
          {"id":"title","component":"Text","text":{"path":"/title"},"variant":"h2"}]}},
        {"version":"v0.9","updateDataModel":{"surfaceId":"s1","path":"/title","value":"hi"}}
      ]
      ''';
      final messages = tryParseA2uiCard(content);
      expect(messages, isNotNull);
      expect(messages, hasLength(3));
      expect(messages![0], isA<CreateSurface>());
      expect(messages[1], isA<UpdateComponents>());
      expect(messages[2], isA<UpdateDataModel>());
      expect(a2uiSurfaceId(messages), 's1');
    });

    test('普通工具结果 JSON(既存后端 TOOL_RESULT 形状)→ 判别为假', () {
      const content =
          '{"toolCallId":"call_1","name":"searchMemory","result":"找到 3 条相关记忆"}';
      expect(tryParseA2uiCard(content), isNull);
    });

    test('普通文本 content → 判别为假', () {
      expect(tryParseA2uiCard('好的,已经帮你处理完成'), isNull);
    });

    test('数组中混入非法元素 → 整体判别为假', () {
      const content = '''
      [
        {"version":"v0.9","createSurface":{"surfaceId":"s1",
          "catalogId":"$basicCatalogId"}},
        {"toolCallId":"call_1","name":"searchMemory","result":"不是 A2UI 消息"}
      ]
      ''';
      expect(tryParseA2uiCard(content), isNull);
    });

    test('空数组 → 判别为假', () {
      expect(tryParseA2uiCard('[]'), isNull);
    });

    test('JSON 但不是对象也不是数组(纯数字)→ 判别为假', () {
      expect(tryParseA2uiCard('42'), isNull);
    });

    test('version 不是 v0.9 → 判别为假', () {
      const content = '''
      {"version": "v1.0", "createSurface": {"surfaceId": "s1"}}
      ''';
      expect(tryParseA2uiCard(content), isNull);
    });

    test('后端工具结果包装内嵌 A2UI 数组(reload 复现形状)→ 剥包装后解析成功', () {
      // PersistingToolCallAdvisor.toToolResultJson 落库形状:
      // {"toolCallId","name","result": "<转义的 A2UI envelope 数组 JSON>"}
      final envelope = jsonEncode([
        {
          'version': 'v0.9',
          'createSurface': {
            'surfaceId': 'choice-card-1',
            'catalogId': basicCatalogId,
          },
        },
        {
          'version': 'v0.9',
          'updateComponents': {
            'surfaceId': 'choice-card-1',
            'components': [
              {
                'id': 'root',
                'component': 'Column',
                'children': ['title'],
              },
              {'id': 'title', 'component': 'Text', 'text': '选一个'},
            ],
          },
        },
      ]);
      final content = jsonEncode({
        'toolCallId': 'call_1',
        'name': 'renderChoiceCard',
        'result': envelope,
      });

      final messages = tryParseA2uiCard(content);
      expect(messages, isNotNull);
      expect(messages, hasLength(2));
      expect(messages![0], isA<CreateSurface>());
      expect(messages[1], isA<UpdateComponents>());
      expect(a2uiSurfaceId(messages), 'choice-card-1');
    });

    test('后端工具结果包装内嵌单条 A2UI 消息 → 剥包装后解析成功', () {
      final envelope = jsonEncode({
        'version': 'v0.9',
        'createSurface': {
          'surfaceId': 's1',
          'catalogId': basicCatalogId,
        },
      });
      final content = jsonEncode({
        'toolCallId': 'call_1',
        'name': 'renderChoiceCard',
        'result': envelope,
      });
      final messages = tryParseA2uiCard(content);
      expect(messages, isNotNull);
      expect(messages!.single, isA<CreateSurface>());
    });

    test('后端工具结果包装但 result 是纯文本(功能型工具)→ 判别为假', () {
      final content = jsonEncode({
        'toolCallId': 'call_1',
        'name': 'searchMemory',
        'result': '找到 3 条相关记忆',
      });
      expect(tryParseA2uiCard(content), isNull);
    });
  });

  group('tryParseA2uiSubmission', () {
    test('合法的提交交互 JSON → 解析出 surfaceId 和 dataModel', () {
      const content =
          '{"surfaceId":"s1","dataModel":{"choice":{"topic":"热修复原理"}}}';
      final submission = tryParseA2uiSubmission(content);
      expect(submission, isNotNull);
      expect(submission!.surfaceId, 's1');
      expect(submission.dataModel, {
        'choice': {'topic': '热修复原理'},
      });
    });

    test('普通文本 content → 判别为假', () {
      expect(tryParseA2uiSubmission('好的,已经帮你处理完成'), isNull);
    });

    test('非法 JSON → 判别为假', () {
      expect(tryParseA2uiSubmission('不是 JSON 的纯文本'), isNull);
    });

    test('缺少 dataModel 字段 → 判别为假', () {
      expect(tryParseA2uiSubmission('{"surfaceId":"s1"}'), isNull);
    });

    test('surfaceId 不是字符串 → 判别为假', () {
      expect(tryParseA2uiSubmission('{"surfaceId":1,"dataModel":{}}'), isNull);
    });

    test('dataModel 不是对象 → 判别为假', () {
      expect(
        tryParseA2uiSubmission('{"surfaceId":"s1","dataModel":"x"}'),
        isNull,
      );
    });
  });
}
