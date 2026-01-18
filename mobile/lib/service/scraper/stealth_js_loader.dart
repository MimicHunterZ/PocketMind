import 'package:flutter/services.dart' show rootBundle;
import 'package:pocketmind/util/logger_service.dart';

/// stealth.js 加载器
///
/// 单例模式缓存 stealth.min.js 内容，避免重复读取 assets
/// 用于注入到 WebView 防止被检测为爬虫
class StealthJsLoader {
  static const String _tag = 'StealthJsLoader';
  static const String _assetPath = 'assets/js/stealth.min.js';

  static StealthJsLoader? _instance;

  /// 缓存的 stealth.js 内容
  String? _stealthJsContent;

  /// 是否已加载
  bool _isLoaded = false;

  /// 加载中的 Future（防止并发加载）
  Future<void>? _loadingFuture;

  StealthJsLoader._();

  /// 获取单例实例
  static StealthJsLoader get instance {
    _instance ??= StealthJsLoader._();
    return _instance!;
  }

  /// 工厂构造函数
  factory StealthJsLoader() => instance;

  /// 预加载 stealth.js（可在 app 启动时调用）
  Future<void> preload() async {
    if (_isLoaded) return;

    // 防止并发加载
    if (_loadingFuture != null) {
      await _loadingFuture;
      return;
    }

    _loadingFuture = _load();
    await _loadingFuture;
    _loadingFuture = null;
  }

  /// 内部加载方法
  Future<void> _load() async {
    try {
      final content = await rootBundle.loadString(_assetPath);
      _stealthJsContent = content;
      _isLoaded = true;
      PMlog.d(_tag, 'stealth.js 加载成功, 大小: ${content.length} 字符');
    } catch (e) {
      PMlog.e(_tag, 'stealth.js 加载失败: $e');
      // 加载失败时使用空字符串，不影响后续逻辑
      _stealthJsContent = '';
      _isLoaded = true;
    }
  }

  /// 获取 stealth.js 内容
  ///
  /// 如果未加载会先加载，然后返回缓存内容
  Future<String> getStealthJs() async {
    if (!_isLoaded) {
      await preload();
    }
    return _stealthJsContent ?? '';
  }

  /// 同步获取 stealth.js 内容（必须先调用过 preload 或 getStealthJs）
  ///
  /// 如果未加载会返回空字符串
  String getStealthJsSync() {
    if (!_isLoaded) {
      PMlog.w(_tag, '尝试同步获取但 stealth.js 尚未加载');
      return '';
    }
    return _stealthJsContent ?? '';
  }

  /// 是否已加载
  bool get isLoaded => _isLoaded;

  /// 重新加载（用于热重载场景）
  Future<void> reload() async {
    _isLoaded = false;
    _stealthJsContent = null;
    await preload();
  }
}
