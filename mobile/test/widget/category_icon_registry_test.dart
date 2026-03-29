import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pocketmind/page/home/model/category_theme_icon_registry.dart';
import 'package:pocketmind/page/widget/category_icon_picker.dart';

void main() {
  test('主题图标注册表至少包含 10 个可替换图标', () {
    expect(themeCategoryIconOptions.length, greaterThanOrEqualTo(10));
    expect(
      themeCategoryIconOptions.first.assetPath,
      startsWith('assets/icons/jelly/'),
    );
  });

  testWidgets('主题图标资源都可被加载', (tester) async {
    for (final option in themeCategoryIconOptions) {
      final data = await rootBundle.loadString(option.assetPath);
      expect(data, contains('<svg'));
    }
  });

  testWidgets('图标选择器单次仅展示一个主图标', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(400, 869),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) => const MaterialApp(
          home: Scaffold(body: CategoryIconPickerDialog()),
        ),
      ),
    );

    final preview = find.byType(SvgPicture);
    expect(preview, findsOneWidget);
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
  });
}
