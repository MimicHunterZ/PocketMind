import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/util/theme_data.dart';

void main() {
  testWidgets('CategoryHomeColors 扩展可从 Theme 读取', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(400, 869),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) =>
            MaterialApp(theme: calmBeigeTheme, home: const Scaffold()),
      ),
    );

    final context = tester.element(find.byType(Scaffold));
    final ext = Theme.of(context).extension<CategoryHomeColors>();

    expect(ext, isNotNull);
    expect(ext!.cardBackground, isNotNull);
    expect(ext.topGlowGradient.length, 2);
    expect(ext.unifiedHomeGradient.length, 3);
  });
}
