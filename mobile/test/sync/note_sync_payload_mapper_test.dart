import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/sync/note_sync_payload_mapper.dart';

void main() {
  group('NoteSyncPayloadMapper.applyServerSnapshot', () {
    test('当服务端未携带 previewImageUrl 时保留本地图片字段', () {
      final note = Note()
        ..previewImageUrl = 'local://cover.jpg'
        ..title = '旧标题';

      NoteSyncPayloadMapper.applyServerSnapshot(
        target: note,
        payload: {
          'uuid': 'u1',
          'title': '新标题',
          'updatedAt': 10,
          'isDeleted': false,
          'categoryId': 1,
          'tags': const <String>[],
          'previewTitle': 'preview',
          'previewDescription': 'desc',
          'previewContent': 'content',
          'resourceStatus': 'CRAWLED',
          'aiSummary': 'summary',
          'serverVersion': 7,
        },
        serverVersion: 7,
      );

      expect(note.title, '新标题');
      expect(note.previewImageUrl, 'local://cover.jpg');
    });

    test('当服务端显式携带 previewImageUrl 时允许覆盖本地值', () {
      final note = Note()..previewImageUrl = 'local://cover.jpg';

      NoteSyncPayloadMapper.applyServerSnapshot(
        target: note,
        payload: {
          'uuid': 'u2',
          'updatedAt': 10,
          'isDeleted': false,
          'categoryId': 1,
          'tags': const <String>[],
          'previewImageUrl': 'https://server/image.jpg',
          'serverVersion': 8,
        },
        serverVersion: 8,
      );

      expect(note.previewImageUrl, 'https://server/image.jpg');
    });

    test('当服务端预览字段为 null 时保留本地值', () {
      final note = Note()
        ..previewTitle = 'local-title'
        ..previewDescription = 'local-desc'
        ..previewContent = 'local-content';

      NoteSyncPayloadMapper.applyServerSnapshot(
        target: note,
        payload: {
          'uuid': 'u3',
          'updatedAt': 10,
          'isDeleted': false,
          'categoryId': 1,
          'tags': const <String>[],
          'previewTitle': null,
          'previewDescription': null,
          'previewContent': null,
          'serverVersion': 9,
        },
        serverVersion: 9,
      );

      expect(note.previewTitle, 'local-title');
      expect(note.previewDescription, 'local-desc');
      expect(note.previewContent, 'local-content');
    });

    test('当服务端预览字段为空字符串时保留本地值', () {
      final note = Note()
        ..previewTitle = 'local-title'
        ..previewDescription = 'local-desc'
        ..previewContent = 'local-content';

      NoteSyncPayloadMapper.applyServerSnapshot(
        target: note,
        payload: {
          'uuid': 'u4',
          'updatedAt': 10,
          'isDeleted': false,
          'categoryId': 1,
          'tags': const <String>[],
          'previewTitle': '   ',
          'previewDescription': '',
          'previewContent': ' \n\t ',
          'serverVersion': 10,
        },
        serverVersion: 10,
      );

      expect(note.previewTitle, 'local-title');
      expect(note.previewDescription, 'local-desc');
      expect(note.previewContent, 'local-content');
    });

    test('本地 CRAWLED 时服务端回流 PENDING 不应降级', () {
      final note = Note()..resourceStatus = 'CRAWLED';

      NoteSyncPayloadMapper.applyServerSnapshot(
        target: note,
        payload: {
          'uuid': 'u5',
          'updatedAt': 11,
          'isDeleted': false,
          'categoryId': 1,
          'tags': const <String>[],
          'resourceStatus': 'PENDING',
          'serverVersion': 11,
        },
        serverVersion: 11,
      );

      expect(note.resourceStatus, 'CRAWLED');
    });

    test('本地 FAILED 时服务端回流 CRAWLED 可升级', () {
      final note = Note()..resourceStatus = 'FAILED';

      NoteSyncPayloadMapper.applyServerSnapshot(
        target: note,
        payload: {
          'uuid': 'u6',
          'updatedAt': 12,
          'isDeleted': false,
          'categoryId': 1,
          'tags': const <String>[],
          'resourceStatus': 'CRAWLED',
          'serverVersion': 12,
        },
        serverVersion: 12,
      );

      expect(note.resourceStatus, 'CRAWLED');
    });

    test('本地 CRAWLED 时服务端回流 FAILED 仍保持 CRAWLED', () {
      final note = Note()..resourceStatus = 'CRAWLED';

      NoteSyncPayloadMapper.applyServerSnapshot(
        target: note,
        payload: {
          'uuid': 'u7',
          'updatedAt': 13,
          'isDeleted': false,
          'categoryId': 1,
          'tags': const <String>[],
          'resourceStatus': 'FAILED',
          'serverVersion': 13,
        },
        serverVersion: 13,
      );

      expect(note.resourceStatus, 'CRAWLED');
    });
  });
}
