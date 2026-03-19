# PocketMind Backend: Remaining Architecture Issues

Based on a meticulous empirical audit of the source code (as of Phase 3), the following architectural and pattern violations remain. These have been actively sourced from current file contents, eliminating any outdated assumptions.

## 1. Controller Layer Violations (Strict Layering)
**Rule**: Controllers must act as a thin protocol adapter layer and must *only* inject Services, strictly forbidding the injection of `Repository` or `Mapper` classes.

**Current Violations**:
- **File**: `PostController.java` (`com.doublez.pocketmindserver.note.api`)
  - **Issue**: Directly injects `NoteRepository` and `ChatSessionRepository` via constructor (`@RequiredArgsConstructor`).
  - **Fix**: Create a `PostService` (or use existing Note/Chat services) to encapsulate `findByUuidAndUserId`, `chatSessionRepository.findByNoteUuid`, and tag resolution, keeping DB dependencies out of the controller.

## 2. Service Layer Violations (Repository Pattern Bypass)
**Rule**: Services must mediate data access strictly through `Repository` interfaces to remain storage-neutral and encapsulate ORM logic.

**Current Violations**:
- **File**: `AssetExtractionsService.java` (`com.doublez.pocketmindserver.asset.application`)
  - **Issue**: Directly injects `AttachmentVisionMapper` to query assets via `findAllByAssetsUuid`.
  - **Fix**: Introduce an `AssetExtractionRepository` interface and its MyBatis implementation (`MybatisAssetExtractionRepository`) to shield the service from MybatisPlus mappers.

## 3. Persistent Layer Performance Issues (N+1 Query)
**Rule**: Avoid firing database queries inside streaming loops or iterators.

**Current Violations**:
- **File**: `MybatisNoteRepository.java` (`com.doublez.pocketmindserver.note.infra.persistence.note`)
  - **Method**: `findChangedSince(...)`
  - **Issue**: Fetches a list of `NoteModel` based on cursor/limit, streams through them via `.map(this::toDomainWithTags)`. For *each* note, `toDomainWithTags` explicitly calls `relationMapper.findTagIdsByNoteUuid(model.getUserId(), model.getUuid())`. If 100 notes are fetched, this triggers 100 subsequent DB queries (an N+1 Query bottleneck).
  - **Fix**: Perform a bulk `IN` query on `NoteTagRelationMapper` taking the list of note Uuids, group tags in memory, and map them to domain objects without triggering looped DB calls.


---
*Note: Previous false-positives have been dismissed. Specifically:*
- *`MemoryExtractorServiceImpl` safely isolates its AI `chatModel.stream` / `call` from the @Transactional boundaries.*
- *Cascade deletes in `ResourceCatalogSyncServiceImpl` accurately follow required logic without DB trigger pollution.*
- *The string magic constant leak (e.g. `ChatRole.TYPE_TEXT`) has been definitively removed in favor of `ChatMessageType` enum constants.*
