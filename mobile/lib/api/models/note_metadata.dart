/// 统一的 note 元数据返回结构
///
/// 整合后端和本地LinkPreview两种数据源的返回数据
/// 调用方应优先使用 previewContent，如果为空则回退到 previewDescription
class NoteMetadata {
  /// 标题
  final String? title;

  /// 描述
  final String? previewDescription;

  /// 正文内容
  final String? previewContent;

  /// AI摘要（
  final String? aiSummary;

  /// 预览图片URL
  final String? imageUrl;

  /// 预览图片URL列表
  final List<String>? imageUrls;

  /// 原始URL
  final String url;

  /// 资源状态
  final String? resourceStatus;

  NoteMetadata({
    this.title,
    this.previewDescription,
    this.previewContent,
    this.aiSummary,
    this.imageUrl,
    this.imageUrls,
    required this.url,
    this.resourceStatus,
  });

  /// 是否有效（至少有标题或图片）
  bool get isValid =>
      (title != null && title!.isNotEmpty) ||
      (imageUrl != null && imageUrl!.isNotEmpty) ||
      (imageUrls != null && imageUrls!.isNotEmpty);

  /// 获取展示用的描述（优先使用 previewContent）
  String? get displayDescription {
    if (previewContent != null && previewContent!.trim().isNotEmpty) {
      return previewContent;
    }
    return previewDescription;
  }

  /// 获取首图（兼容多图和单图场景）
  String? get firstImage {
    if (imageUrls != null && imageUrls!.isNotEmpty) {
      return imageUrls!.first;
    }
    return imageUrl;
  }

  /// 获取所有图片列表
  List<String> get allImages {
    if (imageUrls != null && imageUrls!.isNotEmpty) {
      return imageUrls!;
    }
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return [imageUrl!];
    }
    return [];
  }
}
