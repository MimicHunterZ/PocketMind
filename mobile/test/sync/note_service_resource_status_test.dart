import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:pocketmind/core/constants.dart';
import 'package:pocketmind/data/repositories/isar_note_repository.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/service/note_service.dart';
import 'package:pocketmind/sync/local_write_coordinator.dart';
import 'package:pocketmind/sync/resource_status_state_machine.dart';
import 'package:pocketmind/sync/sync_engine.dart';

class _MockIsarNoteRepository extends Mock implements IsarNoteRepository {}

class _MockLocalWriteCoordinator extends Mock implements LocalWriteCoordinator {}

class _MockSyncEngine extends Mock implements SyncEngine {}

class _SafeMockIsarNoteRepository extends _MockIsarNoteRepository {
  @override
  Future<void> updateResourceStatus(Note note, String status) {
    return super.noSuchMethod(
          Invocation.method(#updateResourceStatus, [note, status]),
          returnValue: Future.value(),
          returnValueForMissingStub: Future.value(),
        )
        as Future<void>;
  }

  @override
  Future<Note?> getById(int id) {
    return super.noSuchMethod(
          Invocation.method(#getById, [id]),
          returnValue: Future<Note?>.value(null),
          returnValueForMissingStub: Future<Note?>.value(null),
        )
        as Future<Note?>;
  }
}

class _SafeMockLocalWriteCoordinator extends _MockLocalWriteCoordinator {
  @override
  Future<int> writeNote(Note note) {
    return super.noSuchMethod(
          Invocation.method(#writeNote, [note]),
          returnValue: Future.value(1),
          returnValueForMissingStub: Future.value(1),
        )
        as Future<int>;
  }
}

void main() {
  late _SafeMockIsarNoteRepository repo;
  late _SafeMockLocalWriteCoordinator coordinator;
  late _MockSyncEngine syncEngine;
  late NoteService service;

  setUp(() {
    repo = _SafeMockIsarNoteRepository();
    coordinator = _SafeMockLocalWriteCoordinator();
    syncEngine = _MockSyncEngine();
    service = NoteService(
      noteRepository: repo,
      writeCoordinator: coordinator,
      syncEngine: syncEngine,
    );
  });

  test('CRAWLED 状态收到回退快照不会写回 loading 态', () async {
    final note = Note()..resourceStatus = AppConstants.resourceStatusCrawled;

    await service.applyResourceStatusEvent(
      note,
      ResourceStatusEvent.serverSnapshot,
      incomingStatus: AppConstants.resourceStatusPending,
    );

    expect(note.resourceStatus, AppConstants.resourceStatusCrawled);
    verifyNever(repo.updateResourceStatus(note, AppConstants.resourceStatusPending));
    verifyZeroInteractions(coordinator);
  });

  test('forceCompleteByUser 会写为 FAILED 并触发同步', () async {
    final note = Note()
      ..id = 1
      ..uuid = 'u1'
      ..resourceStatus = AppConstants.resourceStatusPending;

    await service.forceCompleteByUser(note);

    expect(note.resourceStatus, AppConstants.resourceStatusFailed);
    verify(coordinator.writeNote(note)).called(1);
    verify(syncEngine.kick()).called(1);
    verifyZeroInteractions(repo);
  });

  group('updateNote resourceStatus 不可降级', () {
    test('CRAWLED 笔记调用 updateNote(resourceStatus: PENDING) 后仍为 CRAWLED',
        () async {
      final existingNote = Note()
        ..id = 42
        ..uuid = 'uuid-42'
        ..title = '已完成笔记'
        ..resourceStatus = AppConstants.resourceStatusCrawled;

      when(repo.getById(42)).thenAnswer((_) async => existingNote);

      await service.updateNote(
        id: 42,
        resourceStatus: AppConstants.resourceStatusPending,
      );

      verify(coordinator.writeNote(existingNote)).called(1);
      expect(existingNote.resourceStatus, AppConstants.resourceStatusCrawled);
    });

    test('CRAWLED 笔记调用 updateNote(resourceStatus: FAILED) 后仍为 CRAWLED',
        () async {
      final existingNote = Note()
        ..id = 43
        ..uuid = 'uuid-43'
        ..title = '已完成笔记2'
        ..resourceStatus = AppConstants.resourceStatusCrawled;

      when(repo.getById(43)).thenAnswer((_) async => existingNote);

      await service.updateNote(
        id: 43,
        resourceStatus: AppConstants.resourceStatusFailed,
      );

      verify(coordinator.writeNote(existingNote)).called(1);
      expect(existingNote.resourceStatus, AppConstants.resourceStatusCrawled);
    });

    test('PENDING 笔记调用 updateNote(resourceStatus: CRAWLED) 可正常升级',
        () async {
      final existingNote = Note()
        ..id = 44
        ..uuid = 'uuid-44'
        ..title = '待抓取笔记'
        ..resourceStatus = AppConstants.resourceStatusPending;

      when(repo.getById(44)).thenAnswer((_) async => existingNote);

      await service.updateNote(
        id: 44,
        resourceStatus: AppConstants.resourceStatusCrawled,
      );

      verify(coordinator.writeNote(existingNote)).called(1);
      expect(existingNote.resourceStatus, AppConstants.resourceStatusCrawled);
    });

    test('updateNote 不传 resourceStatus 时保持原值不变', () async {
      final existingNote = Note()
        ..id = 45
        ..uuid = 'uuid-45'
        ..title = '不修改状态'
        ..resourceStatus = AppConstants.resourceStatusCrawled;

      when(repo.getById(45)).thenAnswer((_) async => existingNote);

      await service.updateNote(id: 45, title: '新标题');

      verify(coordinator.writeNote(existingNote)).called(1);
      expect(existingNote.resourceStatus, AppConstants.resourceStatusCrawled);
    });
  });
}
