import 'package:pocketmind/api/models/note_metadata.dart';
import 'package:pocketmind/service/cookie_manager_service.dart';
import 'package:pocketmind/service/scraper/platform_scraper_interface.dart';
import 'package:pocketmind/service/scraper/stealth_js_loader.dart';
import 'package:pocketmind/util/image_storage_helper.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'package:pocketmind/util/platform_detector.dart';

/// 平台爬虫服务
///
/// 整合爬虫策略，处理 Cookie 管理、图片下载、队列管理等
class PlatformScraperService {
  static const String _tag = 'PlatformScraperService';

  /// 图片批量下载并发数
  static const int _imageDownloadConcurrency = 3;

  final CookieManagerService _cookieManager;
  final ImageStorageHelper _imageHelper;

  PlatformScraperService({
    required CookieManagerService cookieManager,
    required ImageStorageHelper imageHelper,
  }) : _cookieManager = cookieManager,
       _imageHelper = imageHelper;

  /// 初始化服务（预加载 stealth.js）
  Future<void> init() async {
    await StealthJsLoader().preload();
    PMlog.d(_tag, '服务初始化完成');
  }

  /// 判断 URL 是否需要本地无头浏览器爬取
  ///
  /// [url] 目标链接
  /// 返回 (需要后台爬取, 平台类型) 的元组
  bool canHandle(String url) {
    final platform =
        PlatformDetector.detectPlatform(url) != PlatformType.generic;
    return platform;
  }

  /// 批量爬取
  ///
  /// [urls] 目标链接列表
  /// 返回以 URL 为 Key 的元数据 Map
  Future<List<NoteMetadata>> scrapeBatch(List<String> urls) async {
    final results = <NoteMetadata>[];

    // 按平台分分类
    final groupedUrls = <PlatformType, List<String>>{};
    for (var url in urls) {
      final platform = PlatformDetector.detectPlatform(url);
      if (platform != PlatformType.generic) {
        groupedUrls.putIfAbsent(platform, () => []).add(url);
      }
    }

    // 逐平台处理（避免同时启动多个 WebView）
    for (var entry in groupedUrls.entries) {
      final platform = entry.key;
      final platformUrls = entry.value;

      PMlog.d(
        _tag,
        '批量爬取 [${platform.displayName}]: ${platformUrls.length} 个链接',
      );

      for (var url in platformUrls) {
        try {
          final metadata = await scrape(url);
          if(metadata != null){
            results.add(metadata);
          }
        } on CookieExpiredException {
          // Cookie 过期后停止该平台的处理
          PMlog.w(_tag, '${platform.displayName} Cookie 已过期，跳过剩余链接');
          break;
        } catch (e) {
          PMlog.e(_tag, '爬取失败 [$url]: $e');
        }
      }
    }

    return results;
  }

  /// 爬取单个 URL
  ///
  /// [url] 目标链接
  /// 返回 [NoteMetadata] 或 null（失败时）
  /// 可能抛出 [CookieExpiredException] 当 Cookie 失效时
  Future<NoteMetadata?> scrape(String url) async {
    final scraper = PlatformDetector.getScraper(url);
    final platform = PlatformDetector.detectPlatform(url);

    if (scraper == null) {
      PMlog.w(_tag, '不支持的平台: $url');
      return null;
    }
    final platformId = platform.identifier;
    PMlog.d(_tag, '开始爬取?[${platformId}]: $url');

    // 获取 Cookie
    final cookieDict = await _cookieManager.getCookieDict(platformId);

    if (!scraper.validateCookies(cookieDict ?? {})) {
      PMlog.e(_tag, 'Cookie 不完整，需要用户登录');
      throw CookieExpiredException('Cookie 不完整', platform: platformId);
    }

    try {
      // 执行爬取
      final scrapedData = await scraper.scrape(url, cookieDict ?? {});

      if (scrapedData == null || !scrapedData.isValid) {
        PMlog.w(_tag, '爬取结果无效');
        return null;
      }

      // 处理图片本地化（批量下载，控制并发）
      final localizedImages = await _localizeImages(scrapedData.images);

      // 构建 NoteMetadata
      final metadata = NoteMetadata(
        title: scrapedData.title,
        previewDescription: scrapedData.description,
        previewContent: scrapedData.content,
        imageUrl: localizedImages.isNotEmpty ? localizedImages.first : null,
        imageUrls: localizedImages,
        url: url,
      );

      PMlog.d(
        _tag,
        '爬取成功: title=${metadata.title}, images=${localizedImages.length}',
      );

      return metadata;
    } on CookieExpiredException catch (e) {
      // 标记 Cookie 过期
      await _cookieManager.markAsExpired(platformId);
      PMlog.e(_tag, 'Cookie 已经过时? ${e.message}');
      rethrow;
    } catch (e) {
      PMlog.e(_tag, '爬取失败: $e');
      return null;
    }
  }

  /// 批量下载图片并本地化
  ///
  /// [imageUrls] 图片 URL 列表
  /// 返回本地化后的路径列表（保持顺序，下载失败的项为空字符串后被过滤）
  Future<List<String>> _localizeImages(List<String> imageUrls) async {
    if (imageUrls.isEmpty) return [];

    // 先去重（保持顺序）
    final uniqueUrls = <String>[];
    final seen = <String>{};
    for (var url in imageUrls) {
      if (!seen.contains(url)) {
        seen.add(url);
        uniqueUrls.add(url);
      }
    }

    if (uniqueUrls.length != imageUrls.length) {
      PMlog.d(_tag, '图片 URL 去重: ${imageUrls.length} -> ${uniqueUrls.length}');
    }

    final results = <int, String?>{};

    // 分批并发下载
    for (var i = 0; i < uniqueUrls.length; i += _imageDownloadConcurrency) {
      final batch = <Future<void>>[];
      final endIndex = (i + _imageDownloadConcurrency) > uniqueUrls.length
          ? uniqueUrls.length
          : (i + _imageDownloadConcurrency);

      for (var j = i; j < endIndex; j++) {
        final index = j;
        final url = uniqueUrls[j];
        batch.add(
          _imageHelper
              .downloadAndSaveImage(url)
              .then((path) {
                results[index] = path;
              })
              .catchError((e) {
                PMlog.w(_tag, '图片下载失败 [$index]: $e');
                results[index] = null;
              }),
        );
      }

      await Future.wait(batch);
    }

    // 按原始顺序组装结果，过滤失败项
    final localizedPaths = <String>[];
    for (var i = 0; i < uniqueUrls.length; i++) {
      final path = results[i];
      if (path != null && path.isNotEmpty) {
        localizedPaths.add(path);
      }
    }

    PMlog.d(_tag, '图片本地化: ${localizedPaths.length}/${uniqueUrls.length} 成功');
    return localizedPaths;
  }
}
