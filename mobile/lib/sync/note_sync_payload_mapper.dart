import 'package:pocketmind/core/constants.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/util/tag_list_utils.dart';

/// Note 同步 payload 映射工具。
///
/// 目的：统一处理服务端快照到本地 Note 的映射，避免 Pull / 409 回滚各写一套，
/// 同时保护客户端本地衍生字段不被“服务端未携带”错误清空。
abstract final class NoteSyncPayloadMapper {
  /// 用服务端快照覆盖目标 Note。
  ///
  /// 当前服务端并不持久化 `previewImageUrl`，因此当 payload 未携带该字段时，
  /// 必须保留本地已有值，否则分享后抓到的图片封面会在下一次同步时丢失。
  static void applyServerSnapshot({
    required Note target,
    required Map<String, dynamic> payload,
    required int serverVersion,
    String? fallbackPreviewImageUrl,
  }) {
    final existingPreviewImageUrl =
        fallbackPreviewImageUrl ?? target.previewImageUrl;
    final existingPreviewTitle = target.previewTitle;
    final existingPreviewDescription = target.previewDescription;
    final existingPreviewContent = target.previewContent;

    target
      ..uuid = payload['uuid'] as String?
      ..title = payload['title'] as String?
      ..content = payload['content'] as String?
      ..url = payload['url'] as String?
      ..updatedAt = payload['updatedAt'] as int? ?? 0
      ..isDeleted = payload['isDeleted'] as bool? ?? false
      ..categoryId =
          payload['categoryId'] as int? ?? AppConstants.homeCategoryId
      ..tags = TagListUtils.normalize(payload['tags'] as List<dynamic>?)
      ..previewTitle = existingPreviewTitle
      ..previewDescription = existingPreviewDescription
      ..previewContent = existingPreviewContent
      ..resourceStatus = payload['resourceStatus'] as String?
      ..aiSummary = payload['aiSummary'] as String?
      ..serverVersion = serverVersion;

    target.previewTitle = _resolvePreviewField(
      payload: payload,
      key: 'previewTitle',
      fallback: existingPreviewTitle,
    );
    target.previewDescription = _resolvePreviewField(
      payload: payload,
      key: 'previewDescription',
      fallback: existingPreviewDescription,
    );
    target.previewContent = _resolvePreviewField(
      payload: payload,
      key: 'previewContent',
      fallback: existingPreviewContent,
    );

    if (payload.containsKey('previewImageUrl')) {
      target.previewImageUrl = payload['previewImageUrl'] as String?;
    } else {
      target.previewImageUrl = existingPreviewImageUrl;
    }

    final timeMs = payload['time'] as int?;
    if (timeMs != null) {
      target.time = DateTime.fromMillisecondsSinceEpoch(timeMs);
    } else {
      target.time = null;
    }
  }

  static Note createFromServerSnapshot({
    required Map<String, dynamic> payload,
    required int serverVersion,
    String? fallbackPreviewImageUrl,
  }) {
    final note = Note();
    applyServerSnapshot(
      target: note,
      payload: payload,
      serverVersion: serverVersion,
      fallbackPreviewImageUrl: fallbackPreviewImageUrl,
    );
    return note;
  }

  /// 预览字段采用“非空覆盖”策略，避免服务端空值抹除端侧抓取结果。
  static String? _resolvePreviewField({
    required Map<String, dynamic> payload,
    required String key,
    required String? fallback,
  }) {
    if (!payload.containsKey(key)) return fallback;
    final value = payload[key] as String?;
    if (value == null || value.trim().isEmpty) {
      return fallback;
    }
    return value;
  }
}
