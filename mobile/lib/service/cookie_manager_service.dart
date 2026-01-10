import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketmind/util/logger_service.dart';

/// 平台 Cookie 数据模型
///
/// 存储平台登录后的 Cookie 信息
class PlatformCookie {
  /// Cookie 键值对字典
  final Map<String, String> cookieDict;

  /// Cookie 字符串格式（用于 HTTP 请求头）
  final String cookieString;

  /// 过期时间
  final DateTime expiresAt;

  /// 保存时间
  final DateTime savedAt;

  PlatformCookie({
    required this.cookieDict,
    required this.cookieString,
    required this.expiresAt,
    required this.savedAt,
  });

  /// 从 JSON 反序列化
  factory PlatformCookie.fromJson(Map<String, dynamic> json) {
    return PlatformCookie(
      cookieDict: Map<String, String>.from(json['cookieDict'] ?? {}),
      cookieString: json['cookieString'] ?? '',
      expiresAt: DateTime.parse(json['expiresAt']),
      savedAt: DateTime.parse(json['savedAt']),
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      'cookieDict': cookieDict,
      'cookieString': cookieString,
      'expiresAt': expiresAt.toIso8601String(),
      'savedAt': savedAt.toIso8601String(),
    };
  }

  /// 检查是否已过期
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// 距离过期的剩余天数
  int get daysUntilExpiry => expiresAt.difference(DateTime.now()).inDays;
}

/// Cookie 管理服务
///
/// 负责平台 Cookie 的存储、读取和过期管理
/// 参考 MediaCrawler tools/crawler_util.py 的 Cookie 转换机制
class CookieManagerService {
  static const String _tag = 'CookieManager';
  static const String _keyPrefix = 'cookie_';

  static CookieManagerService? _instance;
  SharedPreferences? _prefs;

  CookieManagerService._();

  /// 获取单例实例
  static CookieManagerService get instance {
    _instance ??= CookieManagerService._();
    return _instance!;
  }

  /// 工厂构造函数（兼容旧代码）
  factory CookieManagerService() => instance;

  /// 初始化（需要在使用前调用）
  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    PMlog.d(_tag, '初始化完成');
  }

  /// 确保已初始化
  Future<SharedPreferences> _ensurePrefs() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    return _prefs!;
  }

  /// 保存平台 Cookie
  ///
  /// [platform] 平台标识符（如 'xhs'）
  /// [cookieDict] Cookie 键值对字典
  /// [expiresAt] 过期时间
  Future<void> saveCookies(
    String platform,
    Map<String, String> cookieDict,
    DateTime expiresAt,
  ) async {
    final prefs = await _ensurePrefs();
    final key = '$_keyPrefix$platform';

    // 生成 Cookie 字符串（参考 MediaCrawler convert_cookies）
    final cookieString = cookieDict.entries
        .map((e) => '${e.key}=${e.value}')
        .join('; ');

    final data = PlatformCookie(
      cookieDict: cookieDict,
      cookieString: cookieString,
      expiresAt: expiresAt,
      savedAt: DateTime.now(),
    );

    await prefs.setString(key, jsonEncode(data.toJson()));

    PMlog.d(
      _tag,
      '[$platform] Cookie 已保存: '
      'Count=${cookieDict.length}, '
      'ExpiresAt=${expiresAt.toIso8601String()}, '
      'Keys=${cookieDict.keys.join(", ")}',
    );
  }

  /// 获取平台 Cookie 数据
  ///
  /// [platform] 平台标识符
  /// 返回 [PlatformCookie] 或 null（不存在时）
  Future<PlatformCookie?> getCookie(String platform) async {
    final prefs = await _ensurePrefs();
    final key = '$_keyPrefix$platform';
    final jsonStr = prefs.getString(key);

    if (jsonStr == null || jsonStr.isEmpty) {
      PMlog.d(_tag, '[$platform] Cookie 不存在');
      return null;
    }

    try {
      final cookie = PlatformCookie.fromJson(jsonDecode(jsonStr));
      PMlog.d(
        _tag,
        '[$platform] Cookie 读取成功: '
        'Count=${cookie.cookieDict.length}, '
        'Expired=${cookie.isExpired}, '
        'DaysLeft=${cookie.daysUntilExpiry}',
      );
      return cookie;
    } catch (e) {
      PMlog.e(_tag, '[$platform] Cookie 解析失败: $e');
      return null;
    }
  }

  /// 获取 Cookie 字典
  ///
  /// [platform] 平台标识符
  /// 返回 Cookie 键值对或 null
  Future<Map<String, String>?> getCookieDict(String platform) async {
    final cookie = await getCookie(platform);
    return cookie?.cookieDict;
  }

  /// 获取 Cookie 字符串
  ///
  /// [platform] 平台标识符
  /// 返回格式化的 Cookie 字符串或 null
  Future<String?> getCookieString(String platform) async {
    final cookie = await getCookie(platform);
    return cookie?.cookieString;
  }

  /// 检查 Cookie 是否已过期
  ///
  /// [platform] 平台标识符
  /// 返回 true 表示已过期或不存在
  Future<bool> isExpired(String platform) async {
    final cookie = await getCookie(platform);
    if (cookie == null) {
      return true;
    }
    final expired = cookie.isExpired;
    if (expired) {
      PMlog.d(_tag, '[$platform] Cookie 已过期');
    }
    return expired;
  }

  /// 检查是否存在有效的 Cookie
  ///
  /// [platform] 平台标识符
  /// 返回 true 表示存在且未过期
  Future<bool> hasValidCookie(String platform) async {
    final expired = await isExpired(platform);
    return !expired;
  }

  /// 标记 Cookie 为已过期
  ///
  /// [platform] 平台标识符
  /// 用于运行时检测到 Cookie 失效时调用
  Future<void> markAsExpired(String platform) async {
    final cookie = await getCookie(platform);
    if (cookie == null) return;

    // 将过期时间设置为过去
    await saveCookies(
      platform,
      cookie.cookieDict,
      DateTime.now().subtract(const Duration(days: 1)),
    );

    PMlog.d(_tag, '[$platform] Cookie 已标记为过期');
  }

  /// 清除平台 Cookie
  ///
  /// [platform] 平台标识符
  Future<void> clearCookies(String platform) async {
    final prefs = await _ensurePrefs();
    final key = '$_keyPrefix$platform';
    await prefs.remove(key);
    PMlog.d(_tag, '[$platform] Cookie 已清除');
  }

  /// 获取 Cookie 过期时间
  ///
  /// [platform] 平台标识符
  /// 返回过期时间或 null
  Future<DateTime?> getExpiresAt(String platform) async {
    final cookie = await getCookie(platform);
    return cookie?.expiresAt;
  }

  /// 获取 Cookie 保存时间
  ///
  /// [platform] 平台标识符
  /// 返回保存时间或 null
  Future<DateTime?> getSavedAt(String platform) async {
    final cookie = await getCookie(platform);
    return cookie?.savedAt;
  }
}
