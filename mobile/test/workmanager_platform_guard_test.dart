import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/util/workmanager_platform_guard.dart';

void main() {
  test('仅 Android 与 iOS 启用 Workmanager', () {
    expect(shouldInitializeWorkmanager('android'), isTrue);
    expect(shouldInitializeWorkmanager('ios'), isTrue);
    expect(shouldInitializeWorkmanager('windows'), isFalse);
    expect(shouldInitializeWorkmanager('linux'), isFalse);
    expect(shouldInitializeWorkmanager('macos'), isFalse);
  });
}
