import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:pocketmind/model/nav_item.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/page/home/desktop/desktop_home_screen.dart';
import 'package:pocketmind/page/widget/desktop/desktop_sidebar.dart';
import 'package:pocketmind/providers/nav_providers.dart';
import 'package:pocketmind/providers/note_providers.dart';
import 'package:pocketmind/providers/shared_preferences_provider.dart';
import 'package:pocketmind/sync/sync_state_provider.dart';
import 'package:pocketmind/util/theme_data.dart';
import 'package:pocketmind/service/note_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNoteService extends Mock implements NoteService {}

class _StubNoteService extends _MockNoteService {
  @override
  Stream<List<Note>> watchCategoryNotes(int categoryId) {
    return Stream.value(const <Note>[]);
  }
}

void main() {
  testWidgets('桌面侧栏显示三个主Tab而不是分类列表', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    final navItems = [
      NavItem(svgPath: 'assets/icons/home.svg', text: 'home', category: 'home', categoryId: 1),
      NavItem(svgPath: 'assets/icons/x.svg', text: '展示', category: '展示', categoryId: 2),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          navItemsProvider.overrideWith((ref) => Stream.value(navItems)),
        ],
        child: ScreenUtilInit(
          designSize: const Size(1600, 1000),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) => MaterialApp(
            theme: calmBeigeTheme,
            home: const Scaffold(body: DesktopSidebar()),
          ),
        ),
      ),
    );

    expect(find.text('Everything'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('分类'), findsOneWidget);
    expect(find.text('home'), findsNothing);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('桌面Everything页不显示FAB，改为顶部新增按钮', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    final noteService = _StubNoteService();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allNotesProvider.overrideWith((ref) => Stream.value(const <Note>[])),
          noteServiceProvider.overrideWith((ref) => noteService),
          navItemsProvider.overrideWith(
            (ref) => Stream.value([
              NavItem(
                svgPath: 'assets/icons/home.svg',
                text: 'Everything',
                category: 'Everything',
                categoryId: 1,
              ),
            ]),
          ),
          syncIsInitialPullProvider.overrideWith((ref) => false),
          searchResultsProvider.overrideWith((ref) => Stream.value(const <Note>[])),
        ],
        child: ScreenUtilInit(
          designSize: const Size(1600, 1000),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) => MaterialApp(
            theme: calmBeigeTheme,
            home: const DesktopHomeScreen(),
          ),
        ),
      ),
    );

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byKey(const ValueKey('desktop_add_note_button')), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
}
