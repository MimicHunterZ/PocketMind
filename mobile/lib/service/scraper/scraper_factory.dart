import 'package:pocketmind/util/platform_detector.dart';
import 'package:pocketmind/service/scraper/platform_scraper_interface.dart';
import 'package:pocketmind/service/scraper/xhs_scraper.dart';

/// 爬虫工厂
///
/// 根据平台类型创建对应的爬虫实例
class ScraperFactory {
  /// 获取平台对应的爬虫
  ///
  /// [platform] 平台类型
  /// 返回对应的 [IPlatformScraper] 实现，未支持的平台返回 null
  static IPlatformScraper? getScraper(PlatformType platform) {
    switch (platform) {
      case PlatformType.xhs:
        return XhsScraper();
      case PlatformType.generic:
        return null; // 通用平台使用其他策略
    }
  }

  /// 检查平台是否支持专用爬虫
  static bool hasScraper(PlatformType platform) {
    return getScraper(platform) != null;
  }

  /// 获取所有支持的平台
  static List<PlatformType> getSupportedPlatforms() {
    return PlatformType.values
        .where((p) => p != PlatformType.generic && hasScraper(p))
        .toList();
  }
}
