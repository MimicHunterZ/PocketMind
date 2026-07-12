import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/demo/a2ui/open_note_function_demo_page.dart';
import 'package:pocketmind/util/pocketmind_a2ui_catalog.dart';
import 'package:pocketmind/util/theme_data.dart';

/// 验证 [OpenNoteFunction] 真的注册进了共享 catalog(Decision 1),且点击卡片
/// 里的按钮走的是本地 `functionCall`——不会抛异常,也不会走 `event` 往返
/// (这张 demo 卡片没有 `onSubmitted`,若误走 event 分支不会有地方处理,但至少
/// 不应该抛异常)。真实的页面跳转由 [appNavigatorKey] 驱动,在没有真实
/// `MaterialApp.router` 挂载时 `currentContext` 为 null,函数应该安全地空转
/// 而不是崩溃——这正是本测试要覆盖的分支。
void main() {
  test('pocketMindA2uiCatalog 注册了 openNote 本地函数', () {
    expect(
      pocketMindA2uiCatalog.functions.any((f) => f.name == 'openNote'),
      isTrue,
    );
  });

  testWidgets('点击笔记按钮触发本地 functionCall,不抛异常', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[lightChatBubbleColors],
          ),
          home: const OpenNoteFunctionDemoPage(),
        ),
      ),
    );

    await tester.tap(find.text('打开《示例笔记 A》'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
