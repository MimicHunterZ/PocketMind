import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/api/http_client.dart';
import 'package:pocketmind/demo/a2ui/a2ui_stream_api_service.dart';

void main() {
  group('A2uiStreamApiService SSE parsing', () {
    test('parses multi-line data frame as single delta event', () async {
      final service = A2uiStreamApiService(HttpClient());
      final events = await service
          .parseForTest(
            Stream<List<int>>.fromIterable([
              utf8.encode('event: delta\n'),
              utf8.encode('data: {"a":1\n'),
              utf8.encode('data: ,"b":2}\n\n'),
            ]),
            null,
          )
          .toList();

      expect(events.length, 1);
      final delta = events.first as A2uiDeltaEvent;
      expect(delta.data, '{"a":1\n,"b":2}');
    });

    test('parses utf8 split chunks without malformed characters', () async {
      final service = A2uiStreamApiService(HttpClient());
      final bytes = utf8.encode('event: delta\ndata: 中文测试\n\n');
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
      final delta = events.first as A2uiDeltaEvent;
      expect(delta.data, '中文测试');
    });

    test('flushes trailing event without last newline', () async {
      final service = A2uiStreamApiService(HttpClient());
      final events = await service
          .parseForTest(
            Stream<List<int>>.fromIterable([
              utf8.encode('event: done\ndata: {"requestId":"r1"}'),
            ]),
            null,
          )
          .toList();

      expect(events.length, 1);
      expect(events.first, isA<A2uiDoneEvent>());
      final done = events.first as A2uiDoneEvent;
      expect(done.requestId, 'r1');
    });

    test('emits error event payload', () async {
      final service = A2uiStreamApiService(HttpClient());
      final events = await service
          .parseForTest(
            Stream<List<int>>.fromIterable([
              utf8.encode('event: error\ndata: {"message":"boom"}\n\n'),
            ]),
            CancelToken(),
          )
          .toList();

      expect(events.length, 1);
      expect(events.first, isA<A2uiErrorEvent>());
      final error = events.first as A2uiErrorEvent;
      expect(error.message, 'boom');
    });
  });
}
