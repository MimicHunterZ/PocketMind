import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketmind/core/constants.dart';

part 'app_config_state.freezed.dart';
part 'app_config_state.g.dart';

/// 环境枚举
enum Environment {
  /// 开发环境（本地）
  development,

  /// 预发布环境
  staging,

  /// 生产环境
  production,
}

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
    @Default(Environment.development) Environment environment,
  }) = _AppConfigState;

  /// 从 JSON 创建实例
  factory AppConfigState.fromJson(Map<String, dynamic> json) =>
      _$AppConfigStateFromJson(json);

  /// 获取 API 基础 URL
  String get baseUrl {
    if (customDomain.isNotEmpty) {
      return customDomain;
    }
    switch (environment) {
      case Environment.development:
        return 'http://localhost:8080';
      case Environment.staging:
        return ''; // 预发布环境，可按需修改
      case Environment.production:
        return 'https://pocketmind.doublez-area.online';
    }
  }

  /// 是否为开发环境
  bool get isDevelopment => environment == Environment.development;

  /// 是否为生产环境
  bool get isProduction => environment == Environment.production;
}
