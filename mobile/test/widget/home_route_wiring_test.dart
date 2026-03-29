import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/model/category.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/page/home/desktop/desktop_home_screen.dart';
import 'package:pocketmind/page/home/home_screen.dart';
import 'package:pocketmind/providers/category_providers.dart';
import 'package:pocketmind/providers/note_providers.dart';
import 'package:pocketmind/providers/shared_preferences_provider.dart';
import 'package:pocketmind/router/app_router.dart';
import 'package:pocketmind/service/note_service.dart';
import 'package:pocketmind/sync/sync_state_provider.dart';
import 'package:pocketmind/util/theme_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RouteStubNoteService implements NoteService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('home 路由在桌面端加载 DesktopHomeScreen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          searchQueryProvider.overrideWithValue('mock-query'),
          searchResultsProvider.overrideWith((ref) => Stream.value(const [])),
          allCategoriesProvider.overrideWith((ref) {
            final category = Category()
              ..id = 1
              ..name = '默认分类'
              ..description = 'desc';
            return Stream.value([category]);
          }),
          allNotesProvider.overrideWith((ref) {
            final note = Note()
              ..id = 1
              ..title = '标题'
              ..content = '内容';
            return Stream.value([note]);
          }),
          noteServiceProvider.overrideWith((ref) => _RouteStubNoteService()),
          syncIsInitialPullProvider.overrideWith((ref) => false),
        ],
        child: ScreenUtilInit(
          designSize: const Size(400, 869),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) => MaterialApp.router(
            theme: calmBeigeTheme,
            darkTheme: quietNightTheme,
            routerConfig: appRouter,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DesktopHomeScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });
}
