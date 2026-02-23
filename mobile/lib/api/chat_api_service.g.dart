// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_api_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ChatApiService Provider

@ProviderFor(chatApiService)
const chatApiServiceProvider = ChatApiServiceProvider._();

/// ChatApiService Provider

final class ChatApiServiceProvider
    extends $FunctionalProvider<ChatApiService, ChatApiService, ChatApiService>
    with $Provider<ChatApiService> {
  /// ChatApiService Provider
  const ChatApiServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatApiServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatApiServiceHash();

  @$internal
  @override
  $ProviderElement<ChatApiService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ChatApiService create(Ref ref) {
    return chatApiService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatApiService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatApiService>(value),
    );
  }
}

String _$chatApiServiceHash() => r'1bcb8b5fd370f0cd72e2367f352e584d64ddf2b7';
