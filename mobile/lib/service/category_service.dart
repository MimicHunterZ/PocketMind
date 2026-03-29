import 'package:pocketmind/data/repositories/isar_category_repository.dart';
import 'package:pocketmind/model/category.dart';
import 'package:pocketmind/sync/local_write_coordinator.dart';
import 'package:pocketmind/sync/sync_engine.dart';
import 'package:pocketmind/util/logger_service.dart';

final String categoryServiceTag = 'CategoryService';

/// 分类业务服务层。
///
/// ## 写路径
/// 所有写操作（create / delete）通过 [LocalWriteCoordinator]
/// 在单个 Isar 事务中原子完成「业务表写入 + MutationEntry 追加」，
/// 完成后向 [SyncEngine] 发送 kick 信号，触发后端同步推送。
///
/// ## 读路径
/// 读操作直接委托 [IsarCategoryRepository] 的 Watch 流。
class CategoryService {
  final IsarCategoryRepository _categoryRepository;
  final LocalWriteCoordinator _writeCoordinator;
  final SyncEngine? _syncEngine;

  CategoryService({
    required IsarCategoryRepository categoryRepository,
    required LocalWriteCoordinator writeCoordinator,
    SyncEngine? syncEngine,
  })  : _categoryRepository = categoryRepository,
        _writeCoordinator = writeCoordinator,
        _syncEngine = syncEngine;

  /// 初始化默认分类（纯本地，不触发同步）
  Future<void> initDefaultCategories() async {
    await _categoryRepository.initDefaultCategories();
  }

  /// 获取所有分类
  Future<List<Category>> getAllCategories() async {
    return await _categoryRepository.getAll();
  }

  /// 根据ID获取分类
  Future<Category?> getCategoryById(int categoryId) async {
    return await _categoryRepository.getById(categoryId);
  }

  /// 根据名称获取分类
  Future<Category?> getCategoryByName(String name) async {
    return await _categoryRepository.getByName(name);
  }

  /// 添加分类（写入 Isar + 创建 create MutationEntry + kick 同步引擎）
  Future<int> addCategory({
    required String name,
    String? description,
    String? iconPath,
  }) async {
    final newCategory = Category()
      ..name = name
      ..description = description
      ..iconPath = iconPath
      ..createdTime = DateTime.now();

    final resultId = await _writeCoordinator.writeCategory(newCategory);
    _syncEngine?.kick();
    PMlog.d(
      categoryServiceTag,
      '分类添加成功（已追加同步 mutation）: id=$resultId, name=$name',
    );
    return resultId;
  }

  /// 软删除分类（写入 Isar + 创建 delete MutationEntry + kick 同步引擎）
  Future<void> deleteCategory(int categoryId) async {
    final cat = await _categoryRepository.getById(categoryId);
    if (cat == null) {
      PMlog.w(categoryServiceTag, '分类不存在，跳过删除: id=$categoryId');
      return;
    }
    await _writeCoordinator.softDeleteCategory(cat);
    _syncEngine?.kick();
    PMlog.d(categoryServiceTag, '分类软删除成功（已追加同步 mutation）: id=$categoryId');
  }

  /// 更新分类字段（名称/描述/图标）。
  Future<int> updateCategory({
    required int categoryId,
    String? name,
    String? description,
    String? iconPath,
  }) async {
    final category = await _categoryRepository.getById(categoryId);
    if (category == null) {
      throw Exception('分类不存在: id=$categoryId');
    }

    category
      ..name = name ?? category.name
      ..description = description ?? category.description
      ..iconPath = iconPath ?? category.iconPath;

    final resultId = await _writeCoordinator.writeCategory(category);
    _syncEngine?.kick();
    PMlog.d(categoryServiceTag, '分类更新成功: id=$categoryId');
    return resultId;
  }

  /// 监听所有分类变化
  Stream<List<Category>> watchAllCategories() {
    return _categoryRepository.watchAll();
  }
}
