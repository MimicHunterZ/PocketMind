import 'package:isar_community/isar.dart';
import '../../model/note_asset.dart';

/// NoteAsset 的 Isar 仓库实现。
class IsarNoteAssetRepository {
  final Isar _isar;

  IsarNoteAssetRepository(this._isar);

  /// 写入一条资产记录
  Future<void> save(NoteAsset asset) async {
    await _isar.writeTxn(() async {
      await _isar.noteAssets.put(asset);
    });
  }

  /// 按笔记 UUID 查询所有资产，按 sortOrder 升序排列
  Future<List<NoteAsset>> findByNoteUuid(String noteUuid) async {
    return _isar.noteAssets
        .filter()
        .noteUuidEqualTo(noteUuid)
        .sortBySortOrder()
        .findAll();
  }

  /// 按笔记 UUID 监听资产列表变化（用于响应式 UI）
  Stream<List<NoteAsset>> watchByNoteUuid(String noteUuid) {
    return _isar.noteAssets
        .filter()
        .noteUuidEqualTo(noteUuid)
        .sortBySortOrder()
        .watch(fireImmediately: true);
  }

  /// 按笔记 UUID 查询所有本地 / 服务器图片路径，供画廊展示
  Stream<List<String>> watchImagePathsByNoteUuid(String noteUuid) {
    return watchByNoteUuid(noteUuid).map(
      (assets) => assets
          .map((a) => a.localPath ?? a.serverUrl ?? '')
          .where((s) => s.isNotEmpty)
          .toList(),
    );
  }
}
