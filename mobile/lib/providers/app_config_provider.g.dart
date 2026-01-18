// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AppConfig)
const appConfigProvider = AppConfigProvider._();

final class AppConfigProvider
    extends $NotifierProvider<AppConfig, AppConfigState> {
  const AppConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appConfigHash();

  @$internal
  @override
  AppConfig create() => AppConfig();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppConfigState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppConfigState>(value),
    );
  }
}

String _$appConfigHash() => r'53b005ecd41291468355299b33a56b13ad12bb8f';

abstract class _$AppConfig extends $Notifier<AppConfigState> {
  AppConfigState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AppConfigState, AppConfigState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppConfigState, AppConfigState>,
              AppConfigState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
