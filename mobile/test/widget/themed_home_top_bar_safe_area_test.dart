import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/page/home/widgets/themed_home_top_bar.dart';
import 'package:pocketmind/util/theme_data.dart';

void main() {
  testWidgets('顶部栏使用 SafeArea 处理状态栏高度', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(400, 869),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) => MaterialApp(
          theme: calmBeigeTheme,
          home: Scaffold(
            body: ThemedHomeTopBar(
              onAvatarTap: () {},
              onSearchTap: () {},
              onAddTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SafeArea), findsOneWidget);
  });
}
