import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pocketmind/page/widget/pm_image.dart';

/// 图片预热器：用于在「列表/预览」阶段提前缓存图片，避免进入详情后再加载造成割裂感。
///
/// 功能：
/// 1) precacheImage：把图片提前塞进内存缓存
/// 2) 预计算详情轮播高度比 max(h/w)：避免进入详情页出现 loading
///
/// 注意：这是纯体验优化层，不落库。
class ImagePrefetcher {
  ImagePrefetcher._();

  // --- LRU: 避免无限增长 ---
  static final LinkedHashMap<String, double> _ratioCache = LinkedHashMap();
  static const int _ratioCacheLimit = 128;

  static final LinkedHashSet<String> _prefetchedSingles = LinkedHashSet();
  static const int _prefetchedSinglesLimit = 512;

  /// 生成稳定 key（避免 key 过长）。
  static String ratioKeyFor(List<String> images) {
    return '${images.length}:${Object.hashAll(images)}';
  }

  static double? getCachedMaxHeightOverWidth(List<String> images) {
    return _ratioCache[ratioKeyFor(images)];
  }

  /// 从存储的 metadataJson 中解析宽高，直接填充轮播比例缓存。
  ///
  /// 成功则跳过图片解码步骤，避免详情页进入时出现 loading 跳动。
  /// 仅当所有图片都有有效尺寸时才写入缓存；如果某张缺失则保留解码逻辑。
  /// [paths]          - 轮播图片路径列表
  /// [metadataJsonList] - 每张图片对应的 metadataJson （可为 null）
  static void seedRatioFromJson(
    List<String> paths,
    List<String?> metadataJsonList,
  ) {
    if (paths.isEmpty || paths.length != metadataJsonList.length) return;
    final key = ratioKeyFor(paths);
    if (_ratioCache.containsKey(key)) return;

    final ratios = <double>[];
    for (final json in metadataJsonList) {
      if (json == null) return; // 某张无数据，放弃预填，保留解码路径
      try {
        final m = jsonDecode(json) as Map<String, dynamic>;
        final w = m['width'] as int?;
        final h = m['height'] as int?;
        if (w == null || h == null || w <= 0) return;
        ratios.add(h / w);
      } catch (_) {
        return; // JSON 异常，放弃预填
      }
    }
    if (ratios.isEmpty) return;
    _putRatio(key, ratios.reduce((a, b) => a > b ? a : b));
  }

  static void _putRatio(String key, double ratio) {
    _ratioCache.remove(key);
    _ratioCache[key] = ratio;
    while (_ratioCache.length > _ratioCacheLimit) {
      _ratioCache.remove(_ratioCache.keys.first);
    }
  }

  static void _markPrefetchedSingle(String key) {
    _prefetchedSingles.remove(key);
    _prefetchedSingles.add(key);
    while (_prefetchedSingles.length > _prefetchedSinglesLimit) {
      _prefetchedSingles.remove(_prefetchedSingles.first);
    }
  }

  /// 在列表阶段预热：
  /// - [images]：详情页可能会用到的图片列表
  /// - [logicalDecodeWidth]/[logicalDecodeHeight]：按目标展示尺寸解码（可为空）
  /// - [computeCarouselRatio]：是否预计算 max(h/w)
  static Future<void> prewarm(
    BuildContext context,
    List<String> images, {
    double? logicalDecodeWidth,
    double? logicalDecodeHeight,
    bool computeCarouselRatio = true,
  }) async {
    if (images.isEmpty) return;

    // 1) 预缓存（内存）
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final decodeW = (logicalDecodeWidth != null)
        ? (logicalDecodeWidth * dpr).round()
        : null;
    final decodeH = (logicalDecodeHeight != null)
        ? (logicalDecodeHeight * dpr).round()
        : null;

    for (final path in images) {
      final singleKey = path;
      if (_prefetchedSingles.contains(singleKey)) continue;

      final provider = PMImage.imageProviderFromPathOrUrl(
        path,
        decodeWidthPx: decodeW,
        decodeHeightPx: decodeH,
      );
      if (provider == null) continue;

      try {
        await precacheImage(provider, context);
        _markPrefetchedSingle(singleKey);
      } catch (_) {
        // 失败静默：缓存失败不影响正常渲染
      }
    }

    // 2) 预计算轮播高度比：max(h/w)
    if (!computeCarouselRatio) return;
    final key = ratioKeyFor(images);
    if (_ratioCache.containsKey(key)) return;

    final ratios = <double>[];
    for (final path in images) {
      final provider = PMImage.imageProviderFromPathOrUrl(path);
      if (provider == null) continue;
      final ratio = await _resolveHeightOverWidth(provider);
      if (ratio != null && ratio.isFinite && ratio > 0) {
        ratios.add(ratio);
      }
    }
    if (ratios.isEmpty) return;
    _putRatio(key, ratios.reduce((a, b) => a > b ? a : b));
  }

  static Future<double?> _resolveHeightOverWidth(ImageProvider provider) async {
    final completer = Completer<double?>();
    final stream = provider.resolve(const ImageConfiguration());

    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        final w = info.image.width;
        final h = info.image.height;
        stream.removeListener(listener);
        if (w > 0 && h > 0) {
          completer.complete(h / w);
        } else {
          completer.complete(null);
        }
      },
      onError: (_, __) {
        stream.removeListener(listener);
        completer.complete(null);
      },
    );

    stream.addListener(listener);
    return completer.future;
  }
}
