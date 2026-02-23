import 'package:json_annotation/json_annotation.dart';

part 'post_detail_response.g.dart';

/// 资产项（图片等），对应后端 AssetDTO
@JsonSerializable()
class AssetItem {
  final String uuid;
  final String mime;
  final int width;
  final int height;
  final String url;

  AssetItem({
    required this.uuid,
    required this.mime,
    required this.width,
    required this.height,
    required this.url,
  });

  factory AssetItem.fromJson(Map<String, dynamic> json) =>
      _$AssetItemFromJson(json);

  Map<String, dynamic> toJson() => _$AssetItemToJson(this);
}

/// 帖子详情轮询响应，对应后端 PostResponse。
///
/// aiStatus 可能值：PROCESSING / COMPLETED / FAILED
/// 图片视觉提取结果通过独立接口 GET /api/assets/extractions/{noteUuid} 轮询。
@JsonSerializable()
class PostDetailResponse {
  final String uuid;
  final String? url;
  final String aiStatus;
  final String? summary;
  final String? sessionUuid;
  final String? resourceStatus;
  final String? previewTitle;
  final String? previewDescription;
  final List<AssetItem> assets;
  final List<String> tags;

  PostDetailResponse({
    required this.uuid,
    this.url,
    required this.aiStatus,
    this.summary,
    this.sessionUuid,
    this.resourceStatus,
    this.previewTitle,
    this.previewDescription,
    List<AssetItem>? assets,
    List<String>? tags,
  }) : assets = assets ?? [],
       tags = tags ?? [];

  factory PostDetailResponse.fromJson(Map<String, dynamic> json) =>
      _$PostDetailResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PostDetailResponseToJson(this);

  bool get isCompleted => aiStatus == 'COMPLETED';
  bool get isFailed => aiStatus == 'FAILED';
  bool get isProcessing => aiStatus == 'PROCESSING';
}
