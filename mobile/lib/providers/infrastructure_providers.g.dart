// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'infrastructure_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Isar 实例 Provider

@ProviderFor(isar)
const isarProvider = IsarProvider._();

/// Isar 实例 Provider

final class IsarProvider extends $FunctionalProvider<Isar, Isar, Isar>
    with $Provider<Isar> {
  /// Isar 实例 Provider
  const IsarProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isarProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isarHash();

  @$internal
  @override
  $ProviderElement<Isar> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Isar create(Ref ref) {
    return isar(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Isar value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Isar>(value),
    );
  }
}

String _$isarHash() => r'5f3220dde9aa343ef5304b38372711b8b131605e';

/// 通知服务 Provider - 全局单例

@ProviderFor(notificationService)
const notificationServiceProvider = NotificationServiceProvider._();

/// 通知服务 Provider - 全局单例

final class NotificationServiceProvider
    extends
        $FunctionalProvider<
          NotificationService,
          NotificationService,
          NotificationService
        >
    with $Provider<NotificationService> {
  /// 通知服务 Provider - 全局单例
  const NotificationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationServiceHash();

  @$internal
  @override
  $ProviderElement<NotificationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationService create(Ref ref) {
    return notificationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationService>(value),
    );
  }
}

String _$notificationServiceHash() =>
    r'58da87941dbfa08925105dcc4d74091ee38c8593';

/// 平台爬虫服务 Provider - 全局单例

@ProviderFor(platformScraperService)
const platformScraperServiceProvider = PlatformScraperServiceProvider._();

/// 平台爬虫服务 Provider - 全局单例

final class PlatformScraperServiceProvider
    extends
        $FunctionalProvider<
          PlatformScraperService,
          PlatformScraperService,
          PlatformScraperService
        >
    with $Provider<PlatformScraperService> {
  /// 平台爬虫服务 Provider - 全局单例
  const PlatformScraperServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'platformScraperServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$platformScraperServiceHash();

  @$internal
  @override
  $ProviderElement<PlatformScraperService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PlatformScraperService create(Ref ref) {
    return platformScraperService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlatformScraperService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlatformScraperService>(value),
    );
  }
}

String _$platformScraperServiceHash() =>
    r'5e7800db8e1ca05c99cb3f2c9c65d2c4388f8bc7';
