// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatSessionModel _$ChatSessionModelFromJson(Map<String, dynamic> json) =>
    ChatSessionModel(
      uuid: json['uuid'] as String,
      scopeNoteUuid: json['scopeNoteUuid'] as String?,
      title: json['title'] as String?,
      updatedAt: (json['updatedAt'] as num).toInt(),
    );

Map<String, dynamic> _$ChatSessionModelToJson(ChatSessionModel instance) =>
    <String, dynamic>{
      'uuid': instance.uuid,
      'scopeNoteUuid': instance.scopeNoteUuid,
      'title': instance.title,
      'updatedAt': instance.updatedAt,
    };

ToolCallData _$ToolCallDataFromJson(Map<String, dynamic> json) => ToolCallData(
  toolCallId: json['toolCallId'] as String?,
  toolName: json['toolName'] as String?,
  arguments: json['arguments'] as String?,
  result: json['result'] as String?,
);

Map<String, dynamic> _$ToolCallDataToJson(ToolCallData instance) =>
    <String, dynamic>{
      'toolCallId': instance.toolCallId,
      'toolName': instance.toolName,
      'arguments': instance.arguments,
      'result': instance.result,
    };

ChatMessageModel _$ChatMessageModelFromJson(Map<String, dynamic> json) =>
    ChatMessageModel(
      uuid: json['uuid'] as String,
      sessionUuid: json['sessionUuid'] as String,
      parentUuid: json['parentUuid'] as String?,
      role: json['role'] as String,
      messageType: json['messageType'] as String,
      content: json['content'] as String,
      attachmentUuids: (json['attachmentUuids'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      createdAt: (json['createdAt'] as num).toInt(),
      toolData: json['toolData'] == null
          ? null
          : ToolCallData.fromJson(json['toolData'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ChatMessageModelToJson(ChatMessageModel instance) =>
    <String, dynamic>{
      'uuid': instance.uuid,
      'sessionUuid': instance.sessionUuid,
      'parentUuid': instance.parentUuid,
      'role': instance.role,
      'messageType': instance.messageType,
      'content': instance.content,
      'attachmentUuids': instance.attachmentUuids,
      'createdAt': instance.createdAt,
      'toolData': instance.toolData,
    };
