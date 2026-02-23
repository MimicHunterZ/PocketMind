// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_api_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 笔记 AI 分析提交服务 Provider

@ProviderFor(noteApiService)
const noteApiServiceProvider = NoteApiServiceProvider._();

/// 笔记 AI 分析提交服务 Provider

final class NoteApiServiceProvider
    extends $FunctionalProvider<NoteApiService, NoteApiService, NoteApiService>
    with $Provider<NoteApiService> {
  /// 笔记 AI 分析提交服务 Provider
  const NoteApiServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'noteApiServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$noteApiServiceHash();

  @$internal
  @override
  $ProviderElement<NoteApiService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NoteApiService create(Ref ref) {
    return noteApiService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NoteApiService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NoteApiService>(value),
    );
  }
}

String _$noteApiServiceHash() => r'413eb141c37874b97b4481136d94b52180eae71a';
