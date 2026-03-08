// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// IsarCategoryRepository Provider

@ProviderFor(categoryRepository)
const categoryRepositoryProvider = CategoryRepositoryProvider._();

/// IsarCategoryRepository Provider

final class CategoryRepositoryProvider
    extends
        $FunctionalProvider<
          IsarCategoryRepository,
          IsarCategoryRepository,
          IsarCategoryRepository
        >
    with $Provider<IsarCategoryRepository> {
  /// IsarCategoryRepository Provider
  const CategoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryRepositoryHash();

  @$internal
  @override
  $ProviderElement<IsarCategoryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IsarCategoryRepository create(Ref ref) {
    return categoryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IsarCategoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IsarCategoryRepository>(value),
    );
  }
}

String _$categoryRepositoryHash() =>
    r'b4fc8616d983e738a7baebaa5846e55848f9ef0f';

/// SyncApiService Provider

@ProviderFor(syncApiService)
const syncApiServiceProvider = SyncApiServiceProvider._();

/// SyncApiService Provider

final class SyncApiServiceProvider
    extends $FunctionalProvider<SyncApiService, SyncApiService, SyncApiService>
    with $Provider<SyncApiService> {
  /// SyncApiService Provider
  const SyncApiServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncApiServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncApiServiceHash();

  @$internal
  @override
  $ProviderElement<SyncApiService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncApiService create(Ref ref) {
    return syncApiService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncApiService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncApiService>(value),
    );
  }
}

String _$syncApiServiceHash() => r'6b4b353fafd7bef03b685b42f3deab8983f7a010';

/// LocalWriteCoordinator Provider —— 所有业务写操作的原子双写入口

@ProviderFor(localWriteCoordinator)
const localWriteCoordinatorProvider = LocalWriteCoordinatorProvider._();

/// LocalWriteCoordinator Provider —— 所有业务写操作的原子双写入口

final class LocalWriteCoordinatorProvider
    extends
        $FunctionalProvider<
          LocalWriteCoordinator,
          LocalWriteCoordinator,
          LocalWriteCoordinator
        >
    with $Provider<LocalWriteCoordinator> {
  /// LocalWriteCoordinator Provider —— 所有业务写操作的原子双写入口
  const LocalWriteCoordinatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localWriteCoordinatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localWriteCoordinatorHash();

  @$internal
  @override
  $ProviderElement<LocalWriteCoordinator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LocalWriteCoordinator create(Ref ref) {
    return localWriteCoordinator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalWriteCoordinator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalWriteCoordinator>(value),
    );
  }
}

String _$localWriteCoordinatorHash() =>
    r'75c8cc6c57e494ac6bef7196be3a9a0c83fef84e';

/// PullCoordinator Provider

@ProviderFor(pullCoordinator)
const pullCoordinatorProvider = PullCoordinatorProvider._();

/// PullCoordinator Provider

final class PullCoordinatorProvider
    extends
        $FunctionalProvider<PullCoordinator, PullCoordinator, PullCoordinator>
    with $Provider<PullCoordinator> {
  /// PullCoordinator Provider
  const PullCoordinatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pullCoordinatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pullCoordinatorHash();

  @$internal
  @override
  $ProviderElement<PullCoordinator> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PullCoordinator create(Ref ref) {
    return pullCoordinator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PullCoordinator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PullCoordinator>(value),
    );
  }
}

String _$pullCoordinatorHash() => r'5574dd30c3dc03fa4e97a30f395e2433cacfe5af';

/// PushCoordinator Provider

@ProviderFor(pushCoordinator)
const pushCoordinatorProvider = PushCoordinatorProvider._();

/// PushCoordinator Provider

final class PushCoordinatorProvider
    extends
        $FunctionalProvider<PushCoordinator, PushCoordinator, PushCoordinator>
    with $Provider<PushCoordinator> {
  /// PushCoordinator Provider
  const PushCoordinatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushCoordinatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushCoordinatorHash();

  @$internal
  @override
  $ProviderElement<PushCoordinator> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PushCoordinator create(Ref ref) {
    return pushCoordinator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushCoordinator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushCoordinator>(value),
    );
  }
}

String _$pushCoordinatorHash() => r'5ac6a833442235d3548b65c909eadf8a90d9446d';

/// SyncEngine Provider 鈥斺€?鍚屾寮曟搸鍞竴瀹炰緥

@ProviderFor(syncEngine)
const syncEngineProvider = SyncEngineProvider._();

/// SyncEngine Provider 鈥斺€?鍚屾寮曟搸鍞竴瀹炰緥

final class SyncEngineProvider
    extends $FunctionalProvider<SyncEngine, SyncEngine, SyncEngine>
    with $Provider<SyncEngine> {
  /// SyncEngine Provider 鈥斺€?鍚屾寮曟搸鍞竴瀹炰緥
  const SyncEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncEngineHash();

  @$internal
  @override
  $ProviderElement<SyncEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncEngine create(Ref ref) {
    return syncEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncEngine>(value),
    );
  }
}

String _$syncEngineHash() => r'48a5dfd85082a7b6886eefc94d3d97110e8f5251';

/// ResourceFetchScheduler Provider 鈥斺€?绔晶鍏冩暟鎹姄鍙栬皟搴﹀櫒

@ProviderFor(resourceFetchScheduler)
const resourceFetchSchedulerProvider = ResourceFetchSchedulerProvider._();

/// ResourceFetchScheduler Provider 鈥斺€?绔晶鍏冩暟鎹姄鍙栬皟搴﹀櫒

final class ResourceFetchSchedulerProvider
    extends
        $FunctionalProvider<
          ResourceFetchScheduler,
          ResourceFetchScheduler,
          ResourceFetchScheduler
        >
    with $Provider<ResourceFetchScheduler> {
  /// ResourceFetchScheduler Provider 鈥斺€?绔晶鍏冩暟鎹姄鍙栬皟搴﹀櫒
  const ResourceFetchSchedulerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'resourceFetchSchedulerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$resourceFetchSchedulerHash();

  @$internal
  @override
  $ProviderElement<ResourceFetchScheduler> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ResourceFetchScheduler create(Ref ref) {
    return resourceFetchScheduler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ResourceFetchScheduler value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ResourceFetchScheduler>(value),
    );
  }
}

String _$resourceFetchSchedulerHash() =>
    r'9a2d3649844ef2a46804f2ee9a59890fa5a2d127';

/// 鑷€傚簲杞 Provider 鈥斺€?鏍规嵁搴旂敤鐘舵€佽嚜鍔ㄨ皟鏁?Pull 闂撮殧銆?
///
/// 绛栫暐锛?
/// - 鐧诲綍鐘舵€佷笅姣?30 绉掕Е鍙戜竴娆?SyncEngine.kick()
/// - 缃戠粶鐘舵€佸彉鍖栨椂绔嬪嵆瑙﹀彂涓€娆?
/// - 姝?Provider keepAlive锛孉pp 鐢熷懡鍛ㄦ湡鍐呮寔缁繍琛?

@ProviderFor(adaptiveSyncScheduler)
const adaptiveSyncSchedulerProvider = AdaptiveSyncSchedulerProvider._();

/// 鑷€傚簲杞 Provider 鈥斺€?鏍规嵁搴旂敤鐘舵€佽嚜鍔ㄨ皟鏁?Pull 闂撮殧銆?
///
/// 绛栫暐锛?
/// - 鐧诲綍鐘舵€佷笅姣?30 绉掕Е鍙戜竴娆?SyncEngine.kick()
/// - 缃戠粶鐘舵€佸彉鍖栨椂绔嬪嵆瑙﹀彂涓€娆?
/// - 姝?Provider keepAlive锛孉pp 鐢熷懡鍛ㄦ湡鍐呮寔缁繍琛?

final class AdaptiveSyncSchedulerProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// 鑷€傚簲杞 Provider 鈥斺€?鏍规嵁搴旂敤鐘舵€佽嚜鍔ㄨ皟鏁?Pull 闂撮殧銆?
  ///
  /// 绛栫暐锛?
  /// - 鐧诲綍鐘舵€佷笅姣?30 绉掕Е鍙戜竴娆?SyncEngine.kick()
  /// - 缃戠粶鐘舵€佸彉鍖栨椂绔嬪嵆瑙﹀彂涓€娆?
  /// - 姝?Provider keepAlive锛孉pp 鐢熷懡鍛ㄦ湡鍐呮寔缁繍琛?
  const AdaptiveSyncSchedulerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adaptiveSyncSchedulerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adaptiveSyncSchedulerHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return adaptiveSyncScheduler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$adaptiveSyncSchedulerHash() =>
    r'fecba4fb28fc5967e18035e6c4ac9f016454142e';
