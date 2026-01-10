import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pocketmind/service/cookie_manager_service.dart';
import 'package:pocketmind/util/logger_service.dart';

/// 小红书登录页面
///
/// 使用 WebView 加载小红书登录页，登录成功后提取 Cookie
/// 参考 MediaCrawler xhs/login.py 实现：
/// - 通过检测 web_session Cookie 变化来判断登录成功
/// - 轮询检测登录状态，最长等待 10 分钟
///
/// 关键逻辑（参考 MediaCrawler check_login_state）:
/// 1. 页面完全加载后，等待额外时间让 XHS 设置初始 Cookie
/// 2. 捕获此时的 web_session 作为"未登录状态"的基准值
/// 3. 只有当 web_session 从基准值变化时，才认为登录成功
class XhsLoginPage extends StatefulWidget {
  const XhsLoginPage({super.key});

  @override
  State<XhsLoginPage> createState() => _XhsLoginPageState();
}

class _XhsLoginPageState extends State<XhsLoginPage> {
  static const String _tag = 'XhsLoginPage';

  /// 小红书登录/首页 URL
  static const String _loginUrl = 'https://www.xiaohongshu.com';

  /// 判断登录成功的关键 Cookie（参考 MediaCrawler）
  static const String _loginSessionCookie = 'web_session';

  /// 需要保存的 Cookie 名称（用于后续爬虫）
  static const List<String> _cookiesToSave = ['a1', 'webId', 'web_session'];

  /// 推荐的 UserAgent（与 MediaCrawler 保持一致）
  static const String _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/126.0.0.0 Safari/537.36';

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
  bool _initialSessionCaptured = false; // 标记是否已捕获初始 session
  String _statusMessage = '正在加载页面...';
  int _remainingSeconds = 600; // 10 分钟

  /// 未登录时的 web_session 值（用于比对）
  /// 注意：这个值可能是 null（未设置）或具体字符串（游客 session）
  String? _initialWebSession;

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

  /// 获取当前 web_session Cookie 值
  Future<String?> _getWebSession() async {
    try {
      final cookies = await _webViewCookieManager.getCookies(
        url: WebUri(_loginUrl),
      );

      for (var cookie in cookies) {
        if (cookie.name == _loginSessionCookie) {
          return cookie.value;
        }
      }
      return null;
    } catch (e) {
      PMlog.e(_tag, '获取 web_session 失败: $e');
      return null;
    }
  }

  /// 获取所有 Cookie
  Future<Map<String, String>> _getAllCookies() async {
    try {
      final cookies = await _webViewCookieManager.getCookies(
        url: WebUri(_loginUrl),
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

  /// 捕获初始 web_session（页面加载完成后调用）
  ///
  /// 关键点：必须等待页面完全加载并稳定后再捕获，
  /// 因为 XHS 会为游客设置一个 web_session，我们需要以此为基准
  Future<void> _captureInitialSession() async {
    if (_initialSessionCaptured) {
      return; // 只捕获一次
    }

    PMlog.d(_tag, '等待 Cookie 稳定...');

    // 等待页面完全加载并让 XHS 设置 Cookie
    await Future.delayed(_cookieStabilizeDelay);

    _initialWebSession = await _getWebSession();
    _initialSessionCaptured = true;

    PMlog.d(_tag, '初始 web_session 已捕获: ${_initialWebSession ?? "null"}');

    if (mounted) {
      setState(() {
        _statusMessage = '请扫码登录小红书账号';
      });
    }

    // 开始轮询检测
    _startLoginCheck();
  }

  /// 开始轮询检测登录状态
  /// 参考 MediaCrawler: check_login_state 方法
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

      // 检查登录状态
      final currentWebSession = await _getWebSession();

      // 参考 MediaCrawler: 如果 web_session 与初始值不同，说明登录成功
      // 注意：必须是"不同"而不是"非空"，因为游客也有 web_session
      final isLoginSuccess = _checkLoginSuccess(currentWebSession);

      if (isLoginSuccess) {
        PMlog.d(_tag, '检测到 web_session 变化，登录成功！');
        PMlog.d(_tag, '初始值: ${_initialWebSession ?? "null"}');
        PMlog.d(
          _tag,
          '当前值: ${currentWebSession?.substring(0, 20) ?? "null"}...',
        );

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
          if (content != null && content.toString().contains('请通过验证')) {
            if (mounted) {
              setState(() {
                _statusMessage = '请完成验证码验证';
              });
            }
          }
        } catch (e) {
          // 忽略错误
        }
      }
    });
  }

  /// 检查是否登录成功
  ///
  /// 参考 MediaCrawler check_login_state:
  /// - 如果当前 web_session 与初始值不同，认为登录成功
  bool _checkLoginSuccess(String? currentWebSession) {
    // 情况1: 初始时没有 session，现在有了
    if (_initialWebSession == null &&
        currentWebSession != null &&
        currentWebSession.isNotEmpty) {
      return true;
    }

    // 情况2: 初始时有 session，现在变了
    if (_initialWebSession != null &&
        currentWebSession != null &&
        currentWebSession != _initialWebSession) {
      return true;
    }

    return false;
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

      await _cookieManager.saveCookies('xhs', cookiesToSave, expiresAt);

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
        title: const Text('登录小红书'),
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
                  _loginSuccess ? Icons.check_circle : Icons.qr_code_scanner,
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
                      '请使用小红书 APP 扫描二维码登录，登录成功后会自动保存',
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
                // 允许缩放
                supportZoom: true,
                builtInZoomControls: true,
                displayZoomControls: false,
                // 适应屏幕宽度
                useWideViewPort: true,
                loadWithOverviewMode: true,
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

                // 页面加载完成后，捕获初始 session 并开始检测
                // 只在首次加载完成时执行
                if (!_initialSessionCaptured) {
                  await _captureInitialSession();
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
