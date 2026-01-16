import 'package:pocketmind/core/constants.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/data/repositories/isar_note_repository.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'package:pocketmind/util/image_storage_helper.dart';
import 'package:pocketmind/service/metadata_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

final String noteServiceTag = 'NoteService';

/// 本地 Note 业务服务层
class NoteService {
  final IsarNoteRepository _noteRepository;
  final MetadataManager _metadataManager;
  final SharedPreferences _prefs;
  final ImageStorageHelper _imageHelper = ImageStorageHelper();

  NoteService(this._noteRepository, this._metadataManager, this._prefs);

  /// 新增笔记
  ///
  /// 如果保存失败，将抛出异常
  Future<int> addNote({
    String? title,
    String? content,
    String? url,
    int categoryId = AppConstants.homeCategoryId,
    String? tag,
    String? previewImageUrl,
    String? previewTitle,
    String? previewDescription,
    String? aiSummary,
  }) async {
    PMlog.d(
      noteServiceTag,
      'Adding note: title: $title, categoryId: $categoryId',
    );

    // 创建 Note 模型
    final note = Note()
      ..title = title
      ..content = content
      ..url = url
      ..categoryId = categoryId
      ..time = DateTime.now()
      ..tag = tag
      ..previewImageUrl = previewImageUrl
      ..previewTitle = previewTitle
      ..previewDescription = previewDescription
      ..aiSummary = aiSummary
      ..updatedAt = 0;

    final savedId = await _noteRepository.save(note, updateTimestamp: true);

    // todo 暂且不放在这边获取
    // // 如果包含 URL，触发异步元数据抓取
    // if (url != null && url.isNotEmpty) {
    //   // 异步执行，不阻塞保存操作
    //   Future.microtask(() async {
    //     try {
    //       final savedNote = await _noteRepository.getById(savedId);
    //       if (savedNote != null) {
    //         await enrichNoteWithMetadata(savedNote);
    //       }
    //     } catch (e) {
    //       PMlog.e(noteServiceTag, 'Background enrichment failed: $e');
    //     }
    //   });
    // }

    return savedId;
  }

  /// 更新笔记
  ///
  /// 如果保存失败，将抛出异常
  Future<int> updateNote({
    required int id,
    String? title,
    String? content,
    String? url,
    int? categoryId,
    String? tag,
    String? previewImageUrl,
    List<String>? previewImageUrls,
    String? previewTitle,
    String? previewContent,
    String? previewDescription,
    String? aiSummary,
    int? updatedAt,
    bool updateTimestamp = true,
  }) async {
    PMlog.d(
      noteServiceTag,
      'Updating note: id: $id, title: $title, updateTimestamp: $updateTimestamp',
    );

    final existingNote = await _noteRepository.getById(id);
    if (existingNote == null) {
      throw Exception('Note not found: $id');
    }

    // 更新字段（只更新提供的字段）
    existingNote.title = title ?? existingNote.title;
    existingNote.content = content ?? existingNote.content;
    existingNote.url = url ?? existingNote.url;
    existingNote.categoryId = categoryId ?? existingNote.categoryId;
    existingNote.tag = tag ?? existingNote.tag;
    existingNote.previewImageUrl =
        previewImageUrl ?? existingNote.previewImageUrl;
    existingNote.previewImageUrls =
        previewImageUrls ?? existingNote.previewImageUrls;
    existingNote.previewTitle = previewTitle ?? existingNote.previewTitle;
    existingNote.previewDescription =
        previewDescription ?? existingNote.previewDescription;
    existingNote.previewContent = previewContent ?? existingNote.previewContent;
    if (aiSummary != null) existingNote.aiSummary = aiSummary;
    existingNote.updatedAt = updatedAt ?? existingNote.updatedAt;

    final savedId = await _noteRepository.save(
      existingNote,
      updateTimestamp: updateTimestamp,
    );

    return savedId;
  }

  /// 根据笔记id获取笔记
  Future<Note?> getNoteById(int noteId) async {
    return await _noteRepository.getById(noteId);
  }

  /// 获取所有笔记
  Future<List<Note>> getAllNotes() async {
    return await _noteRepository.getAll();
  }

  /// 监听并且获取所有笔记
  Stream<List<Note>> watchAllNotes() {
    return _noteRepository.watchAll();
  }

  /// 监听categories变化并且获取笔记
  Stream<List<Note>> watchCategoryNotes(int category) {
    return _noteRepository.watchByCategory(category);
  }

  /// 删除笔记及其关联资源（如本地图片）
  Future<void> deleteNote(int noteId) async {
    final note = await _noteRepository.getById(noteId);
    if (note != null) {
      await deleteFullNote(note);
    }
  }

  /// 删除完整笔记对象及其关联资源
  Future<void> deleteFullNote(Note note) async {
    // 1. 处理关联资源（如本地图片）
    final url = note.url;
    if (url != null && url.isNotEmpty && _isLocalImage(url)) {
      await _imageHelper.deleteImage(url);
    }

    final previewUrl = note.previewImageUrl;
    if (previewUrl != null &&
        previewUrl.isNotEmpty &&
        _isLocalImage(previewUrl)) {
      await _imageHelper.deleteImage(previewUrl);
    }

    // 2. 从数据库删除
    if (note.id != null) {
      await _noteRepository.delete(note.id!);
      PMlog.d(noteServiceTag, 'Note deleted: ${note.id}');
    }
  }

  bool _isLocalImage(String path) {
    // 简单的本地路径判断逻辑，可以根据实际情况完善
    return path.contains('pocket_images/');
  }

  Future<void> deleteAllNoteByCategoryId(int categoryId) async {
    // TODO: 如果需要删除分类下所有笔记，也需要循环处理图片删除
    await _noteRepository.deleteAllByCategoryId(categoryId);
  }

  /// 根据 title 查询笔记
  Future<List<Note>> findNotesWithTitle(String query) async {
    return await _noteRepository.findByTitle(query);
  }

  /// 根据 content 查询笔记
  Future<List<Note>> findNotesWithContent(String query) async {
    return await _noteRepository.findByContent(query);
  }

  /// 根据 categoryId 查询笔记
  Future<List<Note>> findNotesWithCategory(int categoryId) async {
    return await _noteRepository.findByCategoryId(categoryId);
  }

  /// 根据 tag 查询笔记
  Future<List<Note>> findNotesWithTag(String query) async {
    return await _noteRepository.findByTag(query);
  }

  /// 全部匹配查询
  Stream<List<Note>> findNotesWithQuery(String query) {
    return _noteRepository.findByQuery(query);
  }

  // /// 丰富笔记元数据（链接预览）
  // ///
  // /// 自动抓取链接预览信息，本地化图片，并更新数据库
  // /// 如果抓取失败或数据不完整，返回原笔记对象
  // Future<Note> enrichNoteWithMetadata(Note note) async {
  //   final url = note.url;
  //   // 1. 基础校验：必须有 URL，且未处理过（或者强制刷新）
  //   if (url == null ||
  //       url.isEmpty ||
  //       (note.previewImageUrl != null && note.previewImageUrl!.isNotEmpty) ||
  //       (note.previewTitle != null && note.previewTitle!.isNotEmpty)) {
  //     return note;
  //   }
  //
  //   PMlog.d(noteServiceTag, '开始获取链接元数据: $url');
  //
  //   try {
  //     // 2. 调用 MetadataManager 获取并处理数据
  //     final results = await _metadataManager.fetchAndProcessMetadata([url]);
  //     final metadata = results[url];
  //
  //     if (metadata != null && metadata.isValid) {
  //       // 3. 更新数据库
  //       note.previewImageUrl = metadata.imageUrl;
  //       note.previewTitle = metadata.title;
  //       note.previewDescription = metadata.displayDescription;
  //
  //       if (metadata.previewContent != null &&
  //           metadata.previewContent!.trim().isNotEmpty) {
  //         note.previewContent = metadata.previewContent;
  //       }
  //       if (metadata.aiSummary != null &&
  //           metadata.aiSummary!.trim().isNotEmpty) {
  //         note.aiSummary = metadata.aiSummary;
  //       }
  //       if (metadata.resourceStatus != null) {
  //         note.resourceStatus = metadata.resourceStatus;
  //       }
  //
  //       await _noteRepository.save(note);
  //       PMlog.d(noteServiceTag, '元数据已更新: ${note.id}');
  //     }
  //     return note;
  //   } catch (e) {
  //     PMlog.e(noteServiceTag, '丰富笔记元数据失败: $e');
  //     return note;
  //   }
  // }

  /// 传入 note 从后端拉取资源正文/摘要
  ///
  /// - 仅当 url 存在且 previewContent 为空时尝试
  /// - 成功：写入 previewContent/aiSummary/resourceStatus，并落库
  /// - 失败：返回原笔记对象
  // Future<Note> fetchAndPersistResourceContentIfNeeded(Note note) async {
  //   final url = note.url;
  //   if (url == null || url.isEmpty) return note;
  //   if (note.previewContent != null && note.previewContent!.trim().isNotEmpty) {
  //     return note;
  //   }
  //
  //   try {
  //     final noteMetadata = await _metadataManager.fetchAndProcessMetadata([
  //       url,
  //     ]);
  //     if (noteMetadata.isEmpty) return note;
  //
  //     PMlog.d(noteServiceTag, '开始保存后端返回的note数据');
  //     note.title = noteMetadata[url]?.title ?? note.title;
  //     note.resourceStatus = noteMetadata[url]?.resourceStatus;
  //     note.previewContent = noteMetadata[url]?.previewContent;
  //     note.aiSummary = noteMetadata[url]?.aiSummary;
  //
  //     // todo 这边需要统一使用一个入口，但是 现在 id 和 uuid 还没区分开，先放着
  //     await _noteRepository.save(note);
  //     return note;
  //   } catch (e) {
  //     PMlog.e(noteServiceTag, '从后端获取资源内容失败: $e');
  //     return note;
  //   }
  // }

  // todo 确认一下 riverpod 最佳实践在这里是不是这样写最好
  /// 处理待回调的 URL
  ///
  /// 检查 SharedPreferences 中的 needCallBackUrl 列表
  /// 对每个 URL 尝试查找对应的 Note 并向后端资源内容
  Future<void> processPendingUrls() async {
    // 重新获取 SharedPreferences 实例，确保数据是最新的
    // 因为 Android 的 SharedPreferences 在不同进程（主应用和分享扩展）之间不会自动同步内存缓存。
    await _prefs.reload();
    final urls = _prefs.getStringList('needCallBackUrl') ?? [];
    if (urls.isEmpty) {
      PMlog.d(noteServiceTag, 'urls 为空不处理');
      return;
    }

    PMlog.d(noteServiceTag, '开始处理 URLs: $urls');
    final items = await _metadataManager.fetchAndProcessMetadata(urls);

    var notes = await _noteRepository.findByUrls(urls);
    for (final note in notes) {
      final item = items[note.url];
      if (item != null) {
        note.previewTitle = item.title;
        note.previewDescription = item.displayDescription;
        note.resourceStatus = item.resourceStatus;
        note.previewContent = item.previewContent;
        note.aiSummary = item.aiSummary;
        // 更新图片信息
        note.previewImageUrl = item.firstImage;
        if (item.imageUrls != null && item.imageUrls!.isNotEmpty) {
          note.previewImageUrls = item.imageUrls!;
        }
        await _noteRepository.save(note);
        PMlog.d(
          noteServiceTag,
          'Updated note ${note.id} with metadata, images=${note.previewImageUrls.length}',
        );
      }
    }

    PMlog.d(noteServiceTag, '开始消除 URLs: $urls');

    // 再次刷新，防止在处理过程中有新的 URL 加入
    await _prefs.reload();
    final currentUrls = _prefs.getStringList('needCallBackUrl') ?? [];
    for (var url in urls) {
      currentUrls.remove(url);
    }
    await _prefs.setStringList('needCallBackUrl', currentUrls);
    PMlog.d(
      noteServiceTag,
      'Pending URLs processed and cleared. Remaining: $currentUrls',
    );
  }
}
