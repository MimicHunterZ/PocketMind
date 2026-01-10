/// 平台类型枚举
///
/// 用于标识不同的内容平台，以便选择对应的爬虫策略
enum PlatformType {
  /// 小红书
  xhs,

  /// 通用平台（使用默认策略）
  generic,
}

/// 平台类型扩展方法
extension PlatformTypeExtension on PlatformType {
  /// 获取平台显示名称
  String get displayName {
    switch (this) {
      case PlatformType.xhs:
        return '小红书';
      case PlatformType.generic:
        return '通用';
    }
  }

  /// 获取平台标识符（用于存储）
  String get identifier {
    switch (this) {
      case PlatformType.xhs:
        return 'xhs';
      case PlatformType.generic:
        return 'generic';
    }
  }

  /// 从标识符解析平台类型
  static PlatformType fromIdentifier(String identifier) {
    switch (identifier) {
      case 'xhs':
        return PlatformType.xhs;
      default:
        return PlatformType.generic;
    }
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

    // 未匹配到特定平台，返回通用类型
    return PlatformType.generic;
  }
}
