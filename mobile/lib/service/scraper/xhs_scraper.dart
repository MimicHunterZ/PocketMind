import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'package:pocketmind/service/scraper/platform_scraper_interface.dart';
import 'package:pocketmind/service/scraper/stealth_js_loader.dart';

/// 小红书爬虫实现
///
/// 使用 HeadlessInAppWebView 加载小红书页面并提取数据
/// 参考 MediaCrawler xhs/core.py 和 xhs/extractor.py 实现
class XhsScraper implements IPlatformScraper {
  static const String _tag = 'XhsScraper';

  /// 小红书首页域名
  static const String _domain = 'https://www.xiaohongshu.com';

  /// Cookie 域名
  static const String _cookieDomain = '.xiaohongshu.com';

  /// UserAgent
  static const String _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/126.0.0.0 Safari/537.36';

  /// 页面加载后等待时间（等待 Vue 渲染）
  static const Duration _renderWaitTime = Duration(seconds: 2);

  /// 总超时时间
  static const Duration _timeout = Duration(seconds: 20);

  @override
  String getPlatformName() => '小红书';

  @override
  String getPlatformId() => 'xhs';

  @override
  bool requiresCookie() => true;

  @override
  List<String> getRequiredCookieNames() => ['a1', 'webId'];

  @override
  bool validateCookies(Map<String, String> cookieDict) {
    final required = getRequiredCookieNames();
    for (var name in required) {
      if (!cookieDict.containsKey(name) || cookieDict[name]!.isEmpty) {
        return false;
      }
    }
    return true;
  }

  @override
  Future<ScrapedMetadata?> scrape(
    String url,
    Map<String, String> cookieDict,
  ) async {
    final startTime = DateTime.now();
    PMlog.d(_tag, '开始爬取: $url');

    // 1. 验证 Cookie
    if (!validateCookies(cookieDict)) {
      final missing = getRequiredCookieNames()
          .where((name) => !cookieDict.containsKey(name))
          .toList();
      PMlog.e(_tag, 'Cookie 不完整, 缺少: $missing');
      throw CookieExpiredException('缺少必需Cookie: $missing', platform: 'xhs');
    }

    HeadlessInAppWebView? headlessWebView;
    InAppWebViewController? controller;
    bool isDisposed = false; // 标记 WebView 是否已释放

    try {
      // 2. 获取 stealth.js
      final stealthJs = await StealthJsLoader().getStealthJs();
      PMlog.d(_tag, 'stealth.js 已加载, 大小: ${stealthJs.length}');

      // 3. 设置 Cookie
      await _setCookies(cookieDict);
      PMlog.d(_tag, 'Cookie 已设置: ${cookieDict.keys.join(", ")}');

      // 4. 创建 HeadlessInAppWebView
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
          // 禁用一些可能导致检测的特性
          mediaPlaybackRequiresUserGesture: true,
          allowsInlineMediaPlayback: false,
        ),
        onWebViewCreated: (ctrl) {
          controller = ctrl;
          PMlog.d(_tag, 'WebView 已创建');

          // 注入 stealth.js（在 document 开始时）
          if (stealthJs.isNotEmpty) {
            ctrl.addUserScript(
              userScript: UserScript(
                source: stealthJs,
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              ),
            );
          }
        },
        onLoadStart: (ctrl, loadedUrl) {
          PMlog.d(_tag, '开始加载: $loadedUrl');
        },
        onLoadStop: (ctrl, loadedUrl) async {
          PMlog.d(_tag, '加载完成: $loadedUrl');

          // 检查是否已释放
          if (isDisposed || completer.isCompleted) {
            return;
          }

          // 等待 Vue 渲染
          await Future.delayed(_renderWaitTime);

          // 再次检查是否已释放
          if (isDisposed || completer.isCompleted) {
            return;
          }

          PMlog.d(_tag, '等待渲染完成');

          // 获取 HTML
          try {
            pageHtml = await ctrl.getHtml();
          } catch (e) {
            PMlog.w(_tag, '获取 HTML 时出错（可能 WebView 已释放）: $e');
          }

          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onReceivedError: (ctrl, request, error) {
          PMlog.e(_tag, '加载错误: ${error.description}');
          // 忽略图片等资源加载错误，只关注主请求
          if (request.url.toString() == url ||
              request.url.toString().contains('xiaohongshu.com')) {
            // 只有当是 net::ERR 类型的严重错误时才标记失败
            // chrome-extension 加载失败等可以忽略
            if (error.description.contains('ERR_CONNECTION') ||
                error.description.contains('ERR_NAME_NOT_RESOLVED') ||
                error.description.contains('ERR_INTERNET')) {
              loadError = true;
              if (!completer.isCompleted) {
                completer.complete();
              }
            }
          }
        },
        onReceivedHttpError: (ctrl, request, response) {
          PMlog.e(_tag, 'HTTP 错误: ${response.statusCode}');
          if (response.statusCode == 403 || response.statusCode == 401) {
            loadError = true;
          }
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      // 5. 启动 WebView 并加载页面
      await headlessWebView.run();
      PMlog.d(_tag, 'HeadlessWebView 已启动');

      await controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));

      // 6. 等待加载完成（带超时）
      await completer.future.timeout(
        _timeout,
        onTimeout: () {
          PMlog.w(_tag, '加载超时');
        },
      );

      if (loadError) {
        throw CookieExpiredException('页面加载失败，可能Cookie已过期', platform: 'xhs');
      }

      if (pageHtml == null || pageHtml!.isEmpty) {
        PMlog.e(_tag, '获取 HTML 失败');
        return null;
      }

      // 7. 检测是否需要登录/验证
      if (await _checkNeedLogin(controller!, pageHtml!)) {
        throw CookieExpiredException('检测到需要登录验证', platform: 'xhs');
      }

      // 8. 提取数据
      final metadata = await _extractMetadata(controller!, url, pageHtml!);

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      PMlog.d(
        _tag,
        '爬取完成: title=${metadata?.title}, '
        'images=${metadata?.images.length}, '
        'duration=${duration}ms',
      );

      return metadata;
    } catch (e) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      PMlog.e(_tag, '爬取失败: $e, duration=${duration}ms');

      if (e is CookieExpiredException) {
        rethrow;
      }

      return null;
    } finally {
      // 9. 清理资源
      // 先标记为已释放，防止回调继续使用 controller
      isDisposed = true;

      try {
        await controller?.stopLoading();
        // 使用新的 clearAllCache 替代已废弃的 clearCache
        await InAppWebViewController.clearAllCache();
        await headlessWebView?.dispose();
        PMlog.d(_tag, 'WebView 资源已清理');
      } catch (e) {
        PMlog.w(_tag, '清理资源时出错: $e');
      }
    }
  }

  /// 设置 Cookie
  Future<void> _setCookies(Map<String, String> cookieDict) async {
    final cookieManager = CookieManager.instance();

    for (var entry in cookieDict.entries) {
      await cookieManager.setCookie(
        url: WebUri(_domain),
        name: entry.key,
        value: entry.value,
        domain: _cookieDomain,
        path: '/',
        expiresDate: DateTime.now()
            .add(const Duration(days: 30))
            .millisecondsSinceEpoch,
      );
    }
  }

  /// 检测是否需要登录
  Future<bool> _checkNeedLogin(
    InAppWebViewController controller,
    String html,
  ) async {
    // 参考 MediaCrawler 的错误检测
    // IP_ERROR_STR = "网络连接异常，请检查网络设置或重启试试"
    final checkJs = '''
      (function() {
        var bodyText = document.body ? document.body.innerText : '';
        if (bodyText.includes('网络连接异常') || 
            bodyText.includes('请检查网络设置') ||
            bodyText.includes('请先登录') ||
            bodyText.includes('验证码')) {
          return true;
        }
        return false;
      })()
    ''';

    try {
      final result = await controller.evaluateJavascript(source: checkJs);
      return result == true;
    } catch (e) {
      PMlog.w(_tag, '检测登录状态失败: $e');
      return false;
    }
  }

  /// 提取元数据
  Future<ScrapedMetadata?> _extractMetadata(
    InAppWebViewController controller,
    String url,
    String html,
  ) async {
    // 尝试从 window.__INITIAL_STATE__ 提取（参考 MediaCrawler xhs/extractor.py）
    var metadata = await _extractFromInitialState(controller, url);

    if (metadata != null && metadata.isValid) {
      PMlog.d(_tag, '从 __INITIAL_STATE__ 提取成功');
      return metadata;
    }

    // 降级到 OG 标签提取
    PMlog.d(_tag, '__INITIAL_STATE__ 提取失败，尝试 OG 标签');
    metadata = await _extractFromOgTags(controller);

    if (metadata != null && metadata.isValid) {
      PMlog.d(_tag, '从 OG 标签提取成功');
      return metadata;
    }

    PMlog.w(_tag, '所有提取方法均失败');
    return null;
  }

  /// 从 window.__INITIAL_STATE__ 提取
  ///
  /// 参考 MediaCrawler xhs/extractor.py:
  /// state = re.findall(r"window.__INITIAL_STATE__=({.*})</script>", html)
  /// note_dict = state["note"]["noteDetailMap"][note_id]["note"]
  Future<ScrapedMetadata?> _extractFromInitialState(
    InAppWebViewController controller,
    String url,
  ) async {
    // 提取笔记 ID
    final noteId = _extractNoteId(url);
    if (noteId == null) {
      PMlog.w(_tag, '无法从 URL 提取笔记 ID');
      return null;
    }

    PMlog.d(_tag, '提取到笔记 ID: $noteId');

    // 执行 JS 提取 __INITIAL_STATE__
    final extractJs =
        '''
      (function() {
        try {
          if (typeof window.__INITIAL_STATE__ === 'undefined') {
            return null;
          }
          
          var state = window.__INITIAL_STATE__;
          if (!state || !state.note || !state.note.noteDetailMap) {
            return null;
          }
          
          var noteId = '$noteId';
          var noteData = state.note.noteDetailMap[noteId];
          
          if (!noteData || !noteData.note) {
            // 尝试遍历查找
            var keys = Object.keys(state.note.noteDetailMap);
            if (keys.length > 0) {
              noteData = state.note.noteDetailMap[keys[0]];
            }
          }
          
          if (!noteData || !noteData.note) {
            return null;
          }
          
          var note = noteData.note;
          
          // 提取图片列表
          var images = [];
          if (note.imageList && Array.isArray(note.imageList)) {
            note.imageList.forEach(function(img) {
              if (img.urlDefault) {
                images.push(img.urlDefault);
              } else if (img.url) {
                images.push(img.url);
              }
            });
          }
          
          return JSON.stringify({
            title: note.title || '',
            desc: note.desc || '',
            images: images,
            type: note.type || 'normal'
          });
        } catch (e) {
          return null;
        }
      })()
    ''';

    try {
      final result = await controller.evaluateJavascript(source: extractJs);

      if (result == null || result == 'null') {
        return null;
      }

      final data = jsonDecode(result as String);

      // 规范化图片 URL（去重、HTTP 转 HTTPS）
      final rawImages = List<String>.from(data['images'] ?? []);
      final images = _normalizeImageUrls(rawImages);

      return ScrapedMetadata(
        title: data['title'] as String?,
        description: data['desc'] as String?,
        images: images,
        rawData: data,
      );
    } catch (e) {
      PMlog.e(_tag, '提取 __INITIAL_STATE__ 失败: $e');
      return null;
    }
  }

  /// 从 OG 标签提取
  Future<ScrapedMetadata?> _extractFromOgTags(
    InAppWebViewController controller,
  ) async {
    final extractJs = '''
      (function() {
        try {
          // 提取标题
          var title = '';
          var ogTitle = document.querySelector('meta[property="og:title"]');
          if (ogTitle) {
            title = ogTitle.getAttribute('content') || '';
          } else {
            var titleTag = document.querySelector('title');
            if (titleTag) {
              title = titleTag.innerText || '';
            }
          }
          
          // 提取描述
          var desc = '';
          var ogDesc = document.querySelector('meta[property="og:description"]');
          if (ogDesc) {
            desc = ogDesc.getAttribute('content') || '';
          } else {
            var metaDesc = document.querySelector('meta[name="description"]');
            if (metaDesc) {
              desc = metaDesc.getAttribute('content') || '';
            }
          }
          
          // 提取所有 OG 图片（支持多图，使用 Set 去重）
          var imageSet = new Set();
          var ogImages = document.querySelectorAll('meta[property="og:image"]');
          ogImages.forEach(function(el) {
            var content = el.getAttribute('content');
            if (content && content.startsWith('http')) {
              imageSet.add(content);
            }
          });
          
          // 如果没有 OG 图片，尝试提取页面内的主要图片
          if (imageSet.size === 0) {
            var mainImages = document.querySelectorAll('.note-content img, .swiper-slide img');
            mainImages.forEach(function(img) {
              var src = img.getAttribute('src') || img.getAttribute('data-src');
              if (src && src.startsWith('http')) {
                imageSet.add(src);
              }
            });
          }
          
          return JSON.stringify({
            title: title,
            desc: desc,
            images: Array.from(imageSet)
          });
        } catch (e) {
          return null;
        }
      })()
    ''';

    try {
      final result = await controller.evaluateJavascript(source: extractJs);

      if (result == null || result == 'null') {
        return null;
      }

      final data = jsonDecode(result as String);

      // 提取图片列表并去重、转换 HTTP 为 HTTPS
      final rawImages = List<String>.from(data['images'] ?? []);
      final images = _normalizeImageUrls(rawImages);

      return ScrapedMetadata(
        title: data['title'] as String?,
        description: data['desc'] as String?,
        images: images,
      );
    } catch (e) {
      PMlog.e(_tag, '提取 OG 标签失败: $e');
      return null;
    }
  }

  /// 规范化图片 URL 列表
  ///
  /// - 去重
  /// - HTTP 转 HTTPS（小红书 CDN 支持 HTTPS）
  List<String> _normalizeImageUrls(List<String> urls) {
    final seen = <String>{};
    final result = <String>[];

    for (var url in urls) {
      // HTTP 转 HTTPS
      var normalizedUrl = url;
      if (url.startsWith('http://')) {
        normalizedUrl = url.replaceFirst('http://', 'https://');
      }

      // 去重（基于规范化后的 URL）
      if (!seen.contains(normalizedUrl)) {
        seen.add(normalizedUrl);
        result.add(normalizedUrl);
      }
    }

    return result;
  }

  /// 从 URL 提取笔记 ID
  String? _extractNoteId(String url) {
    // 小红书笔记 URL 格式：
    // https://www.xiaohongshu.com/explore/xxxxx
    // https://www.xiaohongshu.com/discovery/item/xxxxx
    // https://xhslink.com/xxxxx

    // 尝试匹配 explore/xxxxx 格式
    final exploreMatch = RegExp(r'/explore/([a-zA-Z0-9]+)').firstMatch(url);
    if (exploreMatch != null) {
      return exploreMatch.group(1);
    }

    // 尝试匹配 discovery/item/xxxxx 格式
    final discoveryMatch = RegExp(
      r'/discovery/item/([a-zA-Z0-9]+)',
    ).firstMatch(url);
    if (discoveryMatch != null) {
      return discoveryMatch.group(1);
    }

    // 短链接需要先解析真实 URL，这里暂时返回 null
    // 实际使用时 WebView 会自动跳转到真实 URL
    return null;
  }
}
