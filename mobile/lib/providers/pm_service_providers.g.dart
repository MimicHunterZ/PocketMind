// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pm_service_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(authPmService)
const authPmServiceProvider = AuthPmServiceProvider._();

final class AuthPmServiceProvider
    extends $FunctionalProvider<AuthPmService, AuthPmService, AuthPmService>
    with $Provider<AuthPmService> {
  const AuthPmServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authPmServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authPmServiceHash();

  @$internal
  @override
  $ProviderElement<AuthPmService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthPmService create(Ref ref) {
    return authPmService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthPmService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthPmService>(value),
    );
  }
}

String _$authPmServiceHash() => r'57e4d0c58920f35c272fae8bf4885ce4202cefe5';

@ProviderFor(assetApiService)
const assetApiServiceProvider = AssetApiServiceProvider._();

final class AssetApiServiceProvider
    extends
        $FunctionalProvider<AssetApiService, AssetApiService, AssetApiService>
    with $Provider<AssetApiService> {
  const AssetApiServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assetApiServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assetApiServiceHash();

  @$internal
  @override
  $ProviderElement<AssetApiService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AssetApiService create(Ref ref) {
    return assetApiService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AssetApiService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AssetApiService>(value),
    );
  }
}

String _$assetApiServiceHash() => r'6dc4b55333a7d2ccf8a8cb00191b2106f28cd492';

@ProviderFor(postDetailService)
const postDetailServiceProvider = PostDetailServiceProvider._();

final class PostDetailServiceProvider
    extends
        $FunctionalProvider<
          PostDetailService,
          PostDetailService,
          PostDetailService
        >
    with $Provider<PostDetailService> {
  const PostDetailServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'postDetailServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$postDetailServiceHash();

  @$internal
  @override
  $ProviderElement<PostDetailService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PostDetailService create(Ref ref) {
    return postDetailService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PostDetailService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PostDetailService>(value),
    );
  }
}

String _$postDetailServiceHash() => r'6ce3400c0f34c72f3df0f863b65a4eec9d18bf95';

@ProviderFor(aiPollingService)
const aiPollingServiceProvider = AiPollingServiceProvider._();

final class AiPollingServiceProvider
    extends
        $FunctionalProvider<
          AiPollingService,
          AiPollingService,
          AiPollingService
        >
    with $Provider<AiPollingService> {
  const AiPollingServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiPollingServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiPollingServiceHash();

  @$internal
  @override
  $ProviderElement<AiPollingService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AiPollingService create(Ref ref) {
    return aiPollingService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiPollingService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiPollingService>(value),
    );
  }
}

String _$aiPollingServiceHash() => r'dc1b22406324c4710eefc91aaa2b105f61cbdd99';
