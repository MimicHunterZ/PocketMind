// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scraper_task.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScraperTask _$ScraperTaskFromJson(Map<String, dynamic> json) => ScraperTask(
  noteId: (json['noteId'] as num).toInt(),
  url: json['url'] as String,
  platform: json['platform'] as String,
  status:
      $enumDecodeNullable(_$TaskStatusEnumMap, json['status']) ??
      TaskStatus.pending,
  createdAt: _dateTimeFromJson(json['createdAt'] as String),
  startedAt: _dateTimeFromJsonNullable(json['startedAt'] as String?),
  completedAt: _dateTimeFromJsonNullable(json['completedAt'] as String?),
  errorMessage: json['errorMessage'] as String?,
  retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
  nextRetryAt: _dateTimeFromJsonNullable(json['nextRetryAt'] as String?),
);

Map<String, dynamic> _$ScraperTaskToJson(ScraperTask instance) =>
    <String, dynamic>{
      'noteId': instance.noteId,
      'url': instance.url,
      'platform': instance.platform,
      'status': _$TaskStatusEnumMap[instance.status]!,
      'createdAt': _dateTimeToJson(instance.createdAt),
      'startedAt': _dateTimeToJsonNullable(instance.startedAt),
      'completedAt': _dateTimeToJsonNullable(instance.completedAt),
      'errorMessage': instance.errorMessage,
      'retryCount': instance.retryCount,
      'nextRetryAt': _dateTimeToJsonNullable(instance.nextRetryAt),
    };

const _$TaskStatusEnumMap = {
  TaskStatus.pending: 'pending',
  TaskStatus.running: 'running',
  TaskStatus.completed: 'completed',
  TaskStatus.failed: 'failed',
  TaskStatus.cancelled: 'cancelled',
};
