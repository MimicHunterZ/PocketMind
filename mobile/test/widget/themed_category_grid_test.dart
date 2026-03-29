import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:mockito/mockito.dart';
import 'package:pocketmind/model/category.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/page/home/home_screen.dart';
import 'package:pocketmind/page/home/category_posts_screen.dart';
import 'package:pocketmind/page/home/widgets/note_feed_paged_view.dart';
import 'package:pocketmind/page/home/widgets/themed_category_card.dart';
import 'package:pocketmind/page/home/widgets/themed_category_grid.dart';
import 'package:pocketmind/providers/category_providers.dart';
import 'package:pocketmind/providers/note_providers.dart';
import 'package:pocketmind/providers/shared_preferences_provider.dart';
import 'package:pocketmind/service/note_service.dart';
import 'package:pocketmind/util/theme_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockNoteService extends Mock implements NoteService {}

class StubNoteService extends MockNoteService {
  final List<Note> notes;
  StubNoteService(this.notes);

  @override
  Stream<List<Note>> watchCategoryNotes(int categoryId) {
    return Stream.value(notes.where((note) => note.categoryId == categoryId).toList());
  }
}

void main() {
  setUpAll(() {
    disableThemedCategoryIconFloatAnimationForTest = true;
  });

  tearDownAll(() {
    disableThemedCategoryIconFloatAnimationForTest = false;
  });

  test('分类网格列数断点计算正确', () {
    expect(ThemedCategoryGrid.columnsForWidth(390), 2);
    expect(ThemedCategoryGrid.columnsForWidth(700), 3);
    expect(ThemedCategoryGrid.columnsForWidth(1200), 4);
    expect(ThemedCategoryGrid.columnsForWidth(1600), 5);
  });

  testWidgets('分类卡片点击后进入分类帖子页', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final category = Category()
      ..id = 7
      ..name = '测试分类'
      ..description = 'desc'
      ..createdTime = DateTime(2026, 3, 29);
    final note = Note()
      ..id = 1
      ..categoryId = 7
      ..title = '标题'
      ..content = '内容';
    final mockNoteService = StubNoteService([note]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allCategoriesProvider.overrideWith((ref) => Stream.value([category])),
          allNotesProvider.overrideWith((ref) => Stream.value([note])),
          noteServiceProvider.overrideWith((ref) => mockNoteService),
        ],
        child: ScreenUtilInit(
          designSize: const Size(400, 869),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) => MaterialApp(
            theme: calmBeigeTheme,
            home: Scaffold(body: ThemedCategoryGrid(categories: [category])),
          ),
        ),
      ),
    );

    await tester.tap(find.text('测试分类'));
    await tester.pumpAndSettle(const Duration(milliseconds: 120));

    expect(find.byType(CategoryPostsScreen), findsOneWidget);
  });

  testWidgets('分类帖子页使用复用分页组件并展示瀑布流', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final category = Category()
      ..id = 7
      ..name = '测试分类';
    final notes = List<Note>.generate(22, (index) {
      return Note()
        ..id = index + 1
        ..categoryId = 7
        ..title = '标题$index'
        ..content = '内容$index';
    });
    final mockNoteService = StubNoteService(notes);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allCategoriesProvider.overrideWith((ref) => Stream.value([category])),
          allNotesProvider.overrideWith((ref) => Stream.value(notes)),
          noteServiceProvider.overrideWith((ref) => mockNoteService),
        ],
        child: ScreenUtilInit(
          designSize: const Size(400, 869),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) => MaterialApp(
            theme: calmBeigeTheme,
            home: const CategoryPostsScreen(categoryId: 7),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(NoteFeedPagedView), findsOneWidget);
    expect(find.byType(MasonryGridView), findsOneWidget);
  });
}
