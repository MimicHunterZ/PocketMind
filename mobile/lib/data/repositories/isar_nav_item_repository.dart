import 'package:isar_community/isar.dart';
import 'package:pocketmind/model/nav_item.dart';
import 'package:pocketmind/model/category.dart';

/// 解析导航项图标路径：优先使用分类自定义 iconPath
String resolveNavItemIconPath(Category category) {
  final iconPath = category.iconPath;
  if (iconPath != null && iconPath.trim().isNotEmpty) {
    return iconPath;
  }
  return _fallbackIconForCategory(category.name);
}

String _fallbackIconForCategory(String category) {
  const iconMap = {
    '工作': 'assets/icons/work.svg',
    '学习': 'assets/icons/study.svg',
    '生活': 'assets/icons/life.svg',
    '娱乐': 'assets/icons/entertainment.svg',
    'b站': 'assets/icons/bilibili.svg',
    'B站': 'assets/icons/bilibili.svg',
    '小红书': 'assets/icons/redBook.svg',
    'X': 'assets/icons/x.svg',
  };

  return iconMap[category] ?? 'assets/icons/home.svg';
}

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
              svgPath: resolveNavItemIconPath(category),
              text: category.name,
              category: category.name,
              categoryId: category.id ?? 0,
            );
          }).toList();
        });
  }
}
