import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 跨平台共享存储目录工具。
///
/// 设计目的：让"主 App + 分享 Extension"在 iOS 上读到同一份 Isar / 图片目录,
/// 同时不影响 Android / macOS / Windows 的现有行为。
///
/// - **iOS**：通过 MethodChannel `com.doublez.pocketmind/storage` 调用
///   原生侧 `getAppGroupPath` 方法，返回 App Group 容器目录
///   (`group.com.doublez.pocketmind`)。Runner 与 ShareExtension 必须
///   在 Xcode 中各自勾选同一个 App Group，否则原生侧会返回 null。
/// - **其它平台**：直接 fallback 到 `getApplicationDocumentsDirectory()`,
///   行为与改造前完全一致，不会影响 Android / macOS / Windows。
///
/// 用法（替代原本的 `getApplicationDocumentsDirectory()` 调用）：
/// ```dart
/// final dirPath = await getSharedContainerPath();
/// final isar = await Isar.open([...], directory: dirPath);
/// ```
class _StoragePaths {
  static const MethodChannel _channel = MethodChannel(
    'com.doublez.pocketmind/storage',
  );

  /// 缓存解析后的路径，避免重复跨进程调用。
  static String? _cachedPath;

  static Future<String> getSharedContainerPath() async {
    final cached = _cachedPath;
    if (cached != null) return cached;

    String resolved;
    if (Platform.isIOS) {
      // iOS：必须走 App Group。原生侧返回 group container 的根路径。
      final result = await _channel.invokeMethod<String>('getAppGroupPath');
      if (result == null || result.isEmpty) {
        // 严重配置错误（App Group capability 没勾上）。
        // 此时若 fallback 到 ApplicationDocuments，主 App 与 Extension 数据会分裂,
        // 因此选择直接抛错，把问题暴露在 init 阶段。
        throw StateError(
          'iOS App Group 未配置：getAppGroupPath 返回空。'
          '请在 Xcode 中给 Runner 与 ShareExtension 都勾上 '
          'App Groups → group.com.doublez.pocketmind',
        );
      }
      resolved = result;
    } else {
      // Android / macOS / Windows：保持原行为。
      final dir = await getApplicationDocumentsDirectory();
      resolved = dir.path;
    }

    _cachedPath = resolved;
    return resolved;
  }
}

/// 顶层便捷函数，调用方无需感知内部实现。
Future<String> getSharedContainerPath() => _StoragePaths.getSharedContainerPath();
