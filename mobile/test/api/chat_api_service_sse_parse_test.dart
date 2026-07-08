import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/api/chat_api_service.dart';
import 'package:pocketmind/api/http_client.dart';
import 'package:pocketmind/api/models/chat_models.dart';

/// 构造一个 TEXT_MESSAGE_CONTENT SSE 帧(delta 包在 JSON 里,换行被转义)。
String _buildContentFrame(String delta) {
  final payload = jsonEncode({'messageId': 'm1', 'delta': delta});
  return 'event:TEXT_MESSAGE_CONTENT\ndata:$payload\n\n';
}

Future<List<ChatStreamEvent>> _parse(ChatApiService service, String raw) {
  return service
      .parseForTest(Stream<List<int>>.fromIterable([utf8.encode(raw)]), null)
      .toList();
}

Future<String> _accumulateText(ChatApiService service, String raw) async {
  final events = await _parse(service, raw);
  return events.whereType<ChatDeltaEvent>().map((e) => e.delta).join();
}

void main() {
  group('ChatApiService SSE parsing(AG-UI 细粒度事件)', () {
    test('TEXT_MESSAGE_CONTENT → ChatDeltaEvent,delta 原样保留', () async {
      final service = ChatApiService(HttpClient());
      final events = await _parse(service, _buildContentFrame('你好世界'));
      expect(events, hasLength(1));
      expect(events.first, isA<ChatDeltaEvent>());
      expect((events.first as ChatDeltaEvent).delta, '你好世界');
    });

    test('utf8 分块到达不产生乱码', () async {
      final service = ChatApiService(HttpClient());
      final bytes = utf8.encode(_buildContentFrame('中文测试'));
      final events = await service
          .parseForTest(
            Stream<List<int>>.fromIterable([
              bytes.sublist(0, 19),
              bytes.sublist(19),
            ]),
            null,
          )
          .toList();
      final text = events.whereType<ChatDeltaEvent>().map((e) => e.delta).join();
      expect(text, '中文测试');
    });

    test('RUN_FINISHED.result 携带 messageUuid → ChatDoneEvent', () async {
      final service = ChatApiService(HttpClient());
      final payload = jsonEncode({
        'threadId': 's1',
        'runId': 'r1',
        'result': 'assistant-uuid-1',
      });
      final events = await _parse(
        service,
        'event:RUN_FINISHED\ndata:$payload\n\n',
      );
      expect(events, hasLength(1));
      expect(events.first, isA<ChatDoneEvent>());
      final done = events.first as ChatDoneEvent;
      expect(done.messageUuid, 'assistant-uuid-1');
      expect(done.requestId, 'r1');
    });

    test('TOOL_CALL_START / TOOL_CALL_END → 工具进度事件', () async {
      final service = ChatApiService(HttpClient());
      final start = jsonEncode({
        'toolCallId': 'call_1',
        'toolCallName': 'searchMemory',
      });
      final end = jsonEncode({'toolCallId': 'call_1'});
      final events = await _parse(
        service,
        'event:TOOL_CALL_START\ndata:$start\n\n'
        'event:TOOL_CALL_END\ndata:$end\n\n',
      );
      expect(events, hasLength(2));
      expect(events[0], isA<ChatToolCallStartEvent>());
      final startEvent = events[0] as ChatToolCallStartEvent;
      expect(startEvent.toolCallId, 'call_1');
      expect(startEvent.toolName, 'searchMemory');
      expect(events[1], isA<ChatToolCallEndEvent>());
      expect((events[1] as ChatToolCallEndEvent).toolCallId, 'call_1');
    });

    test('ACTIVITY_SNAPSHOT content 数组 → 拆成逐条 ChatA2uiChunkEvent', () async {
      final service = ChatApiService(HttpClient());
      final content = [
        {
          'version': 'v0.9',
          'createSurface': {'surfaceId': 's1'},
        },
        {
          'version': 'v0.9',
          'updateComponents': {'surfaceId': 's1', 'components': []},
        },
      ];
      final payload = jsonEncode({
        'messageId': 'm1',
        'activityType': 'a2ui-surface',
        'content': content,
        'replace': true,
      });
      final events = await _parse(
        service,
        'event:ACTIVITY_SNAPSHOT\ndata:$payload\n\n',
      );
      final chunks = events.whereType<ChatA2uiChunkEvent>().toList();
      expect(chunks, hasLength(2));
      final first = jsonDecode(chunks[0].json) as Map<String, dynamic>;
      expect(first['createSurface'], isNotNull);
      final second = jsonDecode(chunks[1].json) as Map<String, dynamic>;
      expect(second['updateComponents'], isNotNull);
    });

    test('ACTIVITY_SNAPSHOT content 单对象 → 一条 ChatA2uiChunkEvent', () async {
      final service = ChatApiService(HttpClient());
      final payload = jsonEncode({
        'messageId': 'm1',
        'activityType': 'a2ui-surface',
        'content': {
          'version': 'v0.9',
          'createSurface': {'surfaceId': 's1'},
        },
      });
      final events = await _parse(
        service,
        'event:ACTIVITY_SNAPSHOT\ndata:$payload\n\n',
      );
      expect(events.whereType<ChatA2uiChunkEvent>(), hasLength(1));
    });

    test('CUSTOM(chat.paused) → ChatPausedEvent', () async {
      final service = ChatApiService(HttpClient());
      final payload = jsonEncode({
        'name': 'chat.paused',
        'value': {'requestId': 'r1', 'messageUuid': 'm1'},
      });
      final events = await _parse(service, 'event:CUSTOM\ndata:$payload\n\n');
      expect(events, hasLength(1));
      expect(events.first, isA<ChatPausedEvent>());
      final paused = events.first as ChatPausedEvent;
      expect(paused.requestId, 'r1');
      expect(paused.messageUuid, 'm1');
    });

    test('RUN_ERROR → ChatErrorEvent', () async {
      final service = ChatApiService(HttpClient());
      final payload = jsonEncode({'message': 'AI服务异常_ERR_500'});
      final events = await _parse(service, 'event:RUN_ERROR\ndata:$payload\n\n');
      expect(events, hasLength(1));
      expect(events.first, isA<ChatErrorEvent>());
      expect((events.first as ChatErrorEvent).message, 'AI服务异常_ERR_500');
    });

    test('生命周期事件(RUN_STARTED / TEXT_MESSAGE_START/END / TOOL_CALL_RESULT)被忽略', () async {
      final service = ChatApiService(HttpClient());
      final events = await _parse(
        service,
        'event:RUN_STARTED\ndata:{"threadId":"s1","runId":"r1"}\n\n'
        'event:TEXT_MESSAGE_START\ndata:{"messageId":"m1","role":"assistant"}\n\n'
        'event:TEXT_MESSAGE_END\ndata:{"messageId":"m1"}\n\n'
        'event:TOOL_CALL_RESULT\ndata:{"messageId":"m2","toolCallId":"call_1","content":"ok"}\n\n',
      );
      expect(events, isEmpty);
    });

    test('flush 尾部无空行分隔的 RUN_FINISHED', () async {
      final service = ChatApiService(HttpClient());
      final events = await service
          .parseForTest(
            Stream<List<int>>.fromIterable([
              utf8.encode(
                'event:RUN_FINISHED\ndata:{"threadId":"s1","runId":"r1","result":"m1"}',
              ),
            ]),
            null,
          )
          .toList();
      expect(events, hasLength(1));
      expect(events.first, isA<ChatDoneEvent>());
      expect((events.first as ChatDoneEvent).messageUuid, 'm1');
    });

    // 一整轮混排流:文本 → 工具 → 文本 → 卡片 → 完成,验证块序列顺序正确。
    test('完整一轮混排流:文本/工具/文本/卡片/完成 顺序正确', () async {
      final service = ChatApiService(HttpClient());
      String frame(String event, Object payload) =>
          'event:$event\ndata:${jsonEncode(payload)}\n\n';
      final raw = [
        _buildContentFrame('我来帮你看看\n\n## 结果'),
        frame('TOOL_CALL_START', {
          'toolCallId': 'c1',
          'toolCallName': 'searchMemory',
        }),
        frame('TOOL_CALL_END', {'toolCallId': 'c1'}),
        _buildContentFrame('根据检索结果:'),
        frame('ACTIVITY_SNAPSHOT', {
          'messageId': 'm2',
          'activityType': 'a2ui-surface',
          'content': [
            {
              'version': 'v0.9',
              'createSurface': {'surfaceId': 's1'},
            },
          ],
        }),
        frame('RUN_FINISHED', {
          'threadId': 's1',
          'runId': 'r1',
          'result': 'assistant-1',
        }),
      ].join();
      final events = await _parse(service, raw);

      expect(events[0], isA<ChatDeltaEvent>());
      expect(events[1], isA<ChatToolCallStartEvent>());
      expect(events[2], isA<ChatToolCallEndEvent>());
      expect(events[3], isA<ChatDeltaEvent>());
      expect(events[4], isA<ChatA2uiChunkEvent>());
      expect(events[5], isA<ChatDoneEvent>());
    });
  });

  group('文本 delta 累积保留 markdown 结构', () {
    test('标题拆分块累积', () async {
      final service = ChatApiService(HttpClient());
      final raw = [
        _buildContentFrame('##'),
        _buildContentFrame(' '),
        _buildContentFrame('标题示例'),
        _buildContentFrame('\n'),
      ].join();
      expect(await _accumulateText(service, raw), '## 标题示例\n');
    });

    test('围栏代码块结构', () async {
      final service = ChatApiService(HttpClient());
      final raw = [
        _buildContentFrame('```'),
        _buildContentFrame('dart'),
        _buildContentFrame('\n'),
        _buildContentFrame('print("ok");'),
        _buildContentFrame('\n'),
        _buildContentFrame('```'),
      ].join();
      expect(await _accumulateText(service, raw), '```dart\nprint("ok");\n```');
    });

    test('表格结构', () async {
      final service = ChatApiService(HttpClient());
      final raw = [
        _buildContentFrame('| 列1 | 列2 |'),
        _buildContentFrame('\n'),
        _buildContentFrame('|---|---|'),
        _buildContentFrame('\n'),
        _buildContentFrame('| A | B |'),
      ].join();
      expect(
        await _accumulateText(service, raw),
        '| 列1 | 列2 |\n|---|---|\n| A | B |',
      );
    });
  });
}
