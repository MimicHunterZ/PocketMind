// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'http_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// HttpClient Provider
///
/// 提供全局单例的 HTTP 客户端，会根据环境配置自动设置 baseUrl

@ProviderFor(httpClient)
const httpClientProvider = HttpClientProvider._();

/// HttpClient Provider
///
/// 提供全局单例的 HTTP 客户端，会根据环境配置自动设置 baseUrl

final class HttpClientProvider
    extends $FunctionalProvider<HttpClient, HttpClient, HttpClient>
    with $Provider<HttpClient> {
  /// HttpClient Provider
  ///
  /// 提供全局单例的 HTTP 客户端，会根据环境配置自动设置 baseUrl
  const HttpClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'httpClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$httpClientHash();

  @$internal
  @override
  $ProviderElement<HttpClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HttpClient create(Ref ref) {
    return httpClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HttpClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HttpClient>(value),
    );
  }
}

String _$httpClientHash() => r'865eefb29639bcb07175ea9eb99a35322418658b';
