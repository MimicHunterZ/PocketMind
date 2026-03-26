import 'package:isar_community/isar.dart';
import '../../core/constants.dart';
import '../../model/note.dart';
import '../../model/category.dart';
import '../../util/logger_service.dart';
import '../../util/image_storage_helper.dart';

/// Isar 数据库的笔记仓库实现
///
/// 封装所有与 Isar 相关的数据访问逻辑
class IsarNoteRepository {
  final Isar _isar;
  static const String _tag = 'IsarNoteRepository';

  IsarNoteRepository(this._isar);

  /// 按 UUID 查找笔记。
  Future<Note?> findByUuid(String uuid) async {
    return _isar.notes.getByUuid(uuid);
  }

  Future<void> delete(int id) async {
    try {
      // 使用软删除代替物理删除
      await _isar.writeTxn(() async {
        final note = await _isar.notes.get(id);
        if (note != null) {
          // 删除对应的图片文件（如果有）
          if (note.url != null &&
              note.url!.startsWith(AppConstants.localImagePathPrefix)) {
            try {
              await ImageStorageHelper().deleteImage(note.url!);
              PMlog.d(_tag, 'Deleted image: ${note.url}');
            } catch (e) {
              PMlog.w(_tag, 'Failed to delete image ${note.url}: $e');
            }
          }

          // 删除预览图片文件（如果有且是本地的）
          if (note.previewImageUrl != null &&
              note.previewImageUrl!.startsWith(
                AppConstants.localImagePathPrefix,
              )) {
            try {
              await ImageStorageHelper().deleteImage(note.previewImageUrl!);
              PMlog.d(_tag, 'Deleted preview image: ${note.previewImageUrl}');
            } catch (e) {
              PMlog.w(
                _tag,
                'Failed to delete preview image ${note.previewImageUrl}: $e',
              );
            }
          }

          note.isDeleted = true;
          note.updatedAt = DateTime.now().millisecondsSinceEpoch;
          await _isar.notes.put(note);
        }
      });
      PMlog.d(_tag, 'Note soft deleted: id=$id');
    } on IsarError catch (e, stackTrace) {
      PMlog.e(_tag, 'Error while deleting note: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<Note?> getById(int id) async {
    try {
      final note = await _isar.notes.get(id);
      // 过滤已删除的记录
      if (note == null || note.isDeleted) return null;
      return note;
    } catch (e, stackTrace) {
      PMlog.e(_tag, 'Error while getting note by id: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<List<Note>> getAll() async {
    try {
      final notes = await _isar.notes
          .filter()
          .isDeletedEqualTo(false)
          .sortByTimeDesc()
          .findAll();
      return notes;
    } catch (e, stackTrace) {
      PMlog.e(_tag, 'Error while getting all notes: $e\n$stackTrace');
      rethrow;
    }
  }

  Stream<List<Note>> watchAll() {
    return _isar.notes
        .filter()
        .isDeletedEqualTo(false)
        .sortByTimeDesc() // 添加排序（最新的在前）
        .watch(fireImmediately: true);
  }

  Stream<List<Note>> watchByCategory(int category) {
    // 1. 先定义基础查询：所有未删除的笔记
    var query = _isar.notes.filter().isDeletedEqualTo(false);
    // 2. 动态判断：如果 category 不是 homeCategoryId（全部），则追加分类 ID 过滤
    if (category != AppConstants.homeCategoryId) {
      query = query.categoryIdEqualTo(category);
    }
    // 3. 统一收尾：排序、监听、转换
    return query.sortByTimeDesc().watch(fireImmediately: true);
  }

  Future<List<Note>> findByTitle(String query) async {
    try {
      final notes = await _isar.notes
          .filter()
          .isDeletedEqualTo(false)
          .titleContains(query, caseSensitive: false)
          .sortByTimeDesc() // 添加排序（最新的在前）
          .findAll();
      return notes;
    } catch (e, stackTrace) {
      PMlog.e(_tag, 'Error while finding notes by title: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<List<Note>> findByContent(String query) async {
    try {
      final notes = await _isar.notes
          .filter()
          .isDeletedEqualTo(false)
          .contentContains(query, caseSensitive: false)
          .sortByTimeDesc() // 添加排序（最新的在前）
          .findAll();
      return notes;
    } catch (e, stackTrace) {
      PMlog.e(_tag, 'Error while finding notes by content: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<List<Note>> findByCategoryId(int categoryId) async {
    try {
      // categoryId = homeCategoryId 代表 home，返回所有笔记
      if (categoryId == AppConstants.homeCategoryId) {
        return await getAll();
      }

      final notes = await _isar.notes
          .filter()
          .isDeletedEqualTo(false)
          .categoryIdEqualTo(categoryId)
          .sortByTimeDesc()
          .findAll();
      return notes;
    } catch (e, stackTrace) {
      PMlog.e(_tag, 'Error while finding notes by category: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<List<Note>> findByTag(String query) async {
    try {
      final notes = await _isar.notes
          .filter()
          .isDeletedEqualTo(false)
          .tagsElementContains(query, caseSensitive: false)
          .sortByTimeDesc() // 添加排序（最新的在前）
          .findAll();
      return notes;
    } catch (e, stackTrace) {
      PMlog.e(_tag, 'Error while finding notes by tag: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<List<Note>> findByUrls(List<String> urls) async {
    try {
      final notes = await _isar.notes
          .filter()
          .isDeletedEqualTo(false)
          .and()
          .group((q) {
            return q.anyOf(urls, (q, String url) => q.urlEqualTo(url));
          })
          .findAll();
      return notes;
    } catch (e, stackTrace) {
      PMlog.e(_tag, 'Error while finding notes by url: $e\n$stackTrace');
      rethrow;
    }
  }

  Stream<List<Note>> findByQuery(String query) {
    try {
      if (query.trim().isEmpty) {
        return _isar.notes
            .filter()
            .isDeletedEqualTo(false)
            .sortByTimeDesc()
            .watch(fireImmediately: true);
      }
      return _isar.notes
          .filter()
          .isDeletedEqualTo(false)
          .and()
          .group(
            (q) => q
                .titleContains(query, caseSensitive: false)
                .or()
                .contentContains(query, caseSensitive: false)
                .or()
                .previewContentContains(query, caseSensitive: false)
                .or()
                .previewTitleContains(query, caseSensitive: false)
                .or()
                .tagsElementContains(query, caseSensitive: false)
                .or()
                .aiSummaryContains(query, caseSensitive: false),
          )
          .sortByTimeDesc()
          .watch(fireImmediately: true);
    } catch (e, stackTrace) {
      PMlog.e(_tag, 'Error while finding notes by query: $e\n$stackTrace');
      rethrow;
    }
  }

  /// 查找等待抓取资源的笔记
  ///
  /// 条件：URL 不为空，且 previewContent 为空，且未删除
  Future<List<Note>> findPendingResources() async {
    return await _isar.notes
        .filter()
        .urlIsNotNull()
        .urlIsNotEmpty()
        .previewContentIsNull()
        .not()
        .resourceStatusEqualTo('FAILED')
        .isDeletedEqualTo(false)
        .findAll();
  }

  /// 查询指定 resourceStatus 的笔记列表（用于 ResourceFetchScheduler 扫描）
  Future<List<Note>> findByResourceStatus(String status) async {
    return _isar.notes
        .filter()
        .resourceStatusEqualTo(status)
        .isDeletedEqualTo(false)
        .urlIsNotNull()
        .findAll();
  }

  /// 更新笔记的 resourceStatus 字段并落库（不更新 updatedAt，避免干扰 LWW）
  Future<void> updateResourceStatus(Note note, String status) async {
    note.resourceStatus = status;
    await _isar.writeTxn(() async {
      await _isar.notes.put(note);
    });
  }
}
