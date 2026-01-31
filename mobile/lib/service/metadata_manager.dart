import 'package:any_link_preview/any_link_preview.dart';
import 'package:pocketmind/api/link_preview_api_service.dart';
import 'package:pocketmind/api/resource_pm_service.dart';
import 'package:pocketmind/api/models/note_metadata.dart';
import 'package:pocketmind/service/scraper/platform_scraper_interface.dart';
import 'package:pocketmind/service/scraper/platform_scraper_service.dart';
import 'package:pocketmind/util/image_storage_helper.dart';
import 'package:pocketmind/util/link_preview_config.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'package:pocketmind/util/url_helper.dart';

/// 元数据管理服务
///
/// 负责处理链接预览数据的获取、加工和本地化。
/// 不直接操作数据库，只返回处理好的数据对象。
///
/// 策略优先级：
/// 0. 平台专用爬虫（小红书等需要登录的平台）
/// 1. 后端 API（支持正文提取）
/// 2. LinkPreview API（公共服务）
/// 3. 本地解析（AnyLinkPreview）
class MetadataManager {
  static const String _tag = 'MetadataManager';
  final ImageStorageHelper _imageHelper = ImageStorageHelper();
  final LinkPreviewApiService? _linkPreviewApi;
  final ResourcePmService? _resourceService;
  final PlatformScraperService? _platformScraperService;

  MetadataManager({
    LinkPreviewApiService? linkPreviewApi,
    ResourcePmService? resourceService,
    PlatformScraperService? platformScraperService,
  }) : _linkPreviewApi = linkPreviewApi,
       _resourceService = resourceService,
       _platformScraperService = platformScraperService;

  /// 获取并处理链接元数据
  ///
  /// 调用方无需关心内部策略，所有 URL 抓取都走这个入口。
  /// 内部自动选择最优策略：
  /// 1. 平台专用爬虫（小红书等需要登录的平台）
  /// 2. 后端 API
  /// 3. LinkPreview API（公共服务）
  /// 4. 本地解析（AnyLinkPreview）
  ///
  /// [urls] : 目标链接列表
  /// 返回 : 以 URL 为 Key 的元数据 Map
  Future<Map<String, NoteMetadata>> fetchAndProcessMetadata(
    List<String> urls,
  ) async {
    final results = <String, NoteMetadata>{};

    PMlog.d(_tag, '开始批量获取元数据: ${urls.length} 个链接');

    try {
      final scraperUrls = urls
          .where((u) => LinkPreviewConfig.shouldUsePlatformScraper(u))
          .toList();
      if (scraperUrls.isNotEmpty) {
        final ScraperMetaDatas = await _fetchFromPlatformScraper(scraperUrls);
        results.addAll(ScraperMetaDatas);
        // 移除已成功获取的
        urls = urls.where((u) => !results.containsKey(u)).toList();
        PMlog.d(_tag, '从平台爬虫成功获取 ${ScraperMetaDatas.length} 个元数据');
      }

      if (urls.isEmpty) return results;

      // 策略1: 优先尝试后端 API（批量处理）
      final backendUrls = urls
          .where((u) => LinkPreviewConfig.shouldUseBackendService(u))
          .toList();
      if (backendUrls.isNotEmpty) {
        final backendMetaDatas = await _fetchResourceContentByUrls(backendUrls);
        results.addAll(backendMetaDatas);
        // 移除已成功获取的
        urls = urls.where((u) => !results.containsKey(u)).toList();
        PMlog.d(_tag, '从后端服务成功获取 ${backendMetaDatas.length} 个元数据');
      }

      if (urls.isEmpty) return results;

      // 策略2 & 3: 并发处理剩余的 URL
      await Future.wait(
        urls.map((url) async {
          NoteMetadata? result;

          // 策略2: LinkPreview API
          if (LinkPreviewConfig.shouldUseApiService(url)) {
            final apiMetadata = await _fetchFromLinkPreviewApi(url);
            if (apiMetadata != null) {
              result = await _convertMetadataToNote(apiMetadata);
              PMlog.d(_tag, '从 LinkPreview API 成功获取元数据: $url');
            }
          }

          // 策略3: 回退到本地解析
          if (result == null) {
            final localMetadata = await _fetchFromLocalParser(url);
            if (localMetadata != null) {
              result = await _convertMetadataToNote(localMetadata);
              PMlog.d(_tag, '从本地 AnyLinkPreview 库 解析成功获取元数据: $url');
            }
          }

          if (result != null) {
            results[url] = result;
          } else {
            PMlog.w(_tag, '所有策略均失败，无法获取元数据: $url');
          }
        }),
      );

      return results;
    } catch (e) {
      PMlog.e(_tag, '批量元数据处理失败, error: $e');
      return results;
    }
  }

  /// 按需从后端拉取完整的笔记详情，并返回以 URL 为 Key 的 Map
  ///
  /// - 成功：返回 `Map<String, ResourceStatusItem>`
  /// - 失败/无数据：返回空 Map {} (建议返回空 Map 而非 null，避免外部频繁判空)
  Future<Map<String, NoteMetadata>> _fetchResourceContentByUrls(
    List<String> urls,
  ) async {
    List<String> trueHttpsUrls = [];
    if (_resourceService == null) return {};
    // 过滤
    for (var url in urls) {
      if (UrlHelper.containsHttpsUrl(url)) {
        trueHttpsUrls.add(url);
      }
    }

    if (trueHttpsUrls.isEmpty) return {};

    try {
      final lists = await _resourceService.statusByUrls(trueHttpsUrls);

      // todo 处理没有返回的url
      if (lists.isEmpty) return {};
      final noteMetadatas = <NoteMetadata>[];
      for (final item in lists) {
        final metadata = NoteMetadata(
          title: item.title,
          previewContent: item.previewContent,
          aiSummary: item.aiSummary,
          url: item.url,
          resourceStatus: item.status,
        );
        noteMetadatas.add(metadata);
      }
      return {for (var item in noteMetadatas) item.url: item};
    } catch (e) {
      PMlog.w(_tag, 'fetchResourceContentByUrl failed: $e');
      return {};
    }
  }

  /// 将 Metadata 对象转换为 NoteMetadata
  Future<NoteMetadata> _convertMetadataToNote(Metadata metadata) async {
    // 数据清洗
    _sanitizeMetadata(metadata, metadata.url ?? '');

    // 本地化图片
    final processedMetadata = await _localizeResources(metadata);

    return NoteMetadata(
      title: processedMetadata.title,
      previewDescription: processedMetadata.desc, // 来自 LinkPreview 的描述
      previewContent: null, // 本地解析没有正文内容
      aiSummary: null,
      imageUrls: processedMetadata.image != null
          ? [processedMetadata.image!]
          : [], // 本地化后的图片路径
      url: processedMetadata.url ?? '',
      resourceStatus: null,
    );
  }

  /// 使用 LinkPreview.net API 获取元数据
  Future<Metadata?> _fetchFromLinkPreviewApi(String url) async {
    if (_linkPreviewApi == null) return null;

    try {
      final apiData = await _linkPreviewApi.fetchMetadata(url);
      if (apiData.success && apiData.hasData) {
        final metadata = Metadata();
        metadata.title = apiData.title;
        metadata.desc = apiData.description;
        metadata.image = apiData.imageUrl;
        metadata.url = apiData.url;
        PMlog.d(_tag, '从 API 成功获取元数据: ${metadata.title}');
        return metadata;
      }
    } catch (e) {
      PMlog.w(_tag, 'API 获取失败，准备回退到本地解析: $e');
    }
    return null;
  }

  /// 清洗和补全元数据
  void _sanitizeMetadata(Metadata data, String url) {
    // 移除标题和描述中的多余空白
    data.title = data.title?.trim();
    data.desc = data.desc?.trim();

    // 如果标题为空，保持为 null，不要使用域名兜底
    // UI 层会根据 title == null 显示“预览失败”
    if (data.title != null && data.title!.isEmpty) {
      data.title = null;
    }
  }

  /// 使用本地解析库获取元数据
  Future<Metadata?> _fetchFromLocalParser(String url) async {
    try {
      // 针对不同平台使用特定的 User-Agent
      String userAgent =
          'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1';

      if (url.contains('xhslink.com') || url.contains('xiaohongshu.com')) {
        // 小红书使用移动端 User-Agent 效果更好
        userAgent =
            'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1';
      }

      // AnyLinkPreview.getMetadata 内部已经处理了部分解析逻辑
      final metadata = await AnyLinkPreview.getMetadata(
        link: url,
        cache: const Duration(hours: 24),
        proxyUrl: null, // 不使用公共代理，避免被封
        headers: {
          'User-Agent': userAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Cache-Control': 'no-cache',
        },
      );
      return metadata;
    } catch (e) {
      PMlog.w(_tag, '本地解析失败: $e');
      return null;
    }
  }

  /// 下载图片并替换为本地路径
  Future<Metadata> _localizeResources(Metadata original) async {
    final imageUrl = original.image;

    // 如果没有图片或已经是本地路径，直接返回
    if (imageUrl == null ||
        imageUrl.isEmpty ||
        UrlHelper.isLocalImagePath(imageUrl)) {
      return original;
    }

    // 尝试下载图片
    final localPath = await _imageHelper.downloadAndSaveImage(imageUrl);

    if (localPath != null) {
      // 下载成功，替换为本地路径
      original.image = localPath;
      PMlog.d(_tag, '图片已本地化: $localPath');
    } else {
      // 下载失败，将图片字段设为 null，避免保存网络 URL
      original.image = null;
      PMlog.w(_tag, '图片本地化失败，已清除图片字段: $imageUrl');
    }
    return original;
  }

  Future<Map<String, NoteMetadata>> _fetchFromPlatformScraper(
    List<String> scraperUrls,
  ) async {
    if (_platformScraperService == null) return {};
    PMlog.d(_tag, '策略0: 尝试平台爬虫处理 ${scraperUrls.length} 个链接');
    try {
      final platformResults = await _platformScraperService.scrapeBatch(
        scraperUrls,
      );
      return {for (var item in platformResults) item.url: item};
    } on CookieExpiredException catch (e) {
      PMlog.w(_tag, '平台 Cookie 过期: ${e.message}');
      return {};
    }
  }
}
