// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 同步状态 Provider，供 SyncEngine 更新，UI 读取
/// 同步状态 Provider，SyncEngine直接调用其方法更新状态，UI 读取即可。

@ProviderFor(SyncStateNotifier)
const syncStateProvider = SyncStateNotifierProvider._();

/// 同步状态 Provider，供 SyncEngine 更新，UI 读取
/// 同步状态 Provider，SyncEngine直接调用其方法更新状态，UI 读取即可。
final class SyncStateNotifierProvider
    extends $NotifierProvider<SyncStateNotifier, SyncState> {
  /// 同步状态 Provider，供 SyncEngine 更新，UI 读取
  /// 同步状态 Provider，SyncEngine直接调用其方法更新状态，UI 读取即可。
  const SyncStateNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncStateNotifierHash();

  @$internal
  @override
  SyncStateNotifier create() => SyncStateNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncState>(value),
    );
  }
}

String _$syncStateNotifierHash() => r'0934d87e39994f27e37e6573f6a163de1a406fbe';

/// 同步状态 Provider，供 SyncEngine 更新，UI 读取
/// 同步状态 Provider，SyncEngine直接调用其方法更新状态，UI 读取即可。

abstract class _$SyncStateNotifier extends $Notifier<SyncState> {
  SyncState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<SyncState, SyncState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SyncState, SyncState>,
              SyncState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// 仅暴露“是否处于首次拉取”派生状态，供 UI 做最小粒度监听。

@ProviderFor(syncIsInitialPull)
const syncIsInitialPullProvider = SyncIsInitialPullProvider._();

/// 仅暴露“是否处于首次拉取”派生状态，供 UI 做最小粒度监听。

final class SyncIsInitialPullProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// 仅暴露“是否处于首次拉取”派生状态，供 UI 做最小粒度监听。
  const SyncIsInitialPullProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncIsInitialPullProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncIsInitialPullHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return syncIsInitialPull(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$syncIsInitialPullHash() => r'90f861996664c17d5a217117ce3089b9cc210ae4';

/// 仅暴露“是否正在同步”派生状态，避免无关字段变更触发整块 UI 重建。

@ProviderFor(syncIsSyncing)
const syncIsSyncingProvider = SyncIsSyncingProvider._();

/// 仅暴露“是否正在同步”派生状态，避免无关字段变更触发整块 UI 重建。

final class SyncIsSyncingProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// 仅暴露“是否正在同步”派生状态，避免无关字段变更触发整块 UI 重建。
  const SyncIsSyncingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncIsSyncingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncIsSyncingHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return syncIsSyncing(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$syncIsSyncingHash() => r'f45995855f2db791bf9e40b09572e1d3a2033a30';
