// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UploadResultModel _$UploadResultModelFromJson(Map<String, dynamic> json) =>
    UploadResultModel(
      uuid: json['uuid'] as String,
      mime: json['mime'] as String,
      size: (json['size'] as num).toInt(),
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
    );

Map<String, dynamic> _$UploadResultModelToJson(UploadResultModel instance) =>
    <String, dynamic>{
      'uuid': instance.uuid,
      'mime': instance.mime,
      'size': instance.size,
      'width': instance.width,
      'height': instance.height,
    };
