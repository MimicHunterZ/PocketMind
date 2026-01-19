import 'package:isar_community/isar.dart';
import 'package:pocketmind/model/nav_item.dart';
import 'package:pocketmind/model/category.dart';

/// 基于 Isar Category 的导航项仓库实现
class IsarNavItemRepository {
  final Isar isar;

  IsarNavItemRepository(this.isar);

  Stream<List<NavItem>> watchNavItems() {
    return isar.categorys
        .filter()
        .isDeletedEqualTo(false) // 1. 在数据库层面直接过滤
        .sortByCreatedTime() // 2. 排序
        .watch(fireImmediately: true)
        .map((categories) {
          // 3. 此时 categories 里全是有效数据，直接转换即可
          return categories.map((category) {
            return NavItem(
              svgPath: _getIconForCategory(category.name),
              text: category.name,
              category: category.name,
              categoryId: category.id ?? 0,
            );
          }).toList();
        });
  }

  /// 根据 category 返回对应的图标路径
  /// TODO: 根据实际需求配置不同分类的图标
  String _getIconForCategory(String category) {
    // 这里可以根据不同的 category 返回不同的图标
    // 目前先返回默认图标
    const iconMap = {
      '工作': 'assets/icons/work.svg',
      '学习': 'assets/icons/study.svg',
      '生活': 'assets/icons/life.svg',
      '娱乐': 'assets/icons/entertainment.svg',
      'b站': 'assets/icons/bilibili.svg',
    };

    return iconMap[category] ?? 'assets/icons/bilibili.svg';
  }
}
