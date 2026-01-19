import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pocketmind/model/nav_item.dart';
import 'package:pocketmind/data/repositories/isar_nav_item_repository.dart';
import 'package:pocketmind/providers/infrastructure_providers.dart';

part 'nav_providers.g.dart';

/// NavItemRepository Provider
@Riverpod(keepAlive: true)
IsarNavItemRepository navItemRepository(Ref ref) {
  final isar = ref.watch(isarProvider);
  return IsarNavItemRepository(isar);
}

/// 导航项列表 Provider (Stream)
@riverpod
Stream<List<NavItem>> navItems(Ref ref) {
  final repository = ref.watch(navItemRepositoryProvider);
  return repository.watchNavItems();
}

/// 当前激活的导航项索引 Provider
@riverpod
class ActiveNavIndex extends _$ActiveNavIndex {
  @override
  int build() => 0;

  void set(int value) => state = value;
}

/// 笔记布局模式枚举
enum NoteLayout { list, grid }

/// 当前激活的分类 ID Provider
@riverpod
Future<int> activeCategoryId(Ref ref) async {
  // 获取激活的下标
  final activeIndex = ref.watch(activeNavIndexProvider);
  // 获取最新的导航项
  final items = await ref.watch(navItemsProvider.future);
  // 获取当前分类的 categoryId
  return items[activeIndex].categoryId;
}
