import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pocketmind/service/cookie_manager_service.dart';
import 'package:pocketmind/util/logger_service.dart';

/// 知乎登录页面
///
/// 使用 WebView 加载知乎登录页，登录成功后提取 Cookie
/// 参考 MediaCrawler zhihu/login.py 实现：
/// - 通过检测 z_c0 Cookie 出现来判断登录成功
/// - 轮询检测登录状态，最长等待 10 分钟
///
/// 关键逻辑：
/// 1. 页面完全加载后，检测 z_c0 Cookie（已登录用户才有）
/// 2. z_c0 是知乎的登录态 Cookie，未登录用户只有 d_c0
/// 3. 当检测到有效的 z_c0 时，认为登录成功
class ZhihuLoginPage extends StatefulWidget {
  const ZhihuLoginPage({super.key});

  @override
  State<ZhihuLoginPage> createState() => _ZhihuLoginPageState();
}

class _ZhihuLoginPageState extends State<ZhihuLoginPage> {
  static const String _tag = 'ZhihuLoginPage';

  /// 知乎登录/首页 URL
  static const String _loginUrl = 'https://www.zhihu.com/signin';

  /// 判断登录成功的关键 Cookie
  /// z_c0 是知乎的登录态标识，只有登录用户才有
  static const String _loginSessionCookie = 'z_c0';

  /// 需要保存的 Cookie 名称（用于后续爬虫）
  /// d_c0: 设备标识，用于签名
  /// z_c0: 登录态标识
  static const List<String> _cookiesToSave = ['d_c0', 'z_c0'];

  /// 推荐的 UserAgent（桌面端，显示更大的二维码）
  /// 使用桌面端 UA 让知乎显示桌面版登录页面，二维码更大更清晰
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
  bool _checkStarted = false; // 标记是否已开始检测
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

  /// 获取当前 z_c0 Cookie 值
  Future<String?> _getLoginCookie() async {
    try {
      final cookies = await _webViewCookieManager.getCookies(
        url: WebUri('https://www.zhihu.com'),
      );

      for (var cookie in cookies) {
        if (cookie.name == _loginSessionCookie) {
          return cookie.value;
        }
      }
      return null;
    } catch (e) {
      PMlog.e(_tag, '获取 z_c0 失败: $e');
      return null;
    }
  }

  /// 获取所有 Cookie
  Future<Map<String, String>> _getAllCookies() async {
    try {
      final cookies = await _webViewCookieManager.getCookies(
        url: WebUri('https://www.zhihu.com'),
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
      return; // 只启动一次
    }

    PMlog.d(_tag, '等待 Cookie 稳定...');

    // 等待页面完全加载并让知乎设置 Cookie
    await Future.delayed(_cookieStabilizeDelay);

    _checkStarted = true;

    if (mounted) {
      setState(() {
        _statusMessage = '请登录知乎账号';
      });
    }

    // 开始轮询检测
    _startLoginCheck();
  }

  /// 开始轮询检测登录状态
  void _startLoginCheck() {
    if (_loginCheckTimer != null && _loginCheckTimer!.isActive) {
      return; // 已经在检测了
    }

    final startTime = DateTime.now();

    _loginCheckTimer = Timer.periodic(_checkInterval, (timer) async {
      // 检查是否超时
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

      // 更新剩余时间
      final remaining = _maxWaitTime - elapsed;
      if (mounted) {
        setState(() {
          _remainingSeconds = remaining.inSeconds;
        });
      }

      // 检查登录状态：z_c0 出现即为登录成功
      final zc0 = await _getLoginCookie();

      if (zc0 != null && zc0.isNotEmpty) {
        PMlog.d(_tag, '检测到 z_c0，登录成功！');
        PMlog.d(_tag, 'z_c0 值: ${zc0.substring(0, 20.clamp(0, zc0.length))}...');

        timer.cancel();
        await _handleLoginSuccess();
        return;
      }

      // 额外检查：页面内容是否包含验证码提示
      if (_webViewController != null) {
        try {
          final content = await _webViewController!.evaluateJavascript(
            source: 'document.body ? document.body.innerText : ""',
          );
          if (content != null && content.toString().contains('验证')) {
            if (mounted) {
              setState(() {
                _statusMessage = '请完成验证';
              });
            }
          }
        } catch (e) {
          // 忽略错误
        }
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

      await _cookieManager.saveCookies('zhihu', cookiesToSave, expiresAt);

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
      // 等待一下确保 Cookie 完全写入
      await Future.delayed(const Duration(seconds: 1));

      await _saveCookies();

      if (mounted) {
        setState(() {
          _loginSuccess = true;
          _statusMessage = '登录成功！Cookie 已保存';
        });
      }

      // 延迟关闭，让用户看到成功提示
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pop(true); // 返回 true 表示登录成功
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
        title: const Text('登录知乎'),
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
            color: _loginSuccess ? Colors.green.shade100 : Colors.blue.shade50,
            child: Row(
              children: [
                Icon(
                  _loginSuccess ? Icons.check_circle : Icons.login,
                  color: _loginSuccess ? Colors.green : Colors.blue,
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
                              : Colors.blue.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (!_loginSuccess && !_isLoading)
                        Text(
                          '剩余等待时间: ${_formatRemainingTime()}',
                          style: TextStyle(
                            color: Colors.blue.shade700,
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
          if (_isLoading) const LinearProgressIndicator(),

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
                      '请使用知乎 APP 扫码登录，或使用手机号登录',
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
                // 桌面端模式：不强制适应屏幕宽度，允许滚动查看完整页面
                supportZoom: true,
                builtInZoomControls: true,
                displayZoomControls: false,
                // 使用桌面端视窗
                useWideViewPort: true,
                loadWithOverviewMode: false, // false 让页面以原始大小显示
                // 设置最小字体大小，避免文字太小
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

                // 页面加载完成后，开始检测登录状态
                // 只在首次加载完成时执行
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
