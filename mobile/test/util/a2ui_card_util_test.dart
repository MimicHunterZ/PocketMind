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
          "catalogId": "https://a2ui.org/specification/v0_9/standard_catalog.json"
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
          "catalogId":"https://a2ui.org/specification/v0_9/standard_catalog.json"}},
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
          "catalogId":"https://a2ui.org/specification/v0_9/standard_catalog.json"}},
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
  });
}
