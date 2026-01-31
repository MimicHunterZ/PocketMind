import 'package:isar_community/isar.dart';
import 'package:uuid/uuid.dart';
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
  static const _uuid = Uuid();

  IsarNoteRepository(this._isar);

  Future<int> save(Note note, {bool updateTimestamp = true}) async {
    PMlog.d(
      _tag,
      'Saving note: title: ${note.title}, categoryId: ${note.categoryId}, updateTimestamp: $updateTimestamp',
    );

    try {
      // 如果没有设置时间，使用当前时间
      note.time ??= DateTime.now();

      // 设置同步字段
      if (updateTimestamp) {
        note.updatedAt = DateTime.now().millisecondsSinceEpoch;
      }

      // 如果是更新操作，保留现有的 uuid
      // 注意：如果传入的 note 已经是从数据库取出的对象，它应该已经有 uuid 了
      // 这里主要是为了防止新建对象时覆盖了原有的 uuid
      if (note.id != null && note.id != Isar.autoIncrement) {
        final existingNote = await _isar.notes.get(note.id!);
        if (existingNote != null && existingNote.uuid != null) {
          if (note.uuid == null || note.uuid!.isEmpty) {
            note.uuid = existingNote.uuid;
          }
        }
      }

      // 如果是新记录或者没有 uuid，生成新的 UUID
      if (note.uuid == null || note.uuid!.isEmpty) {
        note.uuid = _uuid.v4();
      }

      int resultId = 0;
      await _isar.writeTxn(() async {
        // 建立笔记与分类的关联（保持 IsarLink 用于数据库关系）
        final linkedCategory = await _isar.categorys.get(note.categoryId);
        note.category.value = linkedCategory;

        // 保存笔记
        resultId = await _isar.notes.put(note);
        await note.category.save();
      });

      PMlog.d(_tag, 'Note saved successfully with id: $resultId');
      return resultId;
    } catch (e, stackTrace) {
      PMlog.e(_tag, 'Error while saving note: $e\n$stackTrace');
      rethrow;
    }
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
          for (final previewUrl in note.previewImageUrls) {
            if (previewUrl.startsWith(AppConstants.localImagePathPrefix)) {
              try {
                await ImageStorageHelper().deleteImage(previewUrl);
                PMlog.d(_tag, 'Deleted preview image: $previewUrl');
              } catch (e) {
                PMlog.w(_tag, 'Failed to delete preview image $previewUrl: $e');
              }
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

  Future<void> deleteAllByCategoryId(int categoryId) async {
    try {
      await _isar.writeTxn(() async {
        final notes = await _isar.notes
            .filter()
            .categoryIdEqualTo(categoryId)
            .findAll();
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final note in notes) {
          // 删除对应的图片文件（如果有）
          if (note.url != null &&
              note.url!.startsWith(AppConstants.localImagePathPrefix)) {
            try {
              await ImageStorageHelper().deleteImage(note.url!);
            } catch (e) {
              PMlog.w(_tag, 'Failed to delete image ${note.url}: $e');
            }
          }

          note.isDeleted = true;
          note.updatedAt = now;
        }
        await _isar.notes.putAll(notes);
        PMlog.d(_tag, '成功软删除了 ${notes.length} 条 categoryId为 $categoryId 的笔记');
      });
    } catch (e, stackTrace) {
      PMlog.e(_tag, 'Error while deleting notes by category: $e\n$stackTrace');
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
          .tagContains(query, caseSensitive: false)
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
                .tagContains(query, caseSensitive: false)
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
}
