import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/page/home/widgets/home_top_bar.dart';
import 'package:pocketmind/util/theme_data.dart';

void main() {
  testWidgets('顶部栏头像搜索新增按钮可点击', (tester) async {
    var avatarTapped = 0;
    var searchTapped = 0;
    var addTapped = 0;
    var backTapped = 0;

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(400, 869),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) => MaterialApp(
          theme: calmBeigeTheme,
          home: Scaffold(
            body: Column(
              children: [
                HomeTopBar(
                  onAvatarTap: () => avatarTapped++,
                  onSearchTap: () => searchTapped++,
                  onAddTap: () => addTapped++,
                ),
                HomeTopBar(
                  showSearchInput: true,
                  onAvatarTap: () {},
                  onSearchTap: () {},
                  onAddTap: () {},
                  searchController: TextEditingController(),
                  searchFocusNode: FocusNode(),
                  onSearchBackTap: () => backTapped++,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.tap(find.byIcon(Icons.search));
    await tester.tap(find.byIcon(Icons.add));
    await tester.tap(find.byIcon(Icons.arrow_back));

    expect(avatarTapped, 1);
    expect(searchTapped, 1);
    expect(addTapped, 1);
    expect(backTapped, 1);
  });
}
