import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('后台链路使用统一同步写入口', () {
    final root = Directory.current.path;

    final aiPollingPath = p.join('lib', 'service', 'ai_polling_service.dart');
    final callbackPath = p.join('lib', 'service', 'call_back_dispatcher.dart');
    final schedulerPath = p.join('lib', 'sync', 'resource_fetch_scheduler.dart');

    final aiContent = File(p.join(root, aiPollingPath)).readAsStringSync();
    final callbackContent = File(p.join(root, callbackPath)).readAsStringSync();
    final schedulerContent = File(
      p.join(root, schedulerPath),
    ).readAsStringSync();

    expect(
      aiContent.contains('persistDerivedNoteForSync('),
      isTrue,
      reason: 'AiPollingService 必须通过统一入口持久化并入队同步',
    );
    expect(
      schedulerContent.contains('persistDerivedNoteForSync('),
      isTrue,
      reason: '抓取调度器必须通过统一入口持久化并入队同步',
    );

    // 后台 callbackDispatcher 不再持有任何业务写权，它只能委托给
    // ResourceFetchScheduler 的公开 API（runNow / retryNotes / dismissNotes）。
    expect(
      callbackContent.contains('resourceFetchSchedulerProvider'),
      isTrue,
      reason: '后台回调必须委托 ResourceFetchScheduler，不得自己持久化',
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
    expect(
      schedulerContent.contains('saveSyncInternalNote('),
      isFalse,
      reason: '抓取调度器不应再使用旁路写 saveSyncInternalNote',
    );

    final forbiddenDirectStatusAssignment = RegExp(
      r'resourceStatus\s*=\s*AppConstants\.resourceStatus',
    );

    expect(
      forbiddenDirectStatusAssignment.hasMatch(aiContent),
      isFalse,
      reason: 'AiPollingService 不应直接赋值 resourceStatus，应走状态机入口',
    );
    expect(
      forbiddenDirectStatusAssignment.hasMatch(callbackContent),
      isFalse,
      reason: '后台回调不应直接赋值 resourceStatus，应走状态机入口',
    );
  });

  test('Note 不再持有执行细节字段', () {
    // 架构约束：执行类字段（retryCount / lease / claimedBy）必须落在
    // ScrapeAttempt 表，不得污染 Note。详见
    // docs/architecture/mobile/resource-fetch-pipeline.md。
    final root = Directory.current.path;
    final noteContent = File(p.join(root, 'lib', 'model', 'note.dart'))
        .readAsStringSync();

    final forbiddenFields = <String>[
      'retryCount',
      'scrapingLease',
      'claimedBy',
      'attemptCount',
    ];

    for (final field in forbiddenFields) {
      expect(
        noteContent.contains(field),
        isFalse,
        reason: 'Note 模型不应再包含执行字段 "$field"，请放到 ScrapeAttempt 上',
      );
    }
  });
}
