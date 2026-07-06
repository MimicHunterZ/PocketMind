import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketmind/demo/a2ui/chat_card_lock_preview_page.dart';
import 'package:pocketmind/page/chat/widgets/chat_message_widgets.dart';
import 'package:pocketmind/util/theme_data.dart';

Future<void> _settle(WidgetTester tester, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets(
    '已带提交交互消息的卡片一开始就锁定;未提交的卡片二选择+提交后立刻锁定,'
    '风格与卡片一一致;两张卡片互不影响',
    (tester) async {
      // 默认测试画布(800x600)跟 ScreenUtil 的 designSize(375x812)比例差太多,
      // 会导致底部一些图标/覆盖层重叠,点击坐标可能命中别的东西。换成接近
      // 真机比例的画布尺寸。
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (_, __) => MaterialApp.router(
              theme: ThemeData(
                extensions: const <ThemeExtension<dynamic>>[
                  lightChatBubbleColors,
                ],
              ),
              routerConfig: GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, __) => const ChatCardLockPreviewPage(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);

      // 初始状态:两张卡片都渲染出来,只有卡片一(已带提交交互消息)锁定。
      expect(
        find.byType(A2uiCardMessage, skipOffstage: false),
        findsNWidgets(2),
      );
      expect(
        find.byKey(
          const Key('a2ui-card-lock-barrier'),
          skipOffstage: false,
        ),
        findsOneWidget,
        reason: '两张卡片里应该只有一张一开始就锁定',
      );

      // 卡片二选一个方向、点提交——mock 会通过 a2uiCardSubmitHandlerProvider
      // 把这次提交写回本地假仓库,驱动消息列表重新 emit。卡片二在列表靠下的
      // 位置,先滚动到可见再点,避免命中坐标落在视口外。
      await tester.dragUntilVisible(
        find.text('自定义 ClassLoader').last,
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      await tester.tap(find.text('自定义 ClassLoader').last);
      await _settle(tester, frames: 3);
      await tester.dragUntilVisible(
        find.text('提交选择').last,
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      await tester.tap(find.text('提交选择').last);
      await _settle(tester);
      expect(tester.takeException(), isNull);

      // 提交后,两张卡片都应该锁定了。
      expect(
        find.byKey(
          const Key('a2ui-card-lock-barrier'),
          skipOffstage: false,
        ),
        findsNWidgets(2),
        reason: '卡片二提交后应该立刻锁定,和卡片一风格一致',
      );
    },
  );
}
