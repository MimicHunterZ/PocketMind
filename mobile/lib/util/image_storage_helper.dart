import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:pocketmind/api/http_client.dart';
import 'package:pocketmind/util/storage_paths.dart';
import './logger_service.dart';

/// 图片存储服务
///
/// 负责管理本地图片的存储、路径解析。
/// 实现了"相对路径"与"绝对路径"的转换。
class ImageStorageHelper {
  static String tag = 'ImageStorageHelper';
  // 单例模式，方便全局调用
  static final ImageStorageHelper _instance = ImageStorageHelper._internal();
  factory ImageStorageHelper() => _instance;
  ImageStorageHelper._internal();

  // 应用的文档根目录 (绝对路径)
  String? _rootDir;

  // 图片存放的子文件夹名称
  static const String _folderName = 'pocket_images';

  /// 内容寻址命名：根据图片 URL 计算稳定的相对路径,同一 URL 多次调用
  /// 返回完全相同的字符串。提取为静态方法以便单元测试。
  ///
  /// - [url]：原始图片 URL（不应是 data: URI,base64 走另一条路径）。
  /// - [extensionWithDot]：含点号的小写扩展名（如 `.jpg`、`.webp`）；
  ///   传入空字符串时退化为 `.jpg`。
  static String relativePathForUrl(String url, String extensionWithDot) {
    final ext = extensionWithDot.isEmpty ? '.jpg' : extensionWithDot;
    final hash = sha256.convert(utf8.encode(url)).toString().substring(0, 32);
    return '$_folderName/$hash$ext';
  }

  final _imageSavedController = StreamController<String>.broadcast();

  /// 图片保存事件流（发射相对路径）
  Stream<String> get onImageSaved => _imageSavedController.stream;

  /// 初始化服务
  Future<void> init() async {
    if (_rootDir != null) return;
    // iOS 走 App Group 共享容器，其它平台 fallback 到 ApplicationDocuments
    _rootDir = await getSharedContainerPath();

    // 确保图片目录存在
    final directory = Directory(p.join(_rootDir!, _folderName));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    PMlog.d(tag, '图片存储根目录已初始化: $_rootDir');
  }

  /// 保存图片：将临时文件移动到我们的存储目录
  ///
  /// [sourceFile] : 原始文件（来自系统分享或相册）
  /// 返回 : 相对路径 (例如 "pocket_images/uuid.jpg")，用于存入数据库
  Future<String> saveImage(File sourceFile) async {
    if (_rootDir == null) await init();
    final String fileName =
        '${const Uuid().v4()}${p.extension(sourceFile.path)}';
    // 统一使用正斜杠，确保跨平台数据库兼容性
    final String relativePath = '$_folderName/$fileName';
    final String destinationPath = p.join(_rootDir!, _folderName, fileName);
    await sourceFile.copy(destinationPath);
    return relativePath;
  }

  /// 下载并保存网络图片
  ///
  /// [url] : 图片网络地址 (支持 http/https 或 base64 data uri)
  /// 返回 : 相对路径
  ///
  /// **内容寻址命名**：远程图片以 `sha256(url)` 前缀作为文件名，
  /// 同一 URL 多次调用直接复用磁盘上已有文件，避免重复下载、避免
  /// 同图占用多份存储；与 `_upsertImageNoteAsset` 的 `(noteUuid, localPath)`
  /// 主键配合，可让 Isar 行也只保留一条。
  Future<String?> downloadAndSaveImage(String url) async {
    try {
      if (_rootDir == null) await init();

      // 1. 处理 Base64 Data URI (小红书等平台常返回此类数据)
      if (url.startsWith('data:image/')) {
        return await _saveBase64Image(url);
      }

      // 2. 处理普通网络 URL
      String extension = '';
      try {
        extension = p.extension(Uri.parse(url).path).toLowerCase();
      } catch (e) {
        PMlog.w(tag, '解析图片 URL 扩展名失败: $url');
      }

      // 过滤不支持的格式（如 SVG），这些通常不是真实的预览图
      if (extension == '.svg') {
        PMlog.w(tag, '不支持 SVG 格式作为预览图: $url');
        return null;
      }

      // 内容寻址：sha256(url) 前 32 位 hex 作为稳定文件名
      final initialExt = extension.isEmpty ? '.jpg' : extension;
      final initialRelativePath = relativePathForUrl(url, initialExt);
      final initialFileName = p.basename(initialRelativePath);
      final urlHash = p.basenameWithoutExtension(initialFileName);
      final initialPath = p.join(_rootDir!, _folderName, initialFileName);

      // 同 URL 已经下过 → 直接复用,不再触发 HTTP 请求,不再生成新 NoteAsset 行
      final initialFile = File(initialPath);
      if (await initialFile.exists() && await initialFile.length() > 0) {
        PMlog.d(tag, '图片已存在(内容寻址命中),复用: $initialRelativePath');
        return initialRelativePath;
      }

      // 也兼容历史魔数修正后的扩展名（同 hash 不同后缀）
      for (final ext in const ['.webp', '.png', '.gif', '.jpeg']) {
        if (ext == initialExt) continue;
        final altName = '$urlHash$ext';
        final altPath = p.join(_rootDir!, _folderName, altName);
        final altFile = File(altPath);
        if (await altFile.exists() && await altFile.length() > 0) {
          PMlog.d(tag, '图片已存在(内容寻址命中,扩展名 $ext),复用');
          return '$_folderName/$altName';
        }
      }

      final response = await HttpClient().dio.download(url, initialPath);

      // 校验下载结果
      final file = File(initialPath);
      if (!await file.exists() || await file.length() == 0) {
        PMlog.w(tag, '下载的文件为空: $url');
        if (await file.exists()) await file.delete();
        return null;
      }

      // 校验 Content-Type (可选，有些服务器不返回正确的 content-type)
      final contentType = response.headers.value('content-type')?.toLowerCase();
      if (contentType != null &&
          (!contentType.startsWith('image/') ||
              contentType.contains('svg') ||
              contentType.contains('xml')) &&
          !contentType.contains('application/octet-stream')) {
        PMlog.w(tag, '下载的内容似乎不是有效的图片格式: $contentType');
        await file.delete();
        return null;
      }

      // 修正扩展名：检测实际格式（防止 CDN URL 无扩展名时默认 .jpg 但实为 WebP 等格式）
      final actualExt = await _detectExtensionFromMagicBytes(file);
      if (actualExt.isNotEmpty &&
          actualExt != p.extension(initialFileName).toLowerCase()) {
        final correctedFileName = '$urlHash$actualExt';
        final correctedRelativePath = '$_folderName/$correctedFileName';
        final correctedPath = p.join(_rootDir!, _folderName, correctedFileName);

        // 若魔数修正后的目标文件早已存在（前一次抓取已落盘）→ 删除新下载的副本,直接复用旧的
        final correctedFile = File(correctedPath);
        if (await correctedFile.exists() &&
            await correctedFile.length() > 0) {
          await file.delete();
          PMlog.d(tag, '魔数修正后命中已有文件,删除重复副本: $correctedRelativePath');
          return correctedRelativePath;
        }

        await file.rename(correctedPath);
        PMlog.d(
          tag,
          '格式修正: ${p.extension(initialFileName)} → $actualExt, $initialRelativePath -> $correctedRelativePath',
        );
        return correctedRelativePath;
      }

      PMlog.d(tag, '图片下载成功: $url -> $initialRelativePath');
      return initialRelativePath;
    } catch (e) {
      PMlog.e(tag, '下载图片失败: $url, e:$e');
      return null;
    }
  }

  /// 处理 Base64 图片保存
  Future<String?> _saveBase64Image(String dataUri) async {
    try {
      // 格式: data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...
      final commaIndex = dataUri.indexOf(',');
      if (commaIndex == -1) return null;

      final metadata = dataUri.substring(0, commaIndex);
      final base64Data = dataUri.substring(commaIndex + 1);

      // 提取扩展名
      String extension = '.jpg';
      if (metadata.contains('image/png')) {
        extension = '.png';
      } else if (metadata.contains('image/gif')) {
        extension = '.gif';
      } else if (metadata.contains('image/webp')) {
        extension = '.webp';
      }

      final bytes = base64Decode(base64Data);
      // 内容寻址：以解码后字节的 sha256 为文件名,同图重复保存自动复用
      final urlHash = sha256.convert(bytes).toString().substring(0, 32);
      final String fileName = '$urlHash$extension';
      final String relativePath = '$_folderName/$fileName';
      final String destinationPath = p.join(_rootDir!, _folderName, fileName);

      final file = File(destinationPath);
      if (await file.exists() && await file.length() > 0) {
        PMlog.d(tag, 'Base64 图片已存在(内容寻址命中),复用: $relativePath');
        return relativePath;
      }
      await file.writeAsBytes(bytes);

      PMlog.d(tag, 'Base64 图片保存成功: $relativePath');
      return relativePath;
    } catch (e) {
      PMlog.e(tag, '保存 Base64 图片失败: $e');
      return null;
    }
  }

  /// 获取完整路径：将数据库里的相对路径转换为当前设备的绝对路径
  File getFileByRelativePath(String relativePath) {
    if (_rootDir == null) {
      // 如果还没初始化，尝试同步获取（虽然不推荐，但作为兜底）
      // 注意：这里不能 await，所以如果真的没初始化，可能会有问题
      // 但通常 getFileByRelativePath 是在 UI 渲染时调用的，此时应该已经初始化了
      PMlog.w(tag, 'getFileByRelativePath 被调用时 _rootDir 为空');
    }
    // 兼容旧数据（可能包含反斜杠）
    final normalizedPath = relativePath.replaceAll('\\', '/');
    // 移除 folderName 前缀，因为 p.join 会处理
    final fileName = normalizedPath.replaceFirst('$_folderName/', '');
    final fullPath = p.join(_rootDir ?? '', _folderName, fileName);
    return File(fullPath);
  }

  /// 通知图片已保存（用于外部直接写入文件后触发 UI 更新）
  void notifyImageSaved(String relativePath) {
    _imageSavedController.add(relativePath);
  }

  /// 根据相对路径删除本地图片文件
  Future<void> deleteImage(String relativePath) async {
    try {
      if (_rootDir == null) await init();
      final file = getFileByRelativePath(relativePath);
      if (await file.exists()) {
        await file.delete();
        PMlog.d(tag, '已删除本地图片: $relativePath');
      }
    } catch (e) {
      PMlog.e(tag, '删除图片失败: $relativePath, e:$e');
    }
  }

  /// 从文件头魔数字节检测实际图片格式，返回扩展名（含点号，如 '.webp'），检测失败时返回空字符串
  Future<String> _detectExtensionFromMagicBytes(File file) async {
    try {
      final raf = await file.open();
      final bytes = await raf.read(12);
      await raf.close();
      if (bytes.length >= 4) {
        // WebP: RIFF????WEBP
        if (bytes[0] == 0x52 &&
            bytes[1] == 0x49 &&
            bytes[2] == 0x46 &&
            bytes[3] == 0x46 &&
            bytes.length >= 12 &&
            bytes[8] == 0x57 &&
            bytes[9] == 0x45 &&
            bytes[10] == 0x42 &&
            bytes[11] == 0x50) {
          return '.webp';
        }
        // JPEG: FF D8 FF
        if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
          return '.jpg';
        }
        // PNG: 89 50 4E 47
        if (bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4E &&
            bytes[3] == 0x47) {
          return '.png';
        }
        // GIF87a / GIF89a: 47 49 46 38
        if (bytes[0] == 0x47 &&
            bytes[1] == 0x49 &&
            bytes[2] == 0x46 &&
            bytes[3] == 0x38) {
          return '.gif';
        }
      }
    } catch (e) {
      PMlog.w(tag, '魔数检测失败: $e');
    }
    return '';
  }

  /// 获取所有存储的图片路径（相对路径）
  Future<List<String>> getAllImagePaths() async {
    if (_rootDir == null) await init();
    final directory = Directory(p.join(_rootDir!, _folderName));
    if (!await directory.exists()) {
      return [];
    }

    final List<String> paths = [];
    await for (final entity in directory.list()) {
      if (entity is File) {
        final relativePath = p.join(_folderName, p.basename(entity.path));
        paths.add(relativePath);
      }
    }
    return paths;
  }
}
