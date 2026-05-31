import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:pocketmind/core/constants.dart';
import 'package:pocketmind/data/repositories/isar_note_repository.dart';
import 'package:pocketmind/model/category.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/model/chat_session.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/model/note_asset.dart';
import 'package:pocketmind/model/scrape_attempt.dart';
import 'package:pocketmind/service/metadata_manager.dart';
import 'package:pocketmind/service/note_service.dart';
import 'package:pocketmind/sync/local_write_coordinator.dart';
import 'package:pocketmind/sync/model/mutation_entry.dart';
import 'package:pocketmind/sync/model/sync_checkpoint.dart';
import 'package:pocketmind/sync/process_id.dart';
import 'package:pocketmind/sync/resource_fetch_scheduler.dart';

/// 关键并发路径的端到端测试，使用真 Isar 实例。
///
/// 覆盖：claim CAS、enqueue 去重、悬挂复活墓志铭、慢 worker finalize 拒绝、
/// retryNotes / dismissNotes 状态推进。
void main() {
  late Directory tempDir;
  late Isar isar;
  late ResourceFetchScheduler scheduler;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pm_scheduler_test_');
    isar = await Isar.open([
      NoteSchema,
      CategorySchema,
      NoteAssetSchema,
      ChatSessionSchema,
      ChatMessageSchema,
      MutationEntrySchema,
      SyncCheckpointSchema,
      ScrapeAttemptSchema,
    ], directory: tempDir.path);

    final noteRepo = IsarNoteRepository(isar);
    final coordinator = LocalWriteCoordinator(isar);
    final noteService = NoteService(
      noteRepository: noteRepo,
      writeCoordinator: coordinator,
    );
    // 测试只覆盖 claim/finalize/enqueue 等 DB 路径，不会触达
    // _process → metadataManager.fetchAndProcessMetadata，所以 MetadataManager
    // 不传任何依赖即可。
    final metadataManager = MetadataManager();

    scheduler = ResourceFetchScheduler(
      isar: isar,
      noteService: noteService,
      metadataManager: metadataManager,
    );

    ProcessId.debugSet('proc-A');
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    ProcessId.debugSet(null);
  });

  Future<Note> createNote({
    required String uuid,
    String? url = 'https://example.com/x',
    String resourceStatus = 'PENDING',
    bool isDeleted = false,
  }) async {
    final note = Note()
      ..uuid = uuid
      ..url = url
      ..isDeleted = isDeleted
      ..resourceStatus = resourceStatus;
    await isar.writeTxn(() async {
      await isar.notes.put(note);
    });
    return note;
  }

  group('enqueueIfAbsent', () {
    test('为 PENDING note 创建一条 queued 作业', () async {
      await createNote(uuid: 'n1');

      await scheduler.enqueueIfAbsent('n1');

      final attempts = await isar.scrapeAttempts.where().findAll();
      expect(attempts.length, 1);
      expect(attempts.first.state, AppConstants.scrapeAttemptStateQueued);
      expect(attempts.first.attemptNumber, 1);
      expect(attempts.first.noteUuid, 'n1');
    });

    test('已有 queued 作业时幂等，不重复创建', () async {
      await createNote(uuid: 'n1');
      await scheduler.enqueueIfAbsent('n1');
      await scheduler.enqueueIfAbsent('n1');
      await scheduler.enqueueIfAbsent('n1');

      final attempts = await isar.scrapeAttempts.where().findAll();
      expect(attempts.length, 1);
    });

    test('CRAWLED 终态拒绝再入队', () async {
      await createNote(uuid: 'n1', resourceStatus: 'CRAWLED');
      await scheduler.enqueueIfAbsent('n1');

      final attempts = await isar.scrapeAttempts.where().findAll();
      expect(attempts, isEmpty);
    });

    test('已删除的 note 拒绝入队', () async {
      await createNote(uuid: 'n1', isDeleted: true);
      await scheduler.enqueueIfAbsent('n1');

      final attempts = await isar.scrapeAttempts.where().findAll();
      expect(attempts, isEmpty);
    });
  });

  group('claimNext', () {
    test('无作业时返回 null', () async {
      final id = await scheduler.claimNext();
      expect(id, isNull);
    });

    test('从 queued 转 running，写入 claimedAt + claimedBy', () async {
      await createNote(uuid: 'n1');
      await scheduler.enqueueIfAbsent('n1');

      final id = await scheduler.claimNext();
      expect(id, isNotNull);

      final row = await isar.scrapeAttempts.get(id!);
      expect(row, isNotNull);
      expect(row!.state, AppConstants.scrapeAttemptStateRunning);
      expect(row.claimedAt, isNotNull);
      expect(row.claimedBy, 'proc-A');
    });

    test('lease 未过期的 running 不会被领走', () async {
      await createNote(uuid: 'n1');
      await scheduler.enqueueIfAbsent('n1');
      await scheduler.claimNext(); // 领走

      final second = await scheduler.claimNext();
      expect(second, isNull, reason: '同一作业 lease 内不应被再次领走');
    });

    test('lease 过期 → 领走 + 复制墓志铭 + attemptNumber+1', () async {
      await createNote(uuid: 'n1');
      await scheduler.enqueueIfAbsent('n1');
      final firstId = await scheduler.claimNext();
      expect(firstId, isNotNull);

      // 手动把 claimedAt 退到 lease 之外
      await isar.writeTxn(() async {
        final row = await isar.scrapeAttempts.get(firstId!);
        row!.claimedAt = DateTime.now()
            .subtract(AppConstants.scrapeLease)
            .subtract(const Duration(minutes: 1));
        await isar.scrapeAttempts.put(row);
      });

      // 切换到另一个进程身份
      ProcessId.debugSet('proc-B');
      final secondId = await scheduler.claimNext();
      expect(secondId, isNotNull);

      final all = await isar.scrapeAttempts.where().findAll();
      // 一条墓志铭 (failed/crashed) + 一条 running（B 接管）
      expect(all.length, 2);

      final crashed = all.firstWhere(
        (a) => a.errorCode == AppConstants.scrapeErrorCrashed,
      );
      expect(crashed.state, AppConstants.scrapeAttemptStateFailed);
      expect(crashed.claimedBy, 'proc-A');
      expect(crashed.attemptNumber, 1);

      final running = all.firstWhere(
        (a) => a.state == AppConstants.scrapeAttemptStateRunning,
      );
      expect(running.claimedBy, 'proc-B');
      expect(running.attemptNumber, 2);
    });

    test('多条 queued 按 enqueuedAt 顺序依次被领走', () async {
      await createNote(uuid: 'n1');
      await createNote(uuid: 'n2');

      await scheduler.enqueueIfAbsent('n1');
      // 让 n2 的 enqueuedAt 严格晚于 n1
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await scheduler.enqueueIfAbsent('n2');

      final firstId = await scheduler.claimNext();
      final firstRow = await isar.scrapeAttempts.get(firstId!);
      expect(firstRow!.noteUuid, 'n1');

      final secondId = await scheduler.claimNext();
      final secondRow = await isar.scrapeAttempts.get(secondId!);
      expect(secondRow!.noteUuid, 'n2');
    });
  });

  group('finalize CAS', () {
    test('正常 finalize 写入 succeeded + Note → CRAWLED', () async {
      await createNote(uuid: 'n1');
      await scheduler.enqueueIfAbsent('n1');
      final id = await scheduler.claimNext();

      final accepted = await scheduler.finalize(
        id!,
        state: AppConstants.scrapeAttemptStateSucceeded,
      );
      expect(accepted, isTrue);

      final row = await isar.scrapeAttempts.get(id);
      expect(row!.state, AppConstants.scrapeAttemptStateSucceeded);
      expect(row.finishedAt, isNotNull);

      final note = await isar.notes.where().uuidEqualTo('n1').findFirst();
      expect(note!.resourceStatus, AppConstants.resourceStatusCrawled);
    });

    test('claimedBy 不一致 → 拒绝写入', () async {
      await createNote(uuid: 'n1');
      await scheduler.enqueueIfAbsent('n1');
      final id = await scheduler.claimNext();

      // 模拟"我已被收编"——别人改了 claimedBy
      ProcessId.debugSet('proc-OTHER');

      final accepted = await scheduler.finalize(
        id!,
        state: AppConstants.scrapeAttemptStateSucceeded,
      );
      expect(accepted, isFalse);

      final row = await isar.scrapeAttempts.get(id);
      expect(row!.state, AppConstants.scrapeAttemptStateRunning,
          reason: '行不应被慢 worker 修改');
      final note = await isar.notes.where().uuidEqualTo('n1').findFirst();
      expect(note!.resourceStatus, AppConstants.resourceStatusPending,
          reason: 'Note 不应被慢 worker 升级');
    });

    test('failed + terminal=true → Note → FAILED', () async {
      await createNote(uuid: 'n1');
      await scheduler.enqueueIfAbsent('n1');
      final id = await scheduler.claimNext();

      await scheduler.finalize(
        id!,
        state: AppConstants.scrapeAttemptStateFailed,
        errorCode: AppConstants.scrapeErrorNetwork,
        terminal: true,
      );

      final note = await isar.notes.where().uuidEqualTo('n1').findFirst();
      expect(note!.resourceStatus, AppConstants.resourceStatusFailed);
    });

    test('failed + terminal=false → Note 仍是 PENDING', () async {
      await createNote(uuid: 'n1');
      await scheduler.enqueueIfAbsent('n1');
      final id = await scheduler.claimNext();

      await scheduler.finalize(
        id!,
        state: AppConstants.scrapeAttemptStateFailed,
        errorCode: AppConstants.scrapeErrorNetwork,
        terminal: false,
      );

      final note = await isar.notes.where().uuidEqualTo('n1').findFirst();
      expect(note!.resourceStatus, AppConstants.resourceStatusPending);
    });

    test('CRAWLED 终态不会被 finalize 回退', () async {
      await createNote(uuid: 'n1');
      await scheduler.enqueueIfAbsent('n1');
      final id = await scheduler.claimNext();

      // 先抢着把 note 升级到 CRAWLED
      await isar.writeTxn(() async {
        final note = await isar.notes.where().uuidEqualTo('n1').findFirst();
        note!.resourceStatus = AppConstants.resourceStatusCrawled;
        await isar.notes.put(note);
      });

      await scheduler.finalize(
        id!,
        state: AppConstants.scrapeAttemptStateFailed,
        errorCode: AppConstants.scrapeErrorNetwork,
        terminal: true,
      );

      final note = await isar.notes.where().uuidEqualTo('n1').findFirst();
      expect(note!.resourceStatus, AppConstants.resourceStatusCrawled,
          reason: 'CRAWLED 不应被 failed finalize 拉回');
    });
  });

  group('retryNotes', () {
    test('FAILED → PENDING 并入队', () async {
      await createNote(uuid: 'n1', resourceStatus: 'FAILED');

      await scheduler.retryNotes(['n1']);

      final note = await isar.notes.where().uuidEqualTo('n1').findFirst();
      expect(note!.resourceStatus, AppConstants.resourceStatusPending);

      final attempts = await isar.scrapeAttempts.where().findAll();
      expect(attempts.length, 1);
      expect(attempts.first.state, AppConstants.scrapeAttemptStateQueued);
    });

    test('CRAWLED 不被 retry 改动', () async {
      await createNote(uuid: 'n1', resourceStatus: 'CRAWLED');
      await scheduler.retryNotes(['n1']);

      final note = await isar.notes.where().uuidEqualTo('n1').findFirst();
      expect(note!.resourceStatus, AppConstants.resourceStatusCrawled);
      final attempts = await isar.scrapeAttempts.where().findAll();
      expect(attempts, isEmpty);
    });
  });

  group('dismissNotes', () {
    test('取消活跃作业 + Note → FAILED', () async {
      await createNote(uuid: 'n1');
      await scheduler.enqueueIfAbsent('n1');

      await scheduler.dismissNotes(['n1']);

      final note = await isar.notes.where().uuidEqualTo('n1').findFirst();
      expect(note!.resourceStatus, AppConstants.resourceStatusFailed);

      final attempts = await isar.scrapeAttempts.where().findAll();
      expect(attempts.length, 1);
      expect(attempts.first.state, AppConstants.scrapeAttemptStateCancelled);
      expect(attempts.first.errorCode, AppConstants.scrapeErrorCancelled);
    });

    test('CRAWLED note 被 dismiss 不会回退', () async {
      await createNote(uuid: 'n1', resourceStatus: 'CRAWLED');
      await scheduler.dismissNotes(['n1']);

      final note = await isar.notes.where().uuidEqualTo('n1').findFirst();
      expect(note!.resourceStatus, AppConstants.resourceStatusCrawled);
    });
  });

  group('enqueueOrphanedPendingNotes', () {
    test('PENDING note 没有活跃作业时补一条 queued', () async {
      await createNote(uuid: 'n1');
      // 没调 enqueueIfAbsent

      await scheduler.enqueueOrphanedPendingNotes();

      final attempts = await isar.scrapeAttempts.where().findAll();
      expect(attempts.length, 1);
      expect(attempts.first.noteUuid, 'n1');
    });

    test('已经有活跃作业 → 不重复', () async {
      await createNote(uuid: 'n1');
      await scheduler.enqueueIfAbsent('n1');
      await scheduler.enqueueOrphanedPendingNotes();

      final attempts = await isar.scrapeAttempts.where().findAll();
      expect(attempts.length, 1);
    });
  });

  group('claimNext 退避', () {
    test('enqueuedAt 在未来的 queued 作业不会被领走', () async {
      await createNote(uuid: 'n1');

      // 直接写一条 enqueuedAt 在未来 5 分钟的 queued 作业
      await isar.writeTxn(() async {
        await isar.scrapeAttempts.put(
          ScrapeAttempt()
            ..noteUuid = 'n1'
            ..state = AppConstants.scrapeAttemptStateQueued
            ..attemptNumber = 2
            ..enqueuedAt = DateTime.now().add(const Duration(minutes: 5)),
        );
      });

      final claimed = await scheduler.claimNext();
      expect(claimed, isNull, reason: '退避时间内不应被领取');
    });

    test('两条 queued: 一条 now 一条未来 → 只领走 now 那条', () async {
      await createNote(uuid: 'n1');
      await createNote(uuid: 'n2');

      await isar.writeTxn(() async {
        await isar.scrapeAttempts.put(
          ScrapeAttempt()
            ..noteUuid = 'n1'
            ..state = AppConstants.scrapeAttemptStateQueued
            ..attemptNumber = 2
            ..enqueuedAt = DateTime.now().add(const Duration(minutes: 5)),
        );
        await isar.scrapeAttempts.put(
          ScrapeAttempt()
            ..noteUuid = 'n2'
            ..state = AppConstants.scrapeAttemptStateQueued
            ..attemptNumber = 1
            ..enqueuedAt = DateTime.now(),
        );
      });

      final firstId = await scheduler.claimNext();
      final firstRow = await isar.scrapeAttempts.get(firstId!);
      expect(firstRow!.noteUuid, 'n2', reason: '应跳过未来时间的 n1，领走 n2');

      final secondId = await scheduler.claimNext();
      expect(secondId, isNull, reason: 'n1 还在退避，不应被领取');
    });
  });
}
