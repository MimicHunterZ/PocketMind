import 'package:pocketmind/util/platform_detector.dart';

/// 链接预览配置
class LinkPreviewConfig {
  /// 判断是否使用 LinkPreviewAPI 服务
  ///
  /// X/Twitter/YouTube 使用 LinkPreviewAPI
  static bool shouldUseApiService(String url) {
    final lowerUrl = url.toLowerCase();

    // X/Twitter 使用 API
    if (lowerUrl.contains('x.com') ||
        lowerUrl.contains('twitter.com') ||
        lowerUrl.contains('t.co')) {
      return true;
    }

    // YouTube 使用 API
    if (lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be')) {
      return true;
    }

    // 国内网站和其他网站使用 any_link_preview
    return false;
  }

  static bool shouldUsePlatformScraper(String url) {
    final canHandle =
        PlatformDetector.detectPlatform(url) != PlatformType.generic;
    return canHandle;
  }
}
