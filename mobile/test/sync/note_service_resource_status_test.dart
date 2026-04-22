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
}
