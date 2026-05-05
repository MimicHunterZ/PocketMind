import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketmind/core/constants.dart';

part 'app_config_state.freezed.dart';
part 'app_config_state.g.dart';

/// AppConfig 状态类
@freezed
abstract class AppConfigState with _$AppConfigState {
  const AppConfigState._();

  const factory AppConfigState({
    @Default(false) bool proxyEnabled,
    @Default(AppConstants.defaultProxyHost) String proxyHost,
    @Default(AppConstants.defaultProxyPort) int proxyPort,
    @Default(AppConstants.defaultMetaCacheTimeDays) int metaCacheTime,
    @Default(false) bool titleEnabled,
    @Default(true) bool waterfallLayoutEnabled,
    @Default(false) bool syncAutoStart,
    @Default([]) List<Map<String, String>> reminderShortcuts,
    @Default(false) bool highPrecisionNotification,
    @Default('') String linkPreviewApiKey,
    @Default('') String customDomain,
  }) = _AppConfigState;

  /// 从 JSON 创建实例
  factory AppConfigState.fromJson(Map<String, dynamic> json) =>
      _$AppConfigStateFromJson(json);

  /// 获取 API 基础 URL（即用户配置的服务器地址）
  String get baseUrl => customDomain;

  /// 是否已配置服务器地址
  bool get isServerConfigured => customDomain.isNotEmpty;
}
