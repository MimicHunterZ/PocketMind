import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('后台链路使用统一同步写入口', () {
    final root = Directory.current.path;

    final aiPollingPath = p.join('lib', 'service', 'ai_polling_service.dart');
    final callbackPath = p.join('lib', 'service', 'call_back_dispatcher.dart');

    final aiContent = File(p.join(root, aiPollingPath)).readAsStringSync();
    final callbackContent = File(p.join(root, callbackPath)).readAsStringSync();

    expect(
      aiContent.contains('persistDerivedNoteForSync('),
      isTrue,
      reason: 'AiPollingService 必须通过统一入口持久化并入队同步',
    );
    expect(
      callbackContent.contains('persistDerivedNoteForSync('),
      isTrue,
      reason: '后台回调必须通过统一入口持久化并入队同步',
    );

    expect(
      aiContent.contains('saveSyncInternalNote('),
      isFalse,
      reason: 'AiPollingService 不应再使用旁路写 saveSyncInternalNote',
    );
    expect(
      callbackContent.contains('saveSyncInternalNote('),
      isFalse,
      reason: '后台回调不应再使用旁路写 saveSyncInternalNote',
    );
  });
}
