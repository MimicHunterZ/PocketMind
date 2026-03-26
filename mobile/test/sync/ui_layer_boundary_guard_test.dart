import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('UI 页面层不直接依赖同步与仓储底层 Provider', () {
    final root = Directory.current.path;
    final pageDir = Directory(p.join(root, 'lib', 'page'));
    expect(pageDir.existsSync(), isTrue, reason: '未找到 lib/page 目录');

    const forbiddenTokens = <String>[
      'noteRepositoryProvider',
      'localWriteCoordinatorProvider',
      'syncEngineProvider',
    ];

    final violations = <String>[];
    for (final entry in pageDir.listSync(recursive: true)) {
      if (entry is! File || !entry.path.endsWith('.dart')) continue;
      final relative = p.normalize(p.relative(entry.path, from: root));
      final content = entry.readAsStringSync();
      if (forbiddenTokens.any(content.contains)) {
        violations.add(relative);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'UI 页面层发现对同步/仓储底层 Provider 的直接依赖，请改为通过 NoteService/统一交互层访问: ${violations.join(', ')}',
    );
  });
}
