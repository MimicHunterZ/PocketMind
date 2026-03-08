import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/sync/sync_checkpoint_policy.dart';

void main() {
  group('SyncCheckpointPolicy.isInitialPullVersion', () {
    test('null 视为首次拉取', () {
      expect(SyncCheckpointPolicy.isInitialPullVersion(null), isTrue);
    });

    test('0 视为首次拉取', () {
      expect(SyncCheckpointPolicy.isInitialPullVersion(0), isTrue);
    });

    test('大于 0 视为已完成过至少一次拉取', () {
      expect(SyncCheckpointPolicy.isInitialPullVersion(1), isFalse);
      expect(SyncCheckpointPolicy.isInitialPullVersion(42), isFalse);
    });
  });
}
