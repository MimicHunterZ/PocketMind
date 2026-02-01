/// 元数据来源
///
/// 用于区分抓取渠道，判定失败时使用:
/// - [platformScraper] 和 [backend] 失败才算真正的失败
/// - [linkPreviewApi] 和 [localParser] 只是兜底，不算失败
enum MetadataSource {
  /// 平台专用爬虫（小红书等，本地无头浏览器）
  platformScraper,

  /// 后端服务
  backend,

  /// LinkPreview API（公共服务，兜底）
  linkPreviewApi,

  /// 本地解析库（AnyLinkPreview，兜底）
  localParser,
}

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

  /// AI摘要
  final String? aiSummary;

  /// 预览图片URL列表
  final List<String> imageUrls;

  /// 原始URL
  final String url;

  /// 资源状态
  final String? resourceStatus;

  /// 元数据来源
  final MetadataSource? source;

  NoteMetadata({
    this.title,
    this.previewDescription,
    this.previewContent,
    this.aiSummary,
    List<String>? imageUrls,
    required this.url,
    this.resourceStatus,
    this.source,
  }) : imageUrls = imageUrls ?? [];

  /// 是否来自主要抓取渠道
  bool get isFromPrimarySource =>
      source == MetadataSource.platformScraper ||
      source == MetadataSource.backend;

  /// 是否来自兜底渠道
  bool get isFromFallbackSource =>
      source == MetadataSource.linkPreviewApi ||
      source == MetadataSource.localParser;

  /// 是否有效（至少有标题或图片）
  bool get isValid =>
      (title != null && title!.isNotEmpty) || imageUrls.isNotEmpty;

  /// 获取展示用的描述（优先使用 previewContent）
  String? get displayDescription {
    if (previewContent != null && previewContent!.trim().isNotEmpty) {
      return previewContent;
    }
    return previewDescription;
  }

  /// 获取首图
  String? get firstImage => imageUrls.isNotEmpty ? imageUrls.first : null;
}
