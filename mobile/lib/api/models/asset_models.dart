import 'package:json_annotation/json_annotation.dart';

part 'asset_models.g.dart';

/// 图片上传成功响应，对应后端 UploadResultDTO
@JsonSerializable()
class UploadResultModel {
  final String uuid;
  final String mime;
  final int size;
  final int width;
  final int height;

  UploadResultModel({
    required this.uuid,
    required this.mime,
    required this.size,
    required this.width,
    required this.height,
  });

  factory UploadResultModel.fromJson(Map<String, dynamic> json) =>
      _$UploadResultModelFromJson(json);

  Map<String, dynamic> toJson() => _$UploadResultModelToJson(this);
}
