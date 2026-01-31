import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'package:pocketmind/service/scraper/platform_scraper_interface.dart';
import 'package:pocketmind/service/scraper/stealth_js_loader.dart';

/// B站内容类型
enum BilibiliContentType {
  video('video'), // 普通视频
  bangumi('bangumi'), // 番剧
  read('read'), // 专栏文章
  opus('opus'); // 动态/图文

  final String value;
  const BilibiliContentType(this.value);
}

/// B站爬虫实现
///
/// 支持的 URL 格式：
/// - 视频: https://www.bilibili.com/video/BVxxxxxx
/// - 视频: https://www.bilibili.com/video/avxxxxxx
/// - 短链接: https://b23.tv/xxxxx (会自动重定向到真实 URL)
/// - 番剧: https://www.bilibili.com/bangumi/play/epxxxxxx
/// - 专栏: https://www.bilibili.com/read/cvxxxxxx
///
/// 短链接 b23.tv 会被 WebView 自动重定向，根据最终 URL 判断内容类型
class BilibiliScraper implements IPlatformScraper {
  static const String _tag = 'BilibiliScraper';
  static const String _domain = 'https://www.bilibili.com';
  static const String _cookieDomain = '.bilibili.com';
  static const String _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/128.0.0.0 Safari/537.36';
  static const Duration _renderWaitTime = Duration(seconds: 2);
  static const Duration _timeout = Duration(seconds: 25);

  /// B站无需登录即可访问公开内容，但有 SESSDATA Cookie 更稳定
  @override
  List<String> getRequiredCookieNames() => [];

  @override
  bool validateCookies(Map<String, String> cookieDict) => true;

  @override
  Future<ScrapedMetadata?> scrape(
    String url,
    Map<String, String> cookieDict,
  ) async {
    final startTime = DateTime.now();
    PMlog.d(_tag, '开始爬取: $url');

    // 清理 URL
    final cleanUrl = _cleanUrl(url);

    // 对于 b23.tv 短链接，需要等 WebView 重定向后才能判断类型
    // 所以先不判断内容类型，等加载完成后再判断
    final isShortUrl = cleanUrl.contains('b23.tv');
    if (!isShortUrl) {
      final contentType = _judgeContentType(cleanUrl);
      if (contentType == null) {
        PMlog.e(_tag, '无法识别的 B站 URL 类型: $cleanUrl');
        return null;
      }
      PMlog.d(_tag, '内容类型: ${contentType.value}, 目标URL: $cleanUrl');
    } else {
      PMlog.d(_tag, '检测到短链接，等待重定向: $cleanUrl');
    }

    HeadlessInAppWebView? headlessWebView;
    InAppWebViewController? controller;
    bool isDisposed = false;
    String? finalUrl; // 存储重定向后的最终 URL

    try {
      final stealthJs = await StealthJsLoader().getStealthJs();
      if (cookieDict.isNotEmpty) {
        await _setCookies(cookieDict);
      }

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
        onLoadStop: (ctrl, loadedUrl) async {
          if (isDisposed || completer.isCompleted) return;

          // 记录最终 URL（处理短链接重定向）
          finalUrl = loadedUrl?.toString();
          PMlog.d(_tag, '页面加载完成，最终URL: $finalUrl');

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
        onReceivedHttpError: (_, __, response) {
          // B站 404 等错误
          if (response.statusCode == 404) {
            PMlog.w(_tag, '视频不存在或已被删除');
            loadError = true;
          }
          if (!completer.isCompleted) completer.complete();
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
        if (controller != null && pageHtml == null) {
          try {
            pageHtml = await controller!.getHtml();
            finalUrl ??= await controller!.getUrl().then((u) => u?.toString());
          } catch (_) {}
        }
      }

      if (loadError) {
        PMlog.e(_tag, '网络连接错误或视频不存在');
        return null;
      }

      if (pageHtml == null || pageHtml!.isEmpty) {
        PMlog.e(_tag, '页面加载失败${timedOut ? "（超时）" : ""}');
        return null;
      }

      PMlog.d(_tag, 'HTML 长度: ${pageHtml!.length}');

      // 根据最终 URL 判断内容类型（处理短链接重定向后的情况）
      final actualUrl = finalUrl ?? cleanUrl;
      final contentType = _judgeContentType(actualUrl);
      if (contentType == null) {
        PMlog.e(_tag, '无法识别重定向后的 URL 类型: $actualUrl');
        return null;
      }
      PMlog.d(_tag, '最终内容类型: ${contentType.value}');

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
      // 移除常见的追踪参数
      final cleanParams = Map<String, String>.from(uri.queryParameters)
        ..removeWhere(
          (k, _) =>
              k.startsWith('spm_') ||
              k.startsWith('from_') ||
              k == 'share_source' ||
              k == 'share_medium' ||
              k == 'share_plat' ||
              k == 'share_session_id' ||
              k == 'share_tag' ||
              k == 'share_times' ||
              k == 'timestamp' ||
              k == 'bbid' ||
              k == 'ts' ||
              k == 'vd_source',
        );
      return cleanParams.isEmpty
          ? '${uri.scheme}://${uri.host}${uri.path}'
          : uri.replace(queryParameters: cleanParams).toString();
    } catch (_) {
      return url;
    }
  }

  /// 判断 B站 URL 类型
  BilibiliContentType? _judgeContentType(String url) {
    if (url.contains('/video/')) return BilibiliContentType.video;
    if (url.contains('/bangumi/')) return BilibiliContentType.bangumi;
    if (url.contains('/read/')) return BilibiliContentType.read;
    if (url.contains('/opus/')) return BilibiliContentType.opus;
    // b23.tv 短链接会被重定向，不在这里判断
    if (url.contains('b23.tv')) return BilibiliContentType.video;
    return null;
  }

  /// 设置 Cookie
  Future<void> _setCookies(Map<String, String> cookieDict) async {
    final cookieManager = CookieManager.instance();
    final expiry = DateTime.now()
        .add(const Duration(days: 30))
        .millisecondsSinceEpoch;

    for (var entry in cookieDict.entries) {
      await cookieManager.setCookie(
        url: WebUri(_domain),
        name: entry.key,
        value: entry.value,
        domain: _cookieDomain,
        path: '/',
        expiresDate: expiry,
      );
    }
  }

  /// 提取元数据
  Future<ScrapedMetadata?> _extractMetadata(
    InAppWebViewController controller,
    BilibiliContentType contentType,
  ) async {
    final metadata = await _extractFromInitialState(controller, contentType);
    if (metadata?.isValid == true) return metadata;

    PMlog.w(_tag, '__INITIAL_STATE__ 提取失败');
    return null;
  }

  /// 从 window.__INITIAL_STATE__ 提取 B站页面数据
  Future<ScrapedMetadata?> _extractFromInitialState(
    InAppWebViewController controller,
    BilibiliContentType contentType,
  ) async {
    // 调试：打印数据结构，用于排查平台变更
    final debugJs = '''
(function() {
  try {
    var state = window.__INITIAL_STATE__;
    if (!state) return 'STATE_NOT_FOUND';
    if (state.detail && state.detail.modules) {
      var modTypes = state.detail.modules.map(function(m) { 
        return m.module_type + ':' + Object.keys(m).join(','); 
      });
      return JSON.stringify({type: 'opus', modules: modTypes});
    }
    if (state.readInfo) return JSON.stringify({type: 'read', keys: Object.keys(state.readInfo)});
    if (state.videoData) return JSON.stringify({type: 'video', keys: Object.keys(state.videoData)});
    return JSON.stringify({type: 'unknown', keys: Object.keys(state)});
  } catch (e) {
    return 'ERROR: ' + e.message;
  }
})()
''';
    final debugResult = await controller.evaluateJavascript(source: debugJs);
    PMlog.d(_tag, '__INITIAL_STATE__ structure: $debugResult');

    final extractJs =
        '''
(function() {
  try {
    var state = window.__INITIAL_STATE__;
    if (!state) return null;
    
    var type = '${contentType.value}';
    var result = null;
    
    if (type === 'video') {
      // 普通视频
      var videoData = state.videoData;
      if (videoData) {
        result = {
          title: videoData.title || '',
          desc: videoData.desc || '',
          cover: videoData.pic || '',
          // 额外信息
          bvid: videoData.bvid || '',
          aid: videoData.aid || '',
          duration: videoData.duration || 0,
          pubdate: videoData.pubdate || 0,
          owner: videoData.owner ? {
            name: videoData.owner.name || '',
            face: videoData.owner.face || ''
          } : null,
          stat: videoData.stat ? {
            view: videoData.stat.view || 0,
            danmaku: videoData.stat.danmaku || 0,
            like: videoData.stat.like || 0,
            coin: videoData.stat.coin || 0,
            favorite: videoData.stat.favorite || 0,
            share: videoData.stat.share || 0
          } : null
        };
      }
    } else if (type === 'bangumi') {
      // 番剧
      var mediaInfo = state.mediaInfo;
      var epInfo = state.epInfo;
      if (mediaInfo) {
        result = {
          title: mediaInfo.title || (epInfo ? epInfo.share_copy : ''),
          desc: mediaInfo.evaluate || mediaInfo.description || '',
          cover: mediaInfo.cover || (epInfo ? epInfo.cover : ''),
          // 番剧特有信息
          seasonId: mediaInfo.season_id || '',
          rating: mediaInfo.rating ? mediaInfo.rating.score : null
        };
      } else if (epInfo) {
        result = {
          title: epInfo.share_copy || epInfo.long_title || '',
          desc: '',
          cover: epInfo.cover || ''
        };
      }
    } else if (type === 'read') {
      // 专栏文章
      var readInfo = state.readInfo;
      if (readInfo) {
        // 提取所有图片
        var images = [];
        
        // 方法1: 从 image_urls 获取（优先）
        if (readInfo.image_urls && readInfo.image_urls.length > 0) {
          images = images.concat(readInfo.image_urls);
        }
        
        // 方法2: 从 origin_image_urls 获取
        if (readInfo.origin_image_urls && readInfo.origin_image_urls.length > 0) {
          readInfo.origin_image_urls.forEach(function(url) {
            if (images.indexOf(url) === -1) images.push(url);
          });
        }
        
        // 方法3: 从 content HTML 中提取
        var content = readInfo.content || '';
        var imgRegex = /<img[^>]+data-src="([^"]+)"|<img[^>]+src="([^"]+)"/g;
        var match;
        while ((match = imgRegex.exec(content)) !== null) {
          var imgUrl = match[1] || match[2];
          if (imgUrl && images.indexOf(imgUrl) === -1) {
            images.push(imgUrl);
          }
        }
        
        // 提取纯文本内容（移除 HTML 标签）
        var plainText = content
          .replace(/<figure[^>]*>.*?<\\/figure>/gis, '') // 移除 figure（图片容器）
          .replace(/<img[^>]*>/gi, '[图片]')  // 图片占位
          .replace(/<br\\s*\\/?>/gi, '\\n')   // 换行
          .replace(/<p[^>]*>/gi, '')         // 段落开始
          .replace(/<\\/p>/gi, '\\n\\n')     // 段落结束
          .replace(/<[^>]+>/g, '')           // 移除其他标签
          .replace(/&nbsp;/g, ' ')           // 空格
          .replace(/&lt;/g, '<')
          .replace(/&gt;/g, '>')
          .replace(/&amp;/g, '&')
          .replace(/&quot;/g, '"')
          .replace(/\\n{3,}/g, '\\n\\n')     // 多个换行合并
          .trim();
        
        result = {
          title: readInfo.title || '',
          desc: plainText || readInfo.summary || '',
          cover: readInfo.banner_url || (images.length > 0 ? images[0] : ''),
          images: images,
          cvid: readInfo.id || ''
        };
      }
    } else if (type === 'opus') {
      // 动态/图文 - modules 是数组结构
      var detail = state.detail;
      if (detail) {
        var title = '';
        var desc = '';
        var cover = '';
        var images = [];
        
        // 遍历 modules 数组提取数据
        var modules = detail.modules || [];
        for (var i = 0; i < modules.length; i++) {
          var mod = modules[i];
          var modType = mod.module_type;
          
          if (modType === 'MODULE_TYPE_TITLE' && mod.module_title) {
            title = mod.module_title.text || '';
          }
          
          if (modType === 'MODULE_TYPE_DESC' && mod.module_desc) {
            desc = mod.module_desc.text || '';
          }
          
          // 图片模块
          if (modType === 'MODULE_TYPE_PIC' && mod.module_pic) {
            var pics = mod.module_pic.pics || [];
            pics.forEach(function(pic) {
              var url = pic.url || pic.src || '';
              if (url && images.indexOf(url) === -1) {
                images.push(url);
              }
            });
            if (pics.length > 0 && !cover) {
              cover = pics[0].url || pics[0].src || '';
            }
          }
          
          // 内容模块（包含段落和图片）
          if (modType === 'MODULE_TYPE_CONTENT' && mod.module_content) {
            var content = mod.module_content;
            
            // 段落内容
            if (content.paragraphs && content.paragraphs.length > 0) {
              var texts = [];
              content.paragraphs.forEach(function(p) {
                var paraText = '';
                if (p.text && p.text.nodes) {
                  p.text.nodes.forEach(function(n) {
                    if (n.word && n.word.words) paraText += n.word.words;
                    if (n.rich_text && n.rich_text.text) paraText += n.rich_text.text;
                  });
                }
                if (paraText) texts.push(paraText);
                // 图片段落
                if (p.pic && p.pic.pics && p.pic.pics.length > 0) {
                  p.pic.pics.forEach(function(pic) {
                    var url = pic.url || pic.src || '';
                    if (url && images.indexOf(url) === -1) {
                      images.push(url);
                    }
                    if (!cover && url) cover = url;
                  });
                }
              });
              if (!desc) desc = texts.join('\\n');
            }
            
            if (content.pics && content.pics.length > 0) {
              content.pics.forEach(function(pic) {
                var url = pic.url || pic.src || '';
                if (url && images.indexOf(url) === -1) {
                  images.push(url);
                }
              });
              if (!cover) cover = content.pics[0].url || content.pics[0].src || '';
            }
            if (content.pictures && content.pictures.length > 0) {
              content.pictures.forEach(function(pic) {
                var url = pic.url || pic.src || '';
                if (url && images.indexOf(url) === -1) {
                  images.push(url);
                }
              });
              if (!cover) cover = content.pictures[0].url || content.pictures[0].src || '';
            }
          }
          
          if (modType === 'MODULE_TYPE_COVER' && mod.module_cover) {
            var coverUrl = mod.module_cover.url || mod.module_cover.src || '';
            if (!cover && coverUrl) {
              cover = coverUrl;
            }
            if (coverUrl && images.indexOf(coverUrl) === -1) {
              images.push(coverUrl);
            }
          }
        }
        
        // 如果没有标题，用描述前50字
        if (!title && desc) {
          title = desc.substring(0, 50) + (desc.length > 50 ? '...' : '');
        }
        
        result = {
          title: title,
          desc: desc,
          cover: cover,
          images: images,
          opusId: detail.id_str || ''
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
      if (result == null || result == 'null') {
        PMlog.w(_tag, '__INITIAL_STATE__ 提取失败');
        return null;
      }

      final data = jsonDecode(result as String);
      PMlog.d(_tag, '从 __INITIAL_STATE__ 提取成功: ${data['title']}');

      final images = <String>[];

      // 优先使用 images 数组
      if (data['images'] != null && data['images'] is List) {
        for (var imgUrl in (data['images'] as List)) {
          if (imgUrl != null && imgUrl.toString().isNotEmpty) {
            var url = imgUrl.toString();
            // B站图片 URL 可能是 // 开头，需要补全协议
            if (url.startsWith('//')) {
              url = 'https:$url';
            } else if (!url.startsWith('http')) {
              url = 'https://$url';
            }
            if (!images.contains(url)) {
              images.add(url);
            }
          }
        }
      }

      // 如果没有 images 数组，使用 cover
      if (images.isEmpty) {
        final cover = data['cover'] as String?;
        if (cover != null && cover.isNotEmpty) {
          var normalizedCover = cover;
          if (cover.startsWith('//')) {
            normalizedCover = 'https:$cover';
          } else if (!cover.startsWith('http')) {
            normalizedCover = 'https://$cover';
          }
          images.add(normalizedCover);
        }
      }

      PMlog.d(_tag, '提取到 ${images.length} 张图片');

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

  /// 请求头
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

  /// 反检测脚本
  static const String _antiDetectScript = '''
(function() {
  Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
  Object.defineProperty(navigator, 'platform', { get: () => 'MacIntel' });
  Object.defineProperty(navigator, 'vendor', { get: () => 'Google Inc.' });
  Object.defineProperty(navigator, 'languages', { get: () => ['zh-CN', 'zh', 'en'] });
  Object.defineProperty(navigator, 'hardwareConcurrency', { get: () => 8 });
  Object.defineProperty(navigator, 'deviceMemory', { get: () => 8 });
  window.chrome = { runtime: {}, loadTimes: () => ({}), csi: () => ({}) };
})();
''';
}
