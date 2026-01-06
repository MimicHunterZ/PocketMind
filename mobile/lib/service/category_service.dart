import 'package:pocketmind/data/repositories/isar_category_repository.dart';
import 'package:pocketmind/model/category.dart';
import 'package:pocketmind/util/logger_service.dart';

final String categoryServiceTag = 'CategoryService';

/// 分类业务服务层
class CategoryService {
  final IsarCategoryRepository _categoryRepository;

  CategoryService(this._categoryRepository);

  /// 初始化默认分类
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

  /// 添加分类
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

    final resultId = await _categoryRepository.save(newCategory);
    PMlog.d(
      categoryServiceTag,
      '分类添加成功: id: $resultId, name: $name, icon: $iconPath',
    );
    return resultId;
  }

  /// 删除分类
  Future<void> deleteCategory(int categoryId) async {
    await _categoryRepository.delete(categoryId);
    PMlog.d(categoryServiceTag, '分类删除成功');
  }

  /// 监听所有分类变化
  Stream<List<Category>> watchAllCategories() {
    return _categoryRepository.watchAll();
  }
}
