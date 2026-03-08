import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/util/tag_list_utils.dart';

void main() {
  group('TagListUtils.normalize', () {
    test('会去空、裁剪空白并保持首次出现顺序', () {
      final result = TagListUtils.normalize([
        ' AI ',
        '',
        'flutter',
        'AI',
        null,
        '  ',
        'riverpod',
      ]);

      expect(result, ['AI', 'flutter', 'riverpod']);
    });
  });

  group('TagListUtils.mergeLocalAndServer', () {
    test('本地 pending 与服务端标签冲突时执行并集合并且本地顺序优先', () {
      final result = TagListUtils.mergeLocalAndServer(
        localTags: ['手动标签', 'flutter', 'AI'],
        serverTags: ['AI', '云端补全', ' flutter ', '知识管理'],
      );

      expect(result, ['手动标签', 'flutter', 'AI', '云端补全', '知识管理']);
    });

    test('当任一侧存在脏数据时仍能得到干净结果', () {
      final result = TagListUtils.mergeLocalAndServer(
        localTags: ['  ', '用户标签', ''],
        serverTags: [null, 'AI标签', '用户标签'],
      );

      expect(result, ['用户标签', 'AI标签']);
    });
  });
}
