import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pocketmind/util/image_storage_helper.dart';
import 'package:pocketmind/util/theme_data.dart';
import 'package:pocketmind/util/url_helper.dart';

/// 统一图片渲染组件
///
/// 自动识别并加载不同类型的图片路径：
/// 1. 网络图片 (http/https)
/// 2. 本地相对路径 (pocket_images/...)
/// 3. 本地绝对路径 (Windows 盘符或 Android /data/...)
/// 4. Asset 资源
class PMImage extends StatelessWidget {
  final String pathOrUrl;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// 解码尺寸提示（可选）：用于降低大图解码内存占用，提升滚动/返回流畅性。
  ///
  /// - 网络图：映射到 CachedNetworkImage 的 memCacheWidth/memCacheHeight
  /// - 本地/Asset：映射到 Image.file/Image.asset 的 cacheWidth/cacheHeight
  final int? cacheWidth;
  final int? cacheHeight;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Widget? placeholder;
  final Widget? errorWidget;

  const PMImage({
    super.key,
    required this.pathOrUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.memCacheWidth,
    this.memCacheHeight,
    this.placeholder,
    this.errorWidget,
  });

  /// 统一的 ImageProvider 构造器（用于预取/尺寸探测等场景）。
  ///
  /// 注意：这里返回的是底层 provider，不负责 UI 展示。
  ///
  /// [decodeWidthPx]/[decodeHeightPx] 为像素值，会通过 ResizeImage 降低解码开销。
  static ImageProvider? imageProviderFromPathOrUrl(
    String pathOrUrl, {
    int? decodeWidthPx,
    int? decodeHeightPx,
  }) {
    if (pathOrUrl.isEmpty) return null;

    ImageProvider provider;

    if (UrlHelper.containsHttpsUrl(pathOrUrl)) {
      provider = CachedNetworkImageProvider(pathOrUrl);
    } else if (UrlHelper.isLocalImagePath(pathOrUrl)) {
      final file = ImageStorageHelper().getFileByRelativePath(pathOrUrl);
      if (!file.existsSync()) {
        return null;
      }
      provider = FileImage(file);
    } else if (pathOrUrl.contains(':\\') ||
        pathOrUrl.contains(':/') ||
        pathOrUrl.startsWith('/')) {
      final file = File(pathOrUrl);
      if (!file.existsSync()) {
        return null;
      }
      provider = FileImage(file);
    } else {
      provider = AssetImage(pathOrUrl);
    }

    return ResizeImage.resizeIfNeeded(decodeWidthPx, decodeHeightPx, provider);
  }

  @override
  Widget build(BuildContext context) {
    if (pathOrUrl.isEmpty) {
      return _buildErrorWidget(context);
    }

    // 1. 网络图片
    if (UrlHelper.containsHttpsUrl(pathOrUrl)) {
      return CachedNetworkImage(
        imageUrl: pathOrUrl,
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        placeholder: (context, url) => _buildPlaceholder(context),
        errorWidget: (context, url, error) => _buildErrorWidget(context),
      );
    }

    // 2. 本地相对路径 (pocket_images/...)
    if (UrlHelper.isLocalImagePath(pathOrUrl)) {
      // 只监听当前图片的保存事件，避免任意图片写入都触发所有本地图片重建。
      final stream = ImageStorageHelper().onImageSaved.where(
        (savedPath) => savedPath == pathOrUrl,
      );

      return StreamBuilder<String>(
        stream: stream,
        builder: (context, snapshot) {
          final file = ImageStorageHelper().getFileByRelativePath(pathOrUrl);

          if (!file.existsSync()) {
            return _buildErrorWidget(context);
          }

          // 如果收到当前图片的保存通知，清除缓存以强制重新加载
          if (snapshot.hasData && snapshot.data == pathOrUrl) {
            PaintingBinding.instance.imageCache.evict(FileImage(file));
          }

          return Image.file(
            file,
            fit: fit,
            width: width,
            height: height,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            gaplessPlayback: true,
            // 当收到当前图片的更新通知时，使用 UniqueKey 强制重建 Image 组件
            key: snapshot.hasData && snapshot.data == pathOrUrl
                ? UniqueKey()
                : null,
            errorBuilder: (context, error, stackTrace) =>
                _buildErrorWidget(context),
          );
        },
      );
    }

    // 3. 本地绝对路径 (兼容 Windows 和 Android)
    // Windows: 包含盘符 (C:\...) 或正斜杠 (C:/...)
    // Android/Linux: 以 / 开头
    if (pathOrUrl.contains(':\\') ||
        pathOrUrl.contains(':/') ||
        pathOrUrl.startsWith('/')) {
      final file = File(pathOrUrl);
      if (!file.existsSync()) {
        return _buildErrorWidget(context);
      }
      return Image.file(
        file,
        fit: fit,
        width: width,
        height: height,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) =>
            _buildErrorWidget(context),
      );
    }

    // 4. 默认为 Asset 资源
    return Image.asset(
      pathOrUrl,
      fit: fit,
      width: width,
      height: height,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => _buildErrorWidget(context),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    if (placeholder != null) return placeholder!;
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    if (errorWidget != null) return errorWidget!;
    final appColors = AppColors.of(context);
    return Container(
      width: width,
      height: height,
      color: appColors.errorBackground,
      child: Icon(Icons.broken_image_outlined, color: appColors.errorIcon),
    );
  }
}
