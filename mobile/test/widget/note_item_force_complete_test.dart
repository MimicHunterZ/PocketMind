import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:pocketmind/core/constants.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/page/widget/note_Item.dart';
import 'package:pocketmind/service/note_service.dart';
import 'package:pocketmind/util/theme_data.dart';

class _MockNoteService extends Mock implements NoteService {}

class _SafeMockNoteService extends _MockNoteService {
  @override
  Future<void> forceCompleteByUser(Note note) {
    return super.noSuchMethod(
          Invocation.method(#forceCompleteByUser, [note]),
          returnValue: Future.value(),
          returnValueForMissingStub: Future.value(),
        )
        as Future<void>;
  }
}

void main() {
  testWidgets('loading 卡片点击强制完成后触发 NoteService.forceCompleteByUser', (
    tester,
  ) async {
    final note = Note()
      ..id = 1
      ..uuid = 'u1'
      ..url = 'https://example.com/post'
      ..resourceStatus = AppConstants.resourceStatusPending
      ..time = DateTime(2026, 4, 22);

    final noteService = _SafeMockNoteService();

    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: const Size(400, 869),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) => MaterialApp(
            theme: calmBeigeTheme,
            home: Scaffold(
              body: NoteItem(
                note: note,
                noteService: noteService,
                isWaterfall: true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('长按强制完成'), findsOneWidget);

    await tester.longPress(find.text('长按强制完成'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      find.text('确认强制结束 loading 并进入预览吗？该状态将同步到其他设备。'),
      findsOneWidget,
    );

    final confirmAction = find
        .ancestor(
          of: find.text('强制完成').last,
          matching: find.byWidgetPredicate(
            (widget) => widget is GestureDetector && widget.onTap != null,
          ),
        )
        .last;

    await tester.tap(confirmAction);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    verify(noteService.forceCompleteByUser(note)).called(1);
  });
}
