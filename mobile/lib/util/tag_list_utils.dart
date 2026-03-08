/// 标签列表工具。
///
/// PocketMind 当前的 `tags` 同时承载两类来源：
/// - 用户手动维护的标签
/// - AI / 云端回填的标签
///
/// 因此同步冲突时不能简单“整列覆盖”，否则很容易丢掉另一侧的标签。
/// 这里统一提供去重、清洗、并集合并逻辑，避免各处重复造轮子且规则漂移。
abstract final class TagListUtils {
  /// 规范化标签列表：去空、裁剪空白、按首次出现顺序去重。
  static List<String> normalize(Iterable<dynamic>? rawTags) {
    if (rawTags == null) return const <String>[];

    final ordered = <String>{};
    for (final rawTag in rawTags) {
      if (rawTag == null) continue;
      final normalized = rawTag.toString().trim();
      if (normalized.isEmpty) continue;
      ordered.add(normalized);
    }
    return ordered.toList(growable: false);
  }

  /// 合并本地与服务端标签，并优先保留本地顺序。
  ///
  /// 适用于本地仍有 pending 编辑，但服务端也新增了 AI 标签的场景。
  static List<String> mergeLocalAndServer({
    required Iterable<dynamic> localTags,
    required Iterable<dynamic> serverTags,
  }) {
    final merged = <String>{};
    merged.addAll(normalize(localTags));
    merged.addAll(normalize(serverTags));
    return merged.toList(growable: false);
  }
}
