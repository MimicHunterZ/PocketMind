/// 爬取到的元数据
///
/// 平台爬虫返回的结构化数据
class ScrapedMetadata {
  /// 标题
  final String? title;

  /// 描述/摘要
  final String? description;

  /// 图片 URL 列表（多图支持）
  final List<String> images;

  /// 正文内容
  final String? content;

  /// 原始数据（调试用）
  final Map<String, dynamic>? rawData;

  ScrapedMetadata({
    this.title,
    this.description,
    List<String>? images,
    this.content,
    this.rawData,
  }) : images = images ?? [];

  /// 是否有效（至少有标题或图片）
  bool get isValid => (title != null && title!.isNotEmpty) || images.isNotEmpty;

  /// 获取首图（兼容单图场景）
  String? get firstImage => images.isNotEmpty ? images.first : null;

  @override
  String toString() {
    return 'ScrapedMetadata('
        'title: $title, '
        'description: ${description?.substring(0, description!.length > 50 ? 50 : description!.length)}..., '
        'images: ${images.length}, '
        'hasContent: ${content != null}'
        ')';
  }
}

/// Cookie 过期异常
///
/// 当检测到 Cookie 失效时抛出
class CookieExpiredException implements Exception {
  final String message;
  final String? platform;

  CookieExpiredException(this.message, {this.platform});

  @override
  String toString() => 'CookieExpiredException: $message';
}

/// 平台爬虫抽象接口
///
/// 定义平台爬虫的标准接口，便于扩展新平台
abstract class IPlatformScraper {
  /// 执行爬取
  ///
  /// [url] 目标链接
  /// [cookieDict] Cookie 键值对
  /// 返回 [ScrapedMetadata] 或 null（失败时）
  /// 可能抛出 [CookieExpiredException] 当 Cookie 失效时
  Future<ScrapedMetadata?> scrape(String url, Map<String, String> cookieDict);

  /// 是否需要 Cookie 才能爬取
  bool requiresCookie();

  /// 获取平台名称
  String getPlatformName();

  /// 获取平台标识符
  String getPlatformId();

  /// 获取必需的 Cookie 名称列表
  List<String> getRequiredCookieNames();

  /// 验证 Cookie 是否完整
  bool validateCookies(Map<String, String> cookieDict) {
    final required = getRequiredCookieNames();
    for (var name in required) {
      if (!cookieDict.containsKey(name) || cookieDict[name]!.isEmpty) {
        return false;
      }
    }
    return true;
  }
}
