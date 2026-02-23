// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_detail_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AssetItem _$AssetItemFromJson(Map<String, dynamic> json) => AssetItem(
  uuid: json['uuid'] as String,
  mime: json['mime'] as String,
  width: (json['width'] as num).toInt(),
  height: (json['height'] as num).toInt(),
  url: json['url'] as String,
);

Map<String, dynamic> _$AssetItemToJson(AssetItem instance) => <String, dynamic>{
  'uuid': instance.uuid,
  'mime': instance.mime,
  'width': instance.width,
  'height': instance.height,
  'url': instance.url,
};

PostDetailResponse _$PostDetailResponseFromJson(Map<String, dynamic> json) =>
    PostDetailResponse(
      uuid: json['uuid'] as String,
      url: json['url'] as String?,
      aiStatus: json['aiStatus'] as String,
      summary: json['summary'] as String?,
      sessionUuid: json['sessionUuid'] as String?,
      resourceStatus: json['resourceStatus'] as String?,
      previewTitle: json['previewTitle'] as String?,
      previewDescription: json['previewDescription'] as String?,
      assets: (json['assets'] as List<dynamic>?)
          ?.map((e) => AssetItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );

Map<String, dynamic> _$PostDetailResponseToJson(PostDetailResponse instance) =>
    <String, dynamic>{
      'uuid': instance.uuid,
      'url': instance.url,
      'aiStatus': instance.aiStatus,
      'summary': instance.summary,
      'sessionUuid': instance.sessionUuid,
      'resourceStatus': instance.resourceStatus,
      'previewTitle': instance.previewTitle,
      'previewDescription': instance.previewDescription,
      'assets': instance.assets,
      'tags': instance.tags,
    };
