// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppConfigState _$AppConfigStateFromJson(Map<String, dynamic> json) =>
    _AppConfigState(
      proxyEnabled: json['proxyEnabled'] as bool? ?? false,
      proxyHost: json['proxyHost'] as String? ?? AppConstants.defaultProxyHost,
      proxyPort:
          (json['proxyPort'] as num?)?.toInt() ?? AppConstants.defaultProxyPort,
      metaCacheTime:
          (json['metaCacheTime'] as num?)?.toInt() ??
          AppConstants.defaultMetaCacheTimeDays,
      titleEnabled: json['titleEnabled'] as bool? ?? false,
      waterfallLayoutEnabled: json['waterfallLayoutEnabled'] as bool? ?? true,
      syncAutoStart: json['syncAutoStart'] as bool? ?? false,
      reminderShortcuts:
          (json['reminderShortcuts'] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e as Map))
              .toList() ??
          const [],
      highPrecisionNotification:
          json['highPrecisionNotification'] as bool? ?? false,
      linkPreviewApiKey: json['linkPreviewApiKey'] as String? ?? '',
      customDomain: json['customDomain'] as String? ?? '',
      environment:
          $enumDecodeNullable(_$EnvironmentEnumMap, json['environment']) ??
          Environment.development,
    );

Map<String, dynamic> _$AppConfigStateToJson(_AppConfigState instance) =>
    <String, dynamic>{
      'proxyEnabled': instance.proxyEnabled,
      'proxyHost': instance.proxyHost,
      'proxyPort': instance.proxyPort,
      'metaCacheTime': instance.metaCacheTime,
      'titleEnabled': instance.titleEnabled,
      'waterfallLayoutEnabled': instance.waterfallLayoutEnabled,
      'syncAutoStart': instance.syncAutoStart,
      'reminderShortcuts': instance.reminderShortcuts,
      'highPrecisionNotification': instance.highPrecisionNotification,
      'linkPreviewApiKey': instance.linkPreviewApiKey,
      'customDomain': instance.customDomain,
      'environment': _$EnvironmentEnumMap[instance.environment]!,
    };

const _$EnvironmentEnumMap = {
  Environment.development: 'development',
  Environment.staging: 'staging',
  Environment.production: 'production',
};
