import '../service/scraper/platform_scraper_interface.dart';
import '../service/scraper/xhs_scraper.dart';
import '../service/scraper/zhihu_scraper.dart';

/// 平台类型枚举
///
/// 用于标识不同的内容平台，以便选择对应的爬虫策略
enum PlatformType {
  /// 小红书
  xhs('小红书', 'xhs'),

  /// 知乎
  zhihu('知乎', 'zhihu'),

  /// 通用平台（使用默认策略）
  generic('通用', 'generic');

  final String displayName;
  final String identifier;

  const PlatformType(this.displayName, this.identifier);

  // 直接在枚举内部定义静态 getter
  static List<PlatformType> get getSupportedPlatforms {
    return PlatformType.values.where((p) => p != PlatformType.generic).toList();
  }
}

/// 平台检测器
///
/// 根据 URL 识别内容来源平台
class PlatformDetector {
  /// 小红书 URL 匹配正则
  static final RegExp _xhsPattern = RegExp(
    r'(xhslink|xiaohongshu)\.com',
    caseSensitive: false,
  );

  /// 知乎 URL 匹配正则
  /// 支持：zhihu.com, zhuanlan.zhihu.com
  static final RegExp _zhihuPattern = RegExp(
    r'(zhihu|zhuanlan\.zhihu)\.com',
    caseSensitive: false,
  );

  /// 检测 URL 对应的平台类型
  ///
  /// [url] 目标链接
  /// 返回识别到的 [PlatformType]
  static PlatformType detectPlatform(String url) {
    if (url.isEmpty) {
      return PlatformType.generic;
    }

    // 小红书检测
    if (_xhsPattern.hasMatch(url)) {
      return PlatformType.xhs;
    }

    // 知乎检测
    if (_zhihuPattern.hasMatch(url)) {
      return PlatformType.zhihu;
    }

    // 未匹配到特定平台，返回通用类型
    return PlatformType.generic;
  }

  /// 获取平台对应的爬虫
  ///
  /// [platform] 平台类型
  /// 返回对应的 [IPlatformScraper] 实现，未支持的平台返回 null
  static IPlatformScraper? getScraper(String url) {
    final platform = detectPlatform(url);
    switch (platform) {
      case PlatformType.xhs:
        return XhsScraper();
      case PlatformType.zhihu:
        return ZhihuScraper();
      case PlatformType.generic:
        return null; // 通用平台使用其他策略
    }
  }
}
