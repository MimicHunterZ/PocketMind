import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('分享编辑页不直接依赖 Isar 相关 Provider', () {
    final root = Directory.current.path;
    final target = File(p.join(root, 'lib', 'page', 'share', 'edit_note_page.dart'));

    expect(target.existsSync(), isTrue, reason: '未找到分享编辑页文件');

    final content = target.readAsStringSync();
    const forbiddenTokens = <String>[
      'allCategoriesProvider',
      'categoryActionsProvider',
      'noteServiceProvider',
    ];

    final violations = forbiddenTokens
        .where((token) => content.contains(token))
        .toList();

    expect(
      violations,
      isEmpty,
      reason: '分享编辑页直接依赖了 Provider：${violations.join(', ')}。'
          '这会在热引擎重开 Isar 后继续引用旧实例，导致 isar has been closed。',
    );
  });
}
