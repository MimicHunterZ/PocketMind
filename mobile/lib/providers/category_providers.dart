import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pocketmind/model/category.dart';
import 'package:pocketmind/data/repositories/isar_category_repository.dart';
import 'package:pocketmind/providers/infrastructure_providers.dart';
import 'package:pocketmind/providers/sync_providers.dart';
import 'package:pocketmind/service/category_service.dart';

part 'category_providers.g.dart';

/// CategoryRepository Provider - 数据层
/// 提供 Isar 的具体实现（与 sync_providers.dart 中共用同一 provider，
/// 若已经 import sync_providers，此处直接复用 categoryRepositoryProvider）
@Riverpod(keepAlive: true)
IsarCategoryRepository isarCategoryRepository(Ref ref) {
  final isar = ref.watch(isarProvider);
  return IsarCategoryRepository(isar);
}

/// CategoryService Provider - 业务层
/// 注入 LocalWriteCoordinator + SyncEngine，确保写操作走同步链路
@Riverpod(keepAlive: true)
CategoryService categoryService(Ref ref) {
  final repository = ref.watch(isarCategoryRepositoryProvider);
  final coordinator = ref.watch(localWriteCoordinatorProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return CategoryService(
    categoryRepository: repository,
    writeCoordinator: coordinator,
    syncEngine: syncEngine,
  );
}

/// 所有分类 Stream Provider - 自动监听数据库变化
@riverpod
Stream<List<Category>> allCategories(Ref ref) {
  final categoryService = ref.watch(categoryServiceProvider);
  return categoryService.watchAllCategories();
}

/// 分类操作 Notifier - 封装所有分类相关的业务操作
///
/// UI 层应通过此 Notifier 进行分类的增删改操作，
/// 而不是直接调用 CategoryService
@riverpod
class CategoryActions extends _$CategoryActions {
  @override
  void build() {
    // 无状态，仅提供方法
  }

  /// 添加新分类
  ///
  /// [name] 分类名称（必填）
  /// [description] 分类描述（可选）
  /// [iconPath] 分类图标路径（可选）
  /// 返回新创建分类的 ID
  Future<int> addCategory({
    required String name,
    String? description,
    String? iconPath,
  }) async {
    final service = ref.read(categoryServiceProvider);
    return await service.addCategory(
      name: name,
      description: description,
      iconPath: iconPath,
    );
  }

  /// 删除分类（软删除，触发同步）
  Future<void> deleteCategory(int categoryId) async {
    final service = ref.read(categoryServiceProvider);
    await service.deleteCategory(categoryId);
  }

  /// 更新分类（名称/描述/图标）。
  Future<int> updateCategory({
    required int categoryId,
    String? name,
    String? description,
    String? iconPath,
  }) async {
    final service = ref.read(categoryServiceProvider);
    return await service.updateCategory(
      categoryId: categoryId,
      name: name,
      description: description,
      iconPath: iconPath,
    );
  }

  /// 获取分类详情
  Future<Category?> getCategoryById(int categoryId) async {
    final service = ref.read(categoryServiceProvider);
    return await service.getCategoryById(categoryId);
  }
}
