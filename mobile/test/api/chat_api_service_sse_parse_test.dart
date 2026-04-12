import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/api/chat_api_service.dart';
import 'package:pocketmind/api/http_client.dart';
import 'package:pocketmind/api/models/chat_models.dart';

String _buildDeltaFrame(String chunk) {
  final lines = chunk.split('\n');
  final buffer = StringBuffer('event:delta\n');
  for (final line in lines) {
    buffer.write('data:$line\n');
  }
  buffer.write('\n');
  return buffer.toString();
}

Future<String> _parseDeltaTextFromRaw(
  ChatApiService service,
  String rawSse,
) async {
  final events = await service
      .parseForTest(Stream<List<int>>.fromIterable([utf8.encode(rawSse)]), null)
      .toList();
  return events.whereType<ChatDeltaEvent>().map((e) => e.delta).join();
}

void main() {
  group('ChatApiService SSE parsing', () {
    test('parses multi-line data frame and preserves blank lines', () async {
      final service = ChatApiService(HttpClient());
      final events = await service
          .parseForTest(
            Stream<List<int>>.fromIterable([
              utf8.encode('event: delta\n'),
              utf8.encode('data:line1\n'),
              utf8.encode('data:\n'),
              utf8.encode('data:line2\n\n'),
            ]),
            null,
          )
          .toList();

      expect(events.length, 1);
      expect(events.first, isA<ChatDeltaEvent>());
      final delta = events.first as ChatDeltaEvent;
      expect(delta.delta, 'line1\n\nline2');
    });

    test('parses utf8 split chunks without malformed characters', () async {
      final service = ChatApiService(HttpClient());
      final bytes = utf8.encode('event: delta\ndata:中文测试\n\n');
      final events = await service
          .parseForTest(
            Stream<List<int>>.fromIterable([
              bytes.sublist(0, 19),
              bytes.sublist(19),
            ]),
            null,
          )
          .toList();

      expect(events.length, 1);
      expect(events.first, isA<ChatDeltaEvent>());
      final delta = events.first as ChatDeltaEvent;
      expect(delta.delta, '中文测试');
    });

    test('flushes trailing done event without final separator line', () async {
      final service = ChatApiService(HttpClient());
      final events = await service
          .parseForTest(
            Stream<List<int>>.fromIterable([
              utf8.encode(
                'event: done\ndata: {"messageUuid":"m1","requestId":"r1"}',
              ),
            ]),
            null,
          )
          .toList();

      expect(events.length, 1);
      expect(events.first, isA<ChatDoneEvent>());
      final done = events.first as ChatDoneEvent;
      expect(done.messageUuid, 'm1');
      expect(done.requestId, 'r1');
    });

    test(
      'replay mock response keeps markdown structure and done event',
      () async {
        final service = ChatApiService(HttpClient());
        final responseFile = File('assets/mock/response');
        expect(responseFile.existsSync(), isTrue);

        final content = responseFile.readAsStringSync(encoding: utf8);
        final events = await service
            .parseForTest(
              Stream<List<int>>.fromIterable([utf8.encode(content)]),
              CancelToken(),
            )
            .toList();

        final deltaText = events
            .whereType<ChatDeltaEvent>()
            .map((e) => e.delta)
            .join();
        final doneEvents = events.whereType<ChatDoneEvent>().toList();

        expect(doneEvents.length, 1);
        expect(doneEvents.first.messageUuid, isNotEmpty);
        expect(deltaText.contains('\n\n'), isTrue);
        expect(deltaText.contains('\n\n## 1.'), isTrue);
        expect(deltaText.contains('```markdown'), isTrue);
        expect(deltaText.contains('\n\n### 请求示例'), isTrue);
        expect(deltaText.contains('\n\n## 2.'), isTrue);
      },
    );

    test('preserves heading spacing when ## and title are split', () async {
      final service = ChatApiService(HttpClient());
      final raw = [
        _buildDeltaFrame('##'),
        _buildDeltaFrame(' '),
        _buildDeltaFrame('标题示例'),
        _buildDeltaFrame('\n'),
      ].join();
      final text = await _parseDeltaTextFromRaw(service, raw);
      expect(text, '## 标题示例\n');
    });

    test('preserves fenced code block structure', () async {
      final service = ChatApiService(HttpClient());
      final raw = [
        _buildDeltaFrame('```'),
        _buildDeltaFrame('dart'),
        _buildDeltaFrame('\n'),
        _buildDeltaFrame('print("ok");'),
        _buildDeltaFrame('\n'),
        _buildDeltaFrame('```'),
      ].join();
      final text = await _parseDeltaTextFromRaw(service, raw);
      expect(text, '```dart\nprint("ok");\n```');
    });

    test('preserves unordered list format', () async {
      final service = ChatApiService(HttpClient());
      final raw = [
        _buildDeltaFrame('- '),
        _buildDeltaFrame('项目一'),
        _buildDeltaFrame('\n'),
        _buildDeltaFrame('- '),
        _buildDeltaFrame('项目二'),
      ].join();
      final text = await _parseDeltaTextFromRaw(service, raw);
      expect(text, '- 项目一\n- 项目二');
    });

    test('preserves ordered list format', () async {
      final service = ChatApiService(HttpClient());
      final raw = [
        _buildDeltaFrame('1.'),
        _buildDeltaFrame(' '),
        _buildDeltaFrame('第一项'),
        _buildDeltaFrame('\n'),
        _buildDeltaFrame('2.'),
        _buildDeltaFrame(' '),
        _buildDeltaFrame('第二项'),
      ].join();
      final text = await _parseDeltaTextFromRaw(service, raw);
      expect(text, '1. 第一项\n2. 第二项');
    });

    test('preserves blockquote format', () async {
      final service = ChatApiService(HttpClient());
      final raw = [
        _buildDeltaFrame('>'),
        _buildDeltaFrame(' '),
        _buildDeltaFrame('引用内容'),
      ].join();
      final text = await _parseDeltaTextFromRaw(service, raw);
      expect(text, '> 引用内容');
    });

    test('preserves table format', () async {
      final service = ChatApiService(HttpClient());
      final raw = [
        _buildDeltaFrame('| 列1 | 列2 |'),
        _buildDeltaFrame('\n'),
        _buildDeltaFrame('|---|---|'),
        _buildDeltaFrame('\n'),
        _buildDeltaFrame('| A | B |'),
      ].join();
      final text = await _parseDeltaTextFromRaw(service, raw);
      expect(text, '| 列1 | 列2 |\n|---|---|\n| A | B |');
    });

    test('preserves task list format', () async {
      final service = ChatApiService(HttpClient());
      final raw = [
        _buildDeltaFrame('- [x] 已完成'),
        _buildDeltaFrame('\n'),
        _buildDeltaFrame('- [ ] 未完成'),
      ].join();
      final text = await _parseDeltaTextFromRaw(service, raw);
      expect(text, '- [x] 已完成\n- [ ] 未完成');
    });

    test('preserves inline emphasis markers', () async {
      final service = ChatApiService(HttpClient());
      final raw = [
        _buildDeltaFrame('**粗体**'),
        _buildDeltaFrame(' / '),
        _buildDeltaFrame('*斜体*'),
      ].join();
      final text = await _parseDeltaTextFromRaw(service, raw);
      expect(text, '**粗体** / *斜体*');
    });
  });
}
