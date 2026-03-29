import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/data/repositories/isar_nav_item_repository.dart';
import 'package:pocketmind/model/category.dart';

void main() {
  test('导航项图标优先使用分类 iconPath', () {
    final category = Category()
      ..name = '测试分类'
      ..iconPath = 'assets/icons/jelly/notes.svg';

    final icon = resolveNavItemIconPath(category);
    expect(icon, 'assets/icons/jelly/notes.svg');
  });

  test('当 iconPath 为空时回退默认映射', () {
    final category = Category()
      ..name = 'b站'
      ..iconPath = null;

    final icon = resolveNavItemIconPath(category);
    expect(icon, 'assets/icons/bilibili.svg');
  });
}
