import 'dart:convert';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/demo/a2ui/a2ui_stream_api_service.dart';

void main() {
  group('A2uiStreamApiService local mock stream', () {
    test('emits a staged scenario at a visible frame rate', () async {
      final service = A2uiStreamApiService();
      final events = await service
          .mockStream(requestId: 'r-local', delay: Duration.zero)
          .toList();

      expect(events.whereType<A2uiDeltaEvent>().length, greaterThan(12));
      expect(events.last, isA<A2uiDoneEvent>());
      expect((events.last as A2uiDoneEvent).requestId, 'r-local');

      final payloads = events
          .whereType<A2uiDeltaEvent>()
          .map((event) => jsonDecode(event.data) as Map<String, dynamic>)
          .toList();

      expect(payloads.first['version'], 'v0.9');
      expect(payloads.first['createSurface'], isA<Map<String, dynamic>>());
      expect(
        (payloads.first['createSurface'] as Map<String, dynamic>)['surfaceId'],
        'mock_r-local',
      );
      for (final payload in payloads) {
        expect(payload['version'], 'v0.9');
        expect(jsonEncode(payload), isNot(contains('```')));
      }

      final componentUpdates = payloads
          .map((payload) => payload['updateComponents'])
          .whereType<Map<String, dynamic>>()
          .toList();
      final components = componentUpdates
          .expand((update) => update['components'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .toList();

      expect(components.any((component) => component['id'] == 'root'), isTrue);
      final rootSnapshots = components
          .where((component) => component['id'] == 'root')
          .map(
            (component) =>
                (component['children'] as List<dynamic>).cast<String>(),
          )
          .toList();
      expect(rootSnapshots.first, ['briefCard']);
      expect(rootSnapshots.last, [
        'briefCard',
        'formCard',
        'agendaCard',
        'reminderCard',
        'actionCard',
      ]);
      for (final type in [
        'Button',
        'Card',
        'CheckBox',
        'Column',
        'DateTimeInput',
        'Divider',
        'Icon',
        'List',
        'Modal',
        'ChoicePicker',
        'Row',
        'Slider',
        'Text',
        'TextField',
      ]) {
        expect(
          components.any((component) => component['component'] == type),
          isTrue,
          reason: 'missing $type',
        );
      }

      final agendaList = components.singleWhere(
        (component) => component['id'] == 'agendaList',
      );
      expect(
        agendaList['children'],
        equals({'path': '/agenda', 'componentId': 'agendaItem'}),
      );

      final continueButton = components.singleWhere(
        (component) => component['id'] == 'continueButton',
      );
      final action = continueButton['action'] as Map<String, dynamic>;
      final event = action['event'] as Map<String, dynamic>;
      expect(event['name'], 'continue_generation');
      expect(event['context'], contains('topic'));

      final updatePaths = payloads
          .map((payload) => payload['updateDataModel'])
          .whereType<Map<String, dynamic>>()
          .map((update) => update['path']);
      expect(updatePaths, contains('/brief/body'));
      expect(updatePaths, contains('/agenda'));
      expect(updatePaths, contains('/state/status'));
      expect(updatePaths, isNot(contains('/article/progress')));
    });

    test('stops after cancellation between frames', () async {
      final service = A2uiStreamApiService();
      final cancelToken = CancelToken();
      final events = <A2uiSseEvent>[];

      await for (final event in service.mockStream(
        requestId: 'r-cancel',
        cancelToken: cancelToken,
        delay: Duration.zero,
      )) {
        events.add(event);
        cancelToken.cancel();
      }

      expect(events, hasLength(1));
      expect(events.single, isA<A2uiDeltaEvent>());
      final first =
          jsonDecode((events.single as A2uiDeltaEvent).data)
              as Map<String, dynamic>;
      expect(first['createSurface'], isA<Map<String, dynamic>>());
    });
  });
}
