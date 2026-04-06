import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:pocketmind/core/constants.dart';
import 'package:pocketmind/model/category.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/page/home/category_posts_screen.dart';
import 'package:pocketmind/page/home/home_screen.dart';
import 'package:pocketmind/page/home/widgets/category_card.dart';
import 'package:pocketmind/providers/category_providers.dart';
import 'package:pocketmind/providers/note_providers.dart';
import 'package:pocketmind/providers/shared_preferences_provider.dart';
import 'package:pocketmind/router/route_paths.dart';
import 'package:pocketmind/service/note_service.dart';
import 'package:pocketmind/sync/sync_state_provider.dart';
import 'package:pocketmind/util/theme_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockNoteService extends Mock implements NoteService {}

class StubNoteService extends MockNoteService {
  @override
  Stream<List<Note>> watchCategoryNotes(int categoryId) {
    return Stream.value(const []);
  }
}

void main() {
  setUpAll(() {
    disableThemedCategoryIconFloatAnimationForTest = true;
  });

  tearDownAll(() {
    disableThemedCategoryIconFloatAnimationForTest = false;
  });

  testWidgets('everything页显示顶部栏，分类页显示分类FAB，保留AI入口', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final category = Category()
      ..id = 2
      ..name = '默认分类'
      ..description = 'desc'
      ..createdTime = DateTime(2026, 3, 29);
    final note = Note()
      ..id = 1
      ..categoryId = 2
      ..title = '标题'
      ..content = '内容';
    final noteService = StubNoteService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          searchResultsProvider.overrideWith((ref) => Stream.value(const [])),
          allCategoriesProvider.overrideWith((ref) => Stream.value([category])),
          allNotesProvider.overrideWith((ref) => Stream.value([note])),
          noteServiceProvider.overrideWith((ref) => noteService),
          syncIsInitialPullProvider.overrideWith((ref) => false),
        ],
        child: ScreenUtilInit(
          designSize: const Size(400, 869),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) => MaterialApp(
            theme: calmBeigeTheme,
            home: const HomeScreen(),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Everything'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('分类'), findsOneWidget);

    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle(const Duration(milliseconds: 120));

    expect(find.byIcon(Icons.account_circle_outlined), findsNothing);
    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('home'), findsNothing);
    expect(find.text('默认分类'), findsOneWidget);
  });

  testWidgets('点击搜索后顶部切换为搜索输入框并可返回', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final category = Category()
      ..id = 1
      ..name = '默认分类';
    final noteService = StubNoteService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allCategoriesProvider.overrideWith((ref) => Stream.value([category])),
          allNotesProvider.overrideWith((ref) => Stream.value(const [])),
          searchResultsProvider.overrideWith((ref) => Stream.value(const [])),
          noteServiceProvider.overrideWith((ref) => noteService),
          syncIsInitialPullProvider.overrideWith((ref) => false),
        ],
        child: ScreenUtilInit(
          designSize: const Size(400, 869),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) => MaterialApp(
            theme: calmBeigeTheme,
            home: const HomeScreen(),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle(const Duration(milliseconds: 120));

    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('点击AI后跳转到globalAi路由入口', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final category = Category()
      ..id = 1
      ..name = '默认分类';
    final noteService = StubNoteService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allCategoriesProvider.overrideWith((ref) => Stream.value([category])),
          allNotesProvider.overrideWith((ref) => Stream.value(const [])),
          searchResultsProvider.overrideWith((ref) => Stream.value(const [])),
          noteServiceProvider.overrideWith((ref) => noteService),
          syncIsInitialPullProvider.overrideWith((ref) => false),
        ],
        child: ScreenUtilInit(
          designSize: const Size(400, 869),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) {
            final router = GoRouter(
              routes: [
                GoRoute(
                  path: RoutePaths.home,
                  builder: (_, _) => const HomeScreen(),
                ),
                GoRoute(
                  path: RoutePaths.globalAi,
                  builder: (_, _) => const Scaffold(body: Text('global-ai-page')),
                ),
              ],
            );
            return MaterialApp.router(
              theme: calmBeigeTheme,
              routerConfig: router,
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle(const Duration(milliseconds: 120));

    expect(find.text('global-ai-page'), findsOneWidget);
  });

  testWidgets('分类帖子页菜单包含删除/修改名称/修改描述', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final category = Category()
      ..id = 11
      ..name = '菜单分类';
    final noteService = StubNoteService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allCategoriesProvider.overrideWith((ref) => Stream.value([category])),
          noteServiceProvider.overrideWith((ref) => noteService),
          syncIsInitialPullProvider.overrideWith((ref) => false),
        ],
        child: ScreenUtilInit(
          designSize: const Size(400, 869),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) => MaterialApp(
            theme: calmBeigeTheme,
            home: const CategoryPostsScreen(categoryId: 11),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 120));

    await tester.tap(find.byKey(const ValueKey('category_posts_menu_button')));
    await tester.pumpAndSettle(const Duration(milliseconds: 120));

    expect(find.text('删除分类'), findsOneWidget);
    expect(find.text('修改分类名字'), findsOneWidget);
    expect(find.text('修改分类描述'), findsOneWidget);
  });

  testWidgets('分类卡片优先使用jelly图标资源', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final category = Category()
      ..id = 2
      ..name = '测试分类'
      ..iconPath = 'assets/icons/home.svg';
    final noteService = StubNoteService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          searchResultsProvider.overrideWith((ref) => Stream.value(const [])),
          allCategoriesProvider.overrideWith((ref) => Stream.value([category])),
          allNotesProvider.overrideWith((ref) => Stream.value(const [])),
          noteServiceProvider.overrideWith((ref) => noteService),
          syncIsInitialPullProvider.overrideWith((ref) => false),
        ],
        child: ScreenUtilInit(
          designSize: const Size(400, 869),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) => MaterialApp(
            theme: calmBeigeTheme,
            home: const HomeScreen(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle(const Duration(milliseconds: 120));

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture).first);
    final loader = svg.bytesLoader as SvgAssetLoader;
    expect(loader.assetName, startsWith('assets/icons/jelly/'));
  });

  testWidgets('分类卡片优先使用用户选择的jelly图标', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final category = Category()
      ..id = 9
      ..name = '随便名称'
      ..iconPath = 'assets/icons/jelly/github.svg';
    final noteService = StubNoteService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          searchResultsProvider.overrideWith((ref) => Stream.value(const [])),
          allCategoriesProvider.overrideWith((ref) => Stream.value([category])),
          allNotesProvider.overrideWith((ref) => Stream.value(const [])),
          noteServiceProvider.overrideWith((ref) => noteService),
          syncIsInitialPullProvider.overrideWith((ref) => false),
        ],
        child: ScreenUtilInit(
          designSize: const Size(400, 869),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) => MaterialApp(
            theme: calmBeigeTheme,
            home: const HomeScreen(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle(const Duration(milliseconds: 120));

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture).first);
    final loader = svg.bytesLoader as SvgAssetLoader;
    expect(loader.assetName, equals('assets/icons/jelly/github.svg'));
  });

  testWidgets('分类页不展示home分类', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final homeCategory = Category()
      ..id = AppConstants.homeCategoryId
      ..name = AppConstants.homeCategoryName;
    final workCategory = Category()
      ..id = 3
      ..name = '工作';
    final noteService = StubNoteService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          searchResultsProvider.overrideWith((ref) => Stream.value(const [])),
          allCategoriesProvider.overrideWith(
            (ref) => Stream.value([homeCategory, workCategory]),
          ),
          allNotesProvider.overrideWith((ref) => Stream.value(const [])),
          noteServiceProvider.overrideWith((ref) => noteService),
          syncIsInitialPullProvider.overrideWith((ref) => false),
        ],
        child: ScreenUtilInit(
          designSize: const Size(400, 869),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) => MaterialApp(
            theme: calmBeigeTheme,
            home: const HomeScreen(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle(const Duration(milliseconds: 120));

    expect(find.text(AppConstants.homeCategoryName), findsNothing);
    expect(find.text('工作'), findsOneWidget);
  });

  testWidgets('分类页主体使用SafeArea避免状态栏重叠', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final category = Category()
      ..id = 5
      ..name = '测试分类';
    final noteService = StubNoteService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allCategoriesProvider.overrideWith((ref) => Stream.value([category])),
          allNotesProvider.overrideWith((ref) => Stream.value(const [])),
          searchResultsProvider.overrideWith((ref) => Stream.value(const [])),
          noteServiceProvider.overrideWith((ref) => noteService),
          syncIsInitialPullProvider.overrideWith((ref) => false),
        ],
        child: ScreenUtilInit(
          designSize: const Size(400, 869),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) => MaterialApp(
            theme: calmBeigeTheme,
            home: const HomeScreen(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle(const Duration(milliseconds: 120));

    expect(
      find.byWidgetPredicate(
        (widget) => widget is SafeArea && widget.top && !widget.bottom,
      ),
      findsOneWidget,
    );
  });

  testWidgets('新增分类弹窗包含描述输入框', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final category = Category()
      ..id = 2
      ..name = '默认分类';
    final noteService = StubNoteService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          searchResultsProvider.overrideWith((ref) => Stream.value(const [])),
          allCategoriesProvider.overrideWith((ref) => Stream.value([category])),
          allNotesProvider.overrideWith((ref) => Stream.value(const [])),
          noteServiceProvider.overrideWith((ref) => noteService),
        ],
        child: ScreenUtilInit(
          designSize: const Size(400, 869),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) => MaterialApp(
            theme: calmBeigeTheme,
            home: const HomeScreen(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle(const Duration(milliseconds: 120));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle(const Duration(milliseconds: 120));

    expect(find.text('分类描述（可选）'), findsOneWidget);
  });
}
