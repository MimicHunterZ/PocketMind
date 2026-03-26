import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/data/repositories/isar_note_repository.dart';
import 'package:pocketmind/data/repositories/isar_note_asset_repository.dart';
import 'package:pocketmind/model/note_asset.dart';
import 'package:pocketmind/providers/nav_providers.dart';
import 'package:pocketmind/providers/infrastructure_providers.dart';
import 'package:pocketmind/service/note_service.dart';
import 'package:pocketmind/providers/sync_providers.dart';
import 'package:pocketmind/sync/sync_state_provider.dart';
import 'package:pocketmind/providers/shared_preferences_provider.dart';
import 'package:pocketmind/service/metadata_manager.dart';
import 'package:pocketmind/api/link_preview_api_service.dart';

import '../util/logger_service.dart';

part 'note_providers.freezed.dart';
part 'note_providers.g.dart';

/// NoteRepository Provider - 数据层
/// 提供 Isar 的具体实现
@Riverpod(keepAlive: true)
IsarNoteRepository noteRepository(Ref ref) {
  final isar = ref.watch(isarProvider);
  return IsarNoteRepository(isar);
}

/// NoteAssetRepository Provider
@Riverpod(keepAlive: true)
IsarNoteAssetRepository noteAssetRepository(Ref ref) {
  final isar = ref.watch(isarProvider);
  return IsarNoteAssetRepository(isar);
}

/// 查询指定笔记下所有资产实时流（携带尺寸信息供画廊使用）
@riverpod
Stream<List<NoteAsset>> noteAssetImages(Ref ref, String noteUuid) {
  if (noteUuid.isEmpty) return Stream.value([]);
  return ref.watch(noteAssetRepositoryProvider).watchByNoteUuid(noteUuid);
}

/// MetadataManager Provider - 业务层
/// 负责链接元数据解析和图片本地化
@Riverpod(keepAlive: true)
MetadataManager metadataManager(Ref ref) {
  final apiService = ref.watch(linkPreviewServiceProvider);
  final platformScraperService = ref.watch(platformScraperServiceProvider);
  return MetadataManager(
    linkPreviewApi: apiService,
    platformScraperService: platformScraperService,
  );
}

/// NoteService Provider - 业务层
@Riverpod(keepAlive: true)
NoteService noteService(Ref ref) {
  final repository = ref.watch(noteRepositoryProvider);
  final writeCoordinator = ref.watch(localWriteCoordinatorProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return NoteService(
    noteRepository: repository,
    writeCoordinator: writeCoordinator,
    syncEngine: syncEngine,
    prefs: prefs,
  );
}

/// 搜索查询 Provider - 用于管理当前搜索关键词
@riverpod
class SearchQuery extends _$SearchQuery {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

/// 搜索结果 Provider - 根据搜索查询返回结果
@riverpod
Stream<List<Note>> searchResults(Ref ref) {
  final query = ref.watch(searchQueryProvider);
  if (query == null || query.isEmpty) {
    return Stream.value([]);
  }
  final noteService = ref.watch(noteServiceProvider);
  return noteService.findNotesWithQuery(query);
}

/// 所有笔记的 Stream Provider
@riverpod
Stream<List<Note>> allNotes(Ref ref) {
  final noteService = ref.watch(noteServiceProvider);
  return noteService.watchAllNotes();
}

/// 根据 ID 获取笔记的 Provider
@riverpod
Future<Note?> noteById(Ref ref, {required int id}) async {
  final noteService = ref.watch(noteServiceProvider);
  return noteService.getNoteById(id);
}

/// 桌面端当前选中的笔记 Provider
/// 用于桌面端详情面板显示
@riverpod
class SelectedNote extends _$SelectedNote {
  @override
  Note? build() => null;

  void set(Note? value) => state = value;
}

/// 根据分类获取笔记的 StreamNotifier
@riverpod
class NoteByCategory extends _$NoteByCategory {
  /// build 方法返回 Stream，自动监听数据库变化
  @override
  Stream<List<Note>> build() async* {
    final noteService = ref.watch(noteServiceProvider);
    final isInitialPull = ref.watch(syncIsInitialPullProvider);
    final targetCategoryId = await ref.watch(activeCategoryIdProvider.future);

    PMlog.d('activeIndex', 'targetCategoryId: $targetCategoryId');

    // initialPull 阶段：本地库可能为空，先冻结输出为空列表
    // UI 层根据 syncStateProvider.isInitialPull 显示骨架屏
    // 暂不订阅 Isar Watch，避免全量写入期间 Widget 高频重绘
    if (isInitialPull) {
      yield const <Note>[];
      return;
    }

    yield* noteService.watchCategoryNotes(targetCategoryId);
  }

  /// 删除笔记
  Future<void> deleteNote(int noteId) async {
    try {
      // 直接删除，watchCategoryNotes() 的 Stream 会自动更新 UI
      await ref.read(noteServiceProvider).deleteNote(noteId);
    } catch (e) {
      // 可以在这里处理错误，比如显示 SnackBar
      rethrow;
    }
  }
}

@freezed
abstract class NoteDetailState with _$NoteDetailState {
  const factory NoteDetailState({
    required Note note,
    @Default(false) bool isLoading,
    @Default([]) List<String> tags,
    @Default(false) bool isSaving,
    Object? error,
  }) = _NoteDetailState;
}

@riverpod
class NoteDetail extends _$NoteDetail {
  Timer? _debounceTimer;
  static const _tag = 'NoteDetailNotifier';
  Note? _lastSavedNote;

  @override
  NoteDetailState build(Note initialNote) {
    _lastSavedNote = initialNote;
    final tags = List<String>.from(initialNote.tags);
    return NoteDetailState(note: initialNote, tags: tags);
  }

  /// 更新笔记内容（带防抖保存）
  void updateNote({
    String? title,
    String? content,
    int? categoryId,
    List<String>? tags,
  }) {
    final nextTitle = title ?? state.note.title;
    final nextContent = content ?? state.note.content;
    final nextCategoryId = categoryId ?? state.note.categoryId;
    final nextTags = tags ?? state.note.tags;
    if (_isSameEdit(
      state.note,
      nextTitle,
      nextContent,
      nextCategoryId,
      nextTags,
    )) {
      return;
    }

    final updatedNote = state.note.copyWith(
      title: nextTitle,
      content: nextContent,
      categoryId: nextCategoryId,
      tags: nextTags,
    );

    state = state.copyWith(note: updatedNote, tags: nextTags);
    _debounceSave();
  }

  void addTag(String tag) {
    if (tag.isEmpty || state.tags.contains(tag)) return;
    updateNote(tags: [...state.tags, tag]);
  }

  void removeTag(String tag) {
    updateNote(tags: state.tags.where((t) => t != tag).toList());
  }

  void updateCategory(int categoryId) {
    updateNote(categoryId: categoryId);
  }

  /// 防抖保存逻辑
  void _debounceSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () => saveNote());
  }

  Future<void> saveNote() async {
    if (state.isSaving || state.note.id == null) return;
    if (_lastSavedNote != null &&
        _isEquivalentForSave(state.note, _lastSavedNote!)) {
      return;
    }

    state = state.copyWith(isSaving: true);
    try {
      final id = await ref
          .read(noteServiceProvider)
          .updateNote(
            id: state.note.id!,
            title: state.note.title,
            content: state.note.content,
            url: state.note.url,
            categoryId: state.note.categoryId,
            tags: state.note.tags,
            previewTitle: state.note.previewTitle,
            previewDescription: state.note.previewDescription,
          );
      if (ref.mounted) {
        final savedNote = state.note.copyWith(id: id);
        _lastSavedNote = savedNote;
        state = state.copyWith(note: savedNote);
      }
    } catch (e) {
      PMlog.e(_tag, 'Save failed: $e');
      if (ref.mounted) state = state.copyWith(error: e);
    } finally {
      if (ref.mounted) state = state.copyWith(isSaving: false);
    }
  }

  Future<void> deleteNote() async {
    await ref.read(noteServiceProvider).deleteFullNote(state.note);
  }

  // Future<void> loadLinkPreview() async {
  //   if (state.isLoading) return;
  //   state = state.copyWith(isLoading: true);
  //   try {
  //     final updated = await ref
  //         .read(noteServiceProvider)
  //         .enrichNoteWithMetadata(state.note);
  //     if (ref.mounted) state = state.copyWith(note: updated);
  //   } finally {
  //     if (ref.mounted) state = state.copyWith(isLoading: false);
  //   }
  // }

  // Future<void> loadResourceContentIfNeeded() async {
  //   if (state.isLoading) return;
  //   state = state.copyWith(isLoading: true);
  //   try {
  //     final updated = await ref
  //         .read(noteServiceProvider)
  //         .fetchAndPersistResourceContentIfNeeded(state.note);
  //     if (ref.mounted) state = state.copyWith(note: updated);
  //   } finally {
  //     if (ref.mounted) state = state.copyWith(isLoading: false);
  //   }
  // }

  void shareNote(dynamic context) {
    PMlog.d(_tag, 'Sharing note: ${state.note.title}');
  }

  bool _isSameEdit(
    Note current,
    String? title,
    String? content,
    int? categoryId,
    List<String> tags,
  ) {
    return current.title == title &&
        current.content == content &&
        current.categoryId == categoryId &&
        listEquals(current.tags, tags);
  }

  bool _isEquivalentForSave(Note a, Note b) {
    return a.id == b.id &&
        a.title == b.title &&
        a.content == b.content &&
        a.url == b.url &&
        a.categoryId == b.categoryId &&
        a.previewTitle == b.previewTitle &&
        a.previewDescription == b.previewDescription &&
        listEquals(a.tags, b.tags);
  }
}
