// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// NoteRepository Provider - 数据层
/// 提供 Isar 的具体实现

@ProviderFor(noteRepository)
const noteRepositoryProvider = NoteRepositoryProvider._();

/// NoteRepository Provider - 数据层
/// 提供 Isar 的具体实现

final class NoteRepositoryProvider
    extends
        $FunctionalProvider<
          IsarNoteRepository,
          IsarNoteRepository,
          IsarNoteRepository
        >
    with $Provider<IsarNoteRepository> {
  /// NoteRepository Provider - 数据层
  /// 提供 Isar 的具体实现
  const NoteRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'noteRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$noteRepositoryHash();

  @$internal
  @override
  $ProviderElement<IsarNoteRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IsarNoteRepository create(Ref ref) {
    return noteRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IsarNoteRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IsarNoteRepository>(value),
    );
  }
}

String _$noteRepositoryHash() => r'2230305745bfbe04e0c422da4f823e2d777bb3cb';

/// MetadataManager Provider - 业务层
/// 负责链接元数据解析和图片本地化

@ProviderFor(metadataManager)
const metadataManagerProvider = MetadataManagerProvider._();

/// MetadataManager Provider - 业务层
/// 负责链接元数据解析和图片本地化

final class MetadataManagerProvider
    extends
        $FunctionalProvider<MetadataManager, MetadataManager, MetadataManager>
    with $Provider<MetadataManager> {
  /// MetadataManager Provider - 业务层
  /// 负责链接元数据解析和图片本地化
  const MetadataManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'metadataManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$metadataManagerHash();

  @$internal
  @override
  $ProviderElement<MetadataManager> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MetadataManager create(Ref ref) {
    return metadataManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MetadataManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MetadataManager>(value),
    );
  }
}

String _$metadataManagerHash() => r'41e4b0265968f29432728b69f9403255f8f6ff71';

/// NoteService Provider - 业务层

@ProviderFor(noteService)
const noteServiceProvider = NoteServiceProvider._();

/// NoteService Provider - 业务层

final class NoteServiceProvider
    extends $FunctionalProvider<NoteService, NoteService, NoteService>
    with $Provider<NoteService> {
  /// NoteService Provider - 业务层
  const NoteServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'noteServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$noteServiceHash();

  @$internal
  @override
  $ProviderElement<NoteService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NoteService create(Ref ref) {
    return noteService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NoteService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NoteService>(value),
    );
  }
}

String _$noteServiceHash() => r'96de4e37cb5321144fe987d7953ebc2f2201421b';

/// 搜索查询 Provider - 用于管理当前搜索关键词

@ProviderFor(SearchQuery)
const searchQueryProvider = SearchQueryProvider._();

/// 搜索查询 Provider - 用于管理当前搜索关键词
final class SearchQueryProvider
    extends $NotifierProvider<SearchQuery, String?> {
  /// 搜索查询 Provider - 用于管理当前搜索关键词
  const SearchQueryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchQueryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchQueryHash();

  @$internal
  @override
  SearchQuery create() => SearchQuery();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$searchQueryHash() => r'682eaf558bae7ed6cf1fb423cb5832de0a760e2d';

/// 搜索查询 Provider - 用于管理当前搜索关键词

abstract class _$SearchQuery extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// 搜索结果 Provider - 根据搜索查询返回结果

@ProviderFor(searchResults)
const searchResultsProvider = SearchResultsProvider._();

/// 搜索结果 Provider - 根据搜索查询返回结果

final class SearchResultsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Note>>,
          List<Note>,
          Stream<List<Note>>
        >
    with $FutureModifier<List<Note>>, $StreamProvider<List<Note>> {
  /// 搜索结果 Provider - 根据搜索查询返回结果
  const SearchResultsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchResultsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchResultsHash();

  @$internal
  @override
  $StreamProviderElement<List<Note>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Note>> create(Ref ref) {
    return searchResults(ref);
  }
}

String _$searchResultsHash() => r'850c9dcc518a7ebb0f47a85325ac93481d57f499';

/// 所有笔记的 Stream Provider

@ProviderFor(allNotes)
const allNotesProvider = AllNotesProvider._();

/// 所有笔记的 Stream Provider

final class AllNotesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Note>>,
          List<Note>,
          Stream<List<Note>>
        >
    with $FutureModifier<List<Note>>, $StreamProvider<List<Note>> {
  /// 所有笔记的 Stream Provider
  const AllNotesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allNotesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allNotesHash();

  @$internal
  @override
  $StreamProviderElement<List<Note>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Note>> create(Ref ref) {
    return allNotes(ref);
  }
}

String _$allNotesHash() => r'b56a84aab596f41c7ffcc4baf7f26f1cbac05f87';

/// 根据 ID 获取笔记的 Provider

@ProviderFor(noteById)
const noteByIdProvider = NoteByIdFamily._();

/// 根据 ID 获取笔记的 Provider

final class NoteByIdProvider
    extends $FunctionalProvider<AsyncValue<Note?>, Note?, FutureOr<Note?>>
    with $FutureModifier<Note?>, $FutureProvider<Note?> {
  /// 根据 ID 获取笔记的 Provider
  const NoteByIdProvider._({
    required NoteByIdFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'noteByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$noteByIdHash();

  @override
  String toString() {
    return r'noteByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Note?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Note?> create(Ref ref) {
    final argument = this.argument as int;
    return noteById(ref, id: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NoteByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$noteByIdHash() => r'c39dc317a25b4f68f402da35e01eb8176e2721d4';

/// 根据 ID 获取笔记的 Provider

final class NoteByIdFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Note?>, int> {
  const NoteByIdFamily._()
    : super(
        retry: null,
        name: r'noteByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 根据 ID 获取笔记的 Provider

  NoteByIdProvider call({required int id}) =>
      NoteByIdProvider._(argument: id, from: this);

  @override
  String toString() => r'noteByIdProvider';
}

/// 桌面端当前选中的笔记 Provider
/// 用于桌面端详情面板显示

@ProviderFor(SelectedNote)
const selectedNoteProvider = SelectedNoteProvider._();

/// 桌面端当前选中的笔记 Provider
/// 用于桌面端详情面板显示
final class SelectedNoteProvider
    extends $NotifierProvider<SelectedNote, Note?> {
  /// 桌面端当前选中的笔记 Provider
  /// 用于桌面端详情面板显示
  const SelectedNoteProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedNoteProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedNoteHash();

  @$internal
  @override
  SelectedNote create() => SelectedNote();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Note? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Note?>(value),
    );
  }
}

String _$selectedNoteHash() => r'4eb503b03c287682adcace9ef7a7e331a2fe9209';

/// 桌面端当前选中的笔记 Provider
/// 用于桌面端详情面板显示

abstract class _$SelectedNote extends $Notifier<Note?> {
  Note? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Note?, Note?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Note?, Note?>,
              Note?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// 根据分类获取笔记的 StreamNotifier

@ProviderFor(NoteByCategory)
const noteByCategoryProvider = NoteByCategoryProvider._();

/// 根据分类获取笔记的 StreamNotifier
final class NoteByCategoryProvider
    extends $StreamNotifierProvider<NoteByCategory, List<Note>> {
  /// 根据分类获取笔记的 StreamNotifier
  const NoteByCategoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'noteByCategoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$noteByCategoryHash();

  @$internal
  @override
  NoteByCategory create() => NoteByCategory();
}

String _$noteByCategoryHash() => r'ff4f68c901927a9d99304dbb5e632d24191ff235';

/// 根据分类获取笔记的 StreamNotifier

abstract class _$NoteByCategory extends $StreamNotifier<List<Note>> {
  Stream<List<Note>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<List<Note>>, List<Note>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Note>>, List<Note>>,
              AsyncValue<List<Note>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(NoteDetail)
const noteDetailProvider = NoteDetailFamily._();

final class NoteDetailProvider
    extends $NotifierProvider<NoteDetail, NoteDetailState> {
  const NoteDetailProvider._({
    required NoteDetailFamily super.from,
    required Note super.argument,
  }) : super(
         retry: null,
         name: r'noteDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$noteDetailHash();

  @override
  String toString() {
    return r'noteDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  NoteDetail create() => NoteDetail();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NoteDetailState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NoteDetailState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NoteDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$noteDetailHash() => r'1f39d787e319f977f54fcd0a30aa9430d46148d8';

final class NoteDetailFamily extends $Family
    with
        $ClassFamilyOverride<
          NoteDetail,
          NoteDetailState,
          NoteDetailState,
          NoteDetailState,
          Note
        > {
  const NoteDetailFamily._()
    : super(
        retry: null,
        name: r'noteDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  NoteDetailProvider call(Note initialNote) =>
      NoteDetailProvider._(argument: initialNote, from: this);

  @override
  String toString() => r'noteDetailProvider';
}

abstract class _$NoteDetail extends $Notifier<NoteDetailState> {
  late final _$args = ref.$arg as Note;
  Note get initialNote => _$args;

  NoteDetailState build(Note initialNote);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<NoteDetailState, NoteDetailState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<NoteDetailState, NoteDetailState>,
              NoteDetailState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
