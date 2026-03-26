import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('跨端一致性写入禁止出现旁路写遗留', () {
    final projectRoot = Directory.current.path;
    final libDir = Directory(p.join(projectRoot, 'lib'));
    expect(libDir.existsSync(), isTrue, reason: '未找到 lib 目录');

    final violations = <String>[];
    for (final file in libDir.listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final relative = p.normalize(p.relative(file.path, from: projectRoot));
      final content = file.readAsStringSync();
      if (!content.contains('saveSyncInternalNote(')) continue;
      violations.add(relative);
    }

    expect(
      violations,
      isEmpty,
      reason:
          '发现旁路写遗留（saveSyncInternalNote），请统一改为 NoteService.persistDerivedNoteForSync: ${violations.join(', ')}',
    );
  });
}
