import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pocketmind/service/cookie_manager_service.dart';
import 'package:pocketmind/util/logger_service.dart';

/// B站登录页面
///
/// 使用 WebView 加载 B站 登录页，登录成功后提取 Cookie
/// 关键逻辑：
/// 1. 页面完全加载后，检测 SESSDATA Cookie（已登录用户才有）
/// 2. SESSDATA 是 B站 的登录态 Cookie，未登录用户没有
/// 3. 当检测到有效的 SESSDATA 时，认为登录成功
class BilibiliLoginPage extends StatefulWidget {
  const BilibiliLoginPage({super.key});

  @override
  State<BilibiliLoginPage> createState() => _BilibiliLoginPageState();
}

class _BilibiliLoginPageState extends State<BilibiliLoginPage> {
  static const String _tag = 'BilibiliLoginPage';

  /// B站登录 URL（直接跳转登录页）
  static const String _loginUrl = 'https://passport.bilibili.com/login';

  /// 判断登录成功的关键 Cookie
  /// SESSDATA 是 B站 的登录态标识，只有登录用户才有
  static const String _loginSessionCookie = 'SESSDATA';

  /// 需要保存的 Cookie 名称（用于后续爬虫）
  /// SESSDATA: 登录态标识
  /// bili_jct: CSRF Token，部分 API 需要
  /// DedeUserID: 用户 ID
  static const List<String> _cookiesToSave = [
    'SESSDATA',
    'bili_jct',
    'DedeUserID',
  ];

  /// 推荐的 UserAgent（桌面端）
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/128.0.0.0 Safari/537.36';

  /// 轮询检测间隔
  static const Duration _checkInterval = Duration(seconds: 2);

  /// 最大等待时间（10 分钟）
  static const Duration _maxWaitTime = Duration(minutes: 10);

  /// 页面加载后等待 Cookie 稳定的时间
  static const Duration _cookieStabilizeDelay = Duration(seconds: 3);

  final CookieManagerService _cookieManager = CookieManagerService();
  final CookieManager _webViewCookieManager = CookieManager.instance();

  InAppWebViewController? _webViewController;
  Timer? _loginCheckTimer;

  bool _isLoading = true;
  bool _loginSuccess = false;
  bool _checkStarted = false;
  String _statusMessage = '正在加载页面...';
  int _remainingSeconds = 600; // 10 分钟

  @override
  void initState() {
    super.initState();
    _clearExistingCookies();
  }

  @override
  void dispose() {
    _loginCheckTimer?.cancel();
    _webViewController?.dispose();
    super.dispose();
  }

  /// 清除已有 Cookie，确保用户重新登录
  Future<void> _clearExistingCookies() async {
    try {
      await _webViewCookieManager.deleteAllCookies();
      PMlog.d(_tag, 'WebView Cookie 已清除');
    } catch (e) {
      PMlog.w(_tag, '清除 Cookie 失败: $e');
    }
  }

  /// 获取当前 SESSDATA Cookie 值
  Future<String?> _getLoginCookie() async {
    try {
      final cookies = await _webViewCookieManager.getCookies(
        url: WebUri('https://www.bilibili.com'),
      );

      for (var cookie in cookies) {
        if (cookie.name == _loginSessionCookie) {
          return cookie.value;
        }
      }
      return null;
    } catch (e) {
      PMlog.e(_tag, '获取 SESSDATA 失败: $e');
      return null;
    }
  }

  /// 获取所有 Cookie
  Future<Map<String, String>> _getAllCookies() async {
    try {
      final cookies = await _webViewCookieManager.getCookies(
        url: WebUri('https://www.bilibili.com'),
      );

      final cookieMap = <String, String>{};
      for (var cookie in cookies) {
        cookieMap[cookie.name] = cookie.value;
      }
      return cookieMap;
    } catch (e) {
      PMlog.e(_tag, '获取 Cookie 失败: $e');
      return {};
    }
  }

  /// 开始检测登录状态（页面加载完成后调用）
  Future<void> _startLoginDetection() async {
    if (_checkStarted) {
      return;
    }

    PMlog.d(_tag, '等待 Cookie 稳定...');

    await Future.delayed(_cookieStabilizeDelay);

    _checkStarted = true;

    if (mounted) {
      setState(() {
        _statusMessage = '请登录 B站 账号';
      });
    }

    _startLoginCheck();
  }

  /// 开始轮询检测登录状态
  void _startLoginCheck() {
    if (_loginCheckTimer != null && _loginCheckTimer!.isActive) {
      return;
    }

    final startTime = DateTime.now();

    _loginCheckTimer = Timer.periodic(_checkInterval, (timer) async {
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed >= _maxWaitTime) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _statusMessage = '登录超时，请重试';
          });
        }
        return;
      }

      final remaining = _maxWaitTime - elapsed;
      if (mounted) {
        setState(() {
          _remainingSeconds = remaining.inSeconds;
        });
      }

      // 检查登录状态
      final sessdata = await _getLoginCookie();

      if (sessdata != null && sessdata.isNotEmpty) {
        PMlog.d(_tag, '检测到 SESSDATA，登录成功！');
        PMlog.d(
          _tag,
          'SESSDATA 值: ${sessdata.substring(0, 20.clamp(0, sessdata.length))}...',
        );

        timer.cancel();
        await _handleLoginSuccess();
        return;
      }
    });
  }

  /// 保存 Cookie 到本地
  Future<void> _saveCookies() async {
    try {
      final allCookies = await _getAllCookies();

      final cookiesToSave = <String, String>{};
      for (var name in _cookiesToSave) {
        if (allCookies.containsKey(name) && allCookies[name]!.isNotEmpty) {
          cookiesToSave[name] = allCookies[name]!;
          PMlog.d(
            _tag,
            '保存 Cookie: $name=${allCookies[name]!.substring(0, 10.clamp(0, allCookies[name]!.length))}...',
          );
        }
      }

      if (cookiesToSave.isEmpty) {
        throw Exception('没有可保存的 Cookie');
      }

      // 默认有效期 30 天
      final expiresAt = DateTime.now().add(const Duration(days: 30));

      await _cookieManager.saveCookies('bilibili', cookiesToSave, expiresAt);

      PMlog.d(_tag, 'Cookie 已保存到本地，共 ${cookiesToSave.length} 个');
    } catch (e) {
      PMlog.e(_tag, '保存 Cookie 失败: $e');
      rethrow;
    }
  }

  /// 处理登录成功
  Future<void> _handleLoginSuccess() async {
    _loginCheckTimer?.cancel();

    if (mounted) {
      setState(() {
        _statusMessage = '登录成功！正在保存...';
      });
    }

    try {
      await Future.delayed(const Duration(seconds: 1));
      await _saveCookies();

      if (mounted) {
        setState(() {
          _loginSuccess = true;
          _statusMessage = '登录成功！Cookie 已保存';
        });
      }

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = '保存失败: $e';
        });
      }
    }
  }

  /// 格式化剩余时间
  String _formatRemainingTime() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录 B站'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _loginCheckTimer?.cancel();
            Navigator.of(context).pop(false);
          },
        ),
      ),
      body: Column(
        children: [
          // 状态提示栏
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: _loginSuccess ? Colors.green.shade100 : Colors.pink.shade50,
            child: Row(
              children: [
                Icon(
                  _loginSuccess ? Icons.check_circle : Icons.login,
                  color: _loginSuccess ? Colors.green : Colors.pink,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _loginSuccess
                              ? Colors.green.shade900
                              : Colors.pink.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (!_loginSuccess && !_isLoading)
                        Text(
                          '剩余等待时间: ${_formatRemainingTime()}',
                          style: TextStyle(
                            color: Colors.pink.shade700,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_loginSuccess) const Icon(Icons.check, color: Colors.green),
              ],
            ),
          ),

          // 加载指示器
          if (_isLoading) const LinearProgressIndicator(color: Colors.pink),

          // 使用说明
          if (!_loginSuccess)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.shade50,
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.amber.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '请使用 B站 APP 扫码登录，或使用短信验证码登录',
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // WebView
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_loginUrl)),
              initialSettings: InAppWebViewSettings(
                userAgent: _userAgent,
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                cacheEnabled: true,
                supportZoom: true,
                builtInZoomControls: true,
                displayZoomControls: false,
                useWideViewPort: true,
                loadWithOverviewMode: false,
                minimumFontSize: 8,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              onLoadStart: (controller, url) {
                setState(() {
                  _isLoading = true;
                });
                PMlog.d(_tag, '开始加载: $url');
              },
              onLoadStop: (controller, url) async {
                setState(() {
                  _isLoading = false;
                });
                PMlog.d(_tag, '加载完成: $url');

                if (!_checkStarted) {
                  await _startLoginDetection();
                }
              },
              onReceivedError: (controller, request, error) {
                PMlog.e(_tag, '加载错误: ${error.description}');
                setState(() {
                  _isLoading = false;
                  _statusMessage = '加载失败: ${error.description}';
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
