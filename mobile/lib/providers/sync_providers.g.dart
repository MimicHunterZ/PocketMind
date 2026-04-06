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

/// SyncEngine Provider —— 同步引擎唯一实例

@ProviderFor(syncEngine)
const syncEngineProvider = SyncEngineProvider._();

/// SyncEngine Provider —— 同步引擎唯一实例

final class SyncEngineProvider
    extends $FunctionalProvider<SyncEngine, SyncEngine, SyncEngine>
    with $Provider<SyncEngine> {
  /// SyncEngine Provider —— 同步引擎唯一实例
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

/// ResourceFetchScheduler Provider —— 端侧元数据抓取调度器

@ProviderFor(resourceFetchScheduler)
const resourceFetchSchedulerProvider = ResourceFetchSchedulerProvider._();

/// ResourceFetchScheduler Provider —— 端侧元数据抓取调度器

final class ResourceFetchSchedulerProvider
    extends
        $FunctionalProvider<
          ResourceFetchScheduler,
          ResourceFetchScheduler,
          ResourceFetchScheduler
        >
    with $Provider<ResourceFetchScheduler> {
  /// ResourceFetchScheduler Provider —— 端侧元数据抓取调度器
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
    r'568d3c83711a159827b60cc07ee637705042c0a8';

/// 自适应轮询 Provider —— 根据应用状态自动调整 Pull 间隔。
///
/// 策略：
/// - 登录状态下每 30 秒触发一次 SyncEngine.kick()
/// - 网络状态变化时立即触发一次
/// - 该 Provider 为 keepAlive，App 生命周期内持续运行

@ProviderFor(adaptiveSyncScheduler)
const adaptiveSyncSchedulerProvider = AdaptiveSyncSchedulerProvider._();

/// 自适应轮询 Provider —— 根据应用状态自动调整 Pull 间隔。
///
/// 策略：
/// - 登录状态下每 30 秒触发一次 SyncEngine.kick()
/// - 网络状态变化时立即触发一次
/// - 该 Provider 为 keepAlive，App 生命周期内持续运行

final class AdaptiveSyncSchedulerProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// 自适应轮询 Provider —— 根据应用状态自动调整 Pull 间隔。
  ///
  /// 策略：
  /// - 登录状态下每 30 秒触发一次 SyncEngine.kick()
  /// - 网络状态变化时立即触发一次
  /// - 该 Provider 为 keepAlive，App 生命周期内持续运行
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
    r'efd019758be0345fe48e05748d1d8f41a612b779';
