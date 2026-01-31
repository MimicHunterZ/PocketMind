import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'package:pocketmind/service/scraper/platform_scraper_interface.dart';
import 'package:pocketmind/service/scraper/stealth_js_loader.dart';

/// 知乎内容类型
enum ZhihuContentType {
  answer('answer'),
  answerShort('answer_short'),
  question('question'),
  article('article'),
  video('zvideo');

  final String value;
  const ZhihuContentType(this.value);
}

/// 知乎爬虫实现
///
/// 支持的 URL 格式：
/// - 完整回答: https://www.zhihu.com/question/123456789/answer/123456789
/// - 回答短链接: https://www.zhihu.com/answer/123456789
/// - 纯问题: https://www.zhihu.com/question/123456789
/// - 文章: https://zhuanlan.zhihu.com/p/123456789
/// - 视频: https://www.zhihu.com/zvideo/123456789
class ZhihuScraper implements IPlatformScraper {
  static const String _tag = 'ZhihuScraper';
  static const String _domain = 'https://www.zhihu.com';
  static const String _zhuanlanDomain = 'https://zhuanlan.zhihu.com';
  static const String _cookieDomain = '.zhihu.com';
  static const String _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/128.0.0.0 Safari/537.36';
  static const Duration _renderWaitTime = Duration(seconds: 2);
  static const Duration _timeout = Duration(seconds: 30);

  @override
  List<String> getRequiredCookieNames() => ['d_c0', 'z_c0'];

  @override
  bool validateCookies(Map<String, String> cookieDict) {
    return getRequiredCookieNames().every(
      (name) => cookieDict[name]?.isNotEmpty == true,
    );
  }

  @override
  Future<ScrapedMetadata?> scrape(
    String url,
    Map<String, String> cookieDict,
  ) async {
    final startTime = DateTime.now();
    PMlog.d(_tag, '开始爬取: $url');

    if (!validateCookies(cookieDict)) {
      throw CookieExpiredException('缺少必需Cookie', platform: 'zhihu');
    }

    final cleanUrl = _cleanUrl(url);
    final contentType = _judgeContentType(cleanUrl);
    if (contentType == null) {
      PMlog.e(_tag, '无法识别的知乎 URL 类型: $cleanUrl');
      return null;
    }
    PMlog.d(_tag, '内容类型: ${contentType.value}, 目标URL: $cleanUrl');

    HeadlessInAppWebView? headlessWebView;
    InAppWebViewController? controller;
    bool isDisposed = false;

    try {
      final stealthJs = await StealthJsLoader().getStealthJs();
      await _setCookies(cookieDict);

      final completer = Completer<void>();
      String? pageHtml;
      bool loadError = false;

      headlessWebView = HeadlessInAppWebView(
        initialSettings: InAppWebViewSettings(
          userAgent: _userAgent,
          javaScriptEnabled: true,
          domStorageEnabled: true,
          databaseEnabled: true,
          cacheEnabled: true,
          mediaPlaybackRequiresUserGesture: true,
          useShouldOverrideUrlLoading: false,
          javaScriptCanOpenWindowsAutomatically: false,
          supportMultipleWindows: false,
          safeBrowsingEnabled: false,
        ),
        onWebViewCreated: (ctrl) async {
          controller = ctrl;
          if (stealthJs.isNotEmpty) {
            await ctrl.addUserScript(
              userScript: UserScript(
                source: stealthJs,
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              ),
            );
          }
          await ctrl.addUserScript(
            userScript: UserScript(
              source: _antiDetectScript,
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            ),
          );
        },
        onLoadStop: (ctrl, _) async {
          if (isDisposed || completer.isCompleted) return;
          await Future.delayed(_renderWaitTime);
          if (isDisposed || completer.isCompleted) return;
          try {
            pageHtml = await ctrl.getHtml();
          } catch (_) {}
          if (!completer.isCompleted) completer.complete();
        },
        onReceivedError: (ctrl, request, error) {
          if (request.isForMainFrame == true &&
              (error.description.contains('ERR_CONNECTION') ||
                  error.description.contains('ERR_NAME_NOT_RESOLVED') ||
                  error.description.contains('ERR_NETWORK'))) {
            loadError = true;
            if (!completer.isCompleted) completer.complete();
          }
        },
        onReceivedHttpError: (_, __, ___) {
          // 不因 403 失败，知乎仍会返回页面内容
        },
      );

      await headlessWebView.run();

      await controller?.loadUrl(
        urlRequest: URLRequest(url: WebUri(cleanUrl), headers: _requestHeaders),
      );

      // 等待加载完成（带超时）
      bool timedOut = false;
      try {
        await completer.future.timeout(_timeout);
      } on TimeoutException {
        timedOut = true;
        PMlog.w(_tag, '页面加载超时，尝试获取已加载的内容');
        // 超时时也尝试获取 HTML（页面可能已部分加载）
        if (controller != null && pageHtml == null) {
          try {
            pageHtml = await controller!.getHtml();
          } catch (_) {}
        }
      }

      if (loadError) {
        PMlog.e(_tag, '网络连接错误');
        return null;
      }

      if (pageHtml == null || pageHtml!.isEmpty) {
        PMlog.e(_tag, '页面加载失败${timedOut ? "（超时）" : ""}');
        return null;
      }

      PMlog.d(_tag, 'HTML 长度: ${pageHtml!.length}');

      // 检查是否被拦截
      if (_isBlocked(pageHtml!)) {
        throw CookieExpiredException('被知乎反爬机制拦截', platform: 'zhihu');
      }

      // 检测是否需要登录
      if (await _checkNeedLogin(controller!)) {
        throw CookieExpiredException('检测到需要登录验证', platform: 'zhihu');
      }

      // 提取数据
      final metadata = await _extractMetadata(controller!, contentType);

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      PMlog.d(_tag, '爬取完成: title=${metadata?.title}, duration=${duration}ms');

      return metadata;
    } catch (e) {
      PMlog.e(_tag, '爬取失败: $e');
      if (e is CookieExpiredException) rethrow;
      return null;
    } finally {
      isDisposed = true;
      try {
        await controller?.stopLoading();
        await InAppWebViewController.clearAllCache();
        await headlessWebView?.dispose();
      } catch (_) {}
    }
  }

  /// 清理 URL，移除追踪参数
  String _cleanUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final cleanParams = Map<String, String>.from(uri.queryParameters)
        ..removeWhere((k, _) => k.startsWith('utm_') || k == 'share_code');
      return cleanParams.isEmpty
          ? '${uri.scheme}://${uri.host}${uri.path}'
          : uri.replace(queryParameters: cleanParams).toString();
    } catch (_) {
      return url;
    }
  }

  /// 判断知乎 URL 类型
  ZhihuContentType? _judgeContentType(String url) {
    if (url.contains('/question/') && url.contains('/answer/')) {
      return ZhihuContentType.answer;
    }
    if (url.contains('/answer/')) return ZhihuContentType.answerShort;
    if (url.contains('/question/')) return ZhihuContentType.question;
    if (url.contains('/p/')) return ZhihuContentType.article;
    if (url.contains('/zvideo/')) return ZhihuContentType.video;
    return null;
  }

  /// 设置 Cookie
  Future<void> _setCookies(Map<String, String> cookieDict) async {
    final cookieManager = CookieManager.instance();
    final expiry = DateTime.now()
        .add(const Duration(days: 30))
        .millisecondsSinceEpoch;

    for (var entry in cookieDict.entries) {
      for (var domain in [_domain, _zhuanlanDomain]) {
        await cookieManager.setCookie(
          url: WebUri(domain),
          name: entry.key,
          value: entry.value,
          domain: _cookieDomain,
          path: '/',
          expiresDate: expiry,
        );
      }
    }
  }

  /// 检查是否被拦截
  bool _isBlocked(String html) {
    const blockedTexts = ['系统检测到您的网络环境存在异常', '请完成验证', '访问频率过高'];
    return blockedTexts.any(html.contains);
  }

  /// 检测是否需要登录
  Future<bool> _checkNeedLogin(InAppWebViewController controller) async {
    try {
      final result = await controller.evaluateJavascript(
        source: '''
        (function() {
          var text = document.body?.innerText || '';
          return text.includes('请先登录') || text.includes('登录后查看') ||
                 !!document.querySelector('.Modal-wrapper .Login-content');
        })()
      ''',
      );
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// 提取元数据（优先从 js-initialData）
  Future<ScrapedMetadata?> _extractMetadata(
    InAppWebViewController controller,
    ZhihuContentType contentType,
  ) async {
    // 优先从 js-initialData 提取
    var metadata = await _extractFromInitialData(controller, contentType);
    if (metadata?.isValid == true) return metadata;

    // 降级到 OG 标签
    metadata = await _extractFromOgTags(controller);
    if (metadata?.isValid == true) return metadata;

    return null;
  }

  /// 从 js-initialData 提取
  Future<ScrapedMetadata?> _extractFromInitialData(
    InAppWebViewController controller,
    ZhihuContentType contentType,
  ) async {
    // 调试日志：打印 js-initialData 的结构
    final debugJs = '''
(function() {
  try {
    var el = document.getElementById('js-initialData');
    if (!el) return 'ELEMENT_NOT_FOUND';
    var data = JSON.parse(el.textContent);
    if (!data || !data.initialState) return 'NO_INITIAL_STATE';
    var entities = data.initialState.entities;
    if (!entities) return 'NO_ENTITIES';
    return JSON.stringify(Object.keys(entities));
  } catch (e) {
    return 'ERROR: ' + e.message;
  }
})()
''';
    final debugResult = await controller.evaluateJavascript(source: debugJs);
    PMlog.d(_tag, 'js-initialData entities: $debugResult');

    final extractJs =
        '''
(function() {
  try {
    var el = document.getElementById('js-initialData');
    if (!el) return null;
    
    var data = JSON.parse(el.textContent);
    var entities = data?.initialState?.entities;
    if (!entities) return null;
    
    var type = '${contentType.value}';
    var result = null;
    
    function extractImages(html) {
      var imgs = [];
      var matches = (html || '').match(/<img[^>]+src="([^"]+)"/g) || [];
      matches.forEach(function(m) {
        var src = m.match(/src="([^"]+)"/);
        if (src && src[1]) imgs.push(src[1]);
      });
      return imgs;
    }
    
    if (type === 'answer' || type === 'answer_short') {
      var answers = entities.answers || {};
      var key = Object.keys(answers)[0];
      if (key) {
        var a = answers[key];
        result = {
          title: a.question?.title || '',
          content: a.content || a.excerpt || '',
          desc: a.excerpt || '',
          images: extractImages(a.content)
        };
      }
    } else if (type === 'question') {
      var questions = entities.questions || {};
      var key = Object.keys(questions)[0];
      if (key) {
        var q = questions[key];
        result = {
          title: q.title || '',
          content: q.detail || q.excerpt || '',
          desc: q.excerpt || '',
          images: extractImages(q.detail)
        };
      }
    } else if (type === 'article') {
      var articles = entities.articles || {};
      var key = Object.keys(articles)[0];
      if (key) {
        var ar = articles[key];
        var imgs = ar.imageUrl ? [ar.imageUrl] : [];
        imgs = imgs.concat(extractImages(ar.content));
        result = {
          title: ar.title || '',
          content: ar.content || ar.excerpt || '',
          desc: ar.excerpt || '',
          images: imgs
        };
      }
    } else if (type === 'zvideo') {
      var zvideos = entities.zvideos || {};
      var key = Object.keys(zvideos)[0];
      if (key) {
        var v = zvideos[key];
        result = {
          title: v.title || '',
          content: v.description || '',
          desc: v.description || '',
          images: v.video?.thumbnail ? [v.video.thumbnail] : []
        };
      }
    }
    
    return result ? JSON.stringify(result) : null;
  } catch (e) {
    return null;
  }
})()
''';

    try {
      final result = await controller.evaluateJavascript(source: extractJs);
      if (result == null || result == 'null') return null;

      final data = jsonDecode(result as String);
      final content = _stripHtmlTags(data['content'] ?? '');
      final images = _normalizeImageUrls(
        List<String>.from(data['images'] ?? []),
      );

      return ScrapedMetadata(
        title: data['title'] as String?,
        description: data['desc'] as String?,
        content: content.isNotEmpty ? content : null,
        images: images,
      );
    } catch (e) {
      PMlog.e(_tag, '提取 js-initialData 失败: $e');
      return null;
    }
  }

  /// 从 OG 标签提取（降级方案）
  Future<ScrapedMetadata?> _extractFromOgTags(
    InAppWebViewController controller,
  ) async {
    try {
      final result = await controller.evaluateJavascript(
        source: '''
(function() {
  var title = document.querySelector('meta[property="og:title"]')?.content ||
              document.querySelector('title')?.innerText || '';
  var desc = document.querySelector('meta[property="og:description"]')?.content ||
             document.querySelector('meta[name="description"]')?.content || '';
  var imgs = [];
  document.querySelectorAll('meta[property="og:image"]').forEach(function(el) {
    var c = el.content;
    if (c && c.startsWith('http')) imgs.push(c);
  });
  return JSON.stringify({ title: title, desc: desc, images: imgs });
})()
''',
      );
      if (result == null || result == 'null') return null;

      final data = jsonDecode(result as String);
      return ScrapedMetadata(
        title: data['title'] as String?,
        description: data['desc'] as String?,
        images: _normalizeImageUrls(List<String>.from(data['images'] ?? [])),
      );
    } catch (_) {
      return null;
    }
  }

  /// 去除 HTML 标签
  String _stripHtmlTags(String html) {
    if (html.isEmpty) return '';
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 规范化图片 URL
  List<String> _normalizeImageUrls(List<String> urls) {
    final seen = <String>{};
    return urls
        .where((u) => u.isNotEmpty && !u.startsWith('data:'))
        .map(
          (u) => u.startsWith('http://')
              ? u.replaceFirst('http://', 'https://')
              : u,
        )
        .where((u) => seen.add(u))
        .toList();
  }

  /// 请求头（伪装成 Chrome 桌面浏览器）
  static const Map<String, String> _requestHeaders = {
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    'Sec-Ch-Ua':
        '"Chromium";v="128", "Google Chrome";v="128", "Not;A=Brand";v="24"',
    'Sec-Ch-Ua-Mobile': '?0',
    'Sec-Ch-Ua-Platform': '"macOS"',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Upgrade-Insecure-Requests': '1',
  };

  /// 反检测脚本（隐藏 WebView 特征）
  static const String _antiDetectScript = '''
(function() {
  Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
  Object.defineProperty(navigator, 'platform', { get: () => 'MacIntel' });
  Object.defineProperty(navigator, 'vendor', { get: () => 'Google Inc.' });
  Object.defineProperty(navigator, 'languages', { get: () => ['zh-CN', 'zh', 'en'] });
  Object.defineProperty(navigator, 'hardwareConcurrency', { get: () => 8 });
  Object.defineProperty(navigator, 'deviceMemory', { get: () => 8 });
  Object.defineProperty(navigator, 'userAgentData', {
    get: () => ({
      brands: [
        { brand: "Chromium", version: "128" },
        { brand: "Google Chrome", version: "128" },
        { brand: "Not;A=Brand", version: "24" }
      ],
      mobile: false,
      platform: "macOS",
      getHighEntropyValues: () => Promise.resolve({
        mobile: false, platform: "macOS",
        platformVersion: "10.15.7", architecture: "x86", bitness: "64"
      })
    })
  });
  Object.defineProperty(navigator, 'plugins', {
    get: () => {
      var arr = [
        { name: 'Chrome PDF Plugin', filename: 'internal-pdf-viewer' },
        { name: 'Chrome PDF Viewer', filename: 'mhjfbmdgcfjbbpaeojofohoefgiehjai' }
      ];
      arr.item = i => arr[i] || null;
      arr.namedItem = n => arr.find(p => p.name === n) || null;
      return arr;
    }
  });
  window.chrome = { runtime: {}, loadTimes: () => ({}), csi: () => ({}) };
})();
''';
}
