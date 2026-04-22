import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/core/constants.dart';
import 'package:pocketmind/sync/resource_status_state_machine.dart';

void main() {
  group('Resource status transition regression', () {
    test('先本地 CRAWLED，后 Pull 回流 PENDING，状态仍为 CRAWLED', () {
      final next = ResourceStatusStateMachine.reduce(
        current: AppConstants.resourceStatusCrawled,
        event: ResourceStatusEvent.serverSnapshot,
        incoming: AppConstants.resourceStatusPending,
      );

      expect(next, AppConstants.resourceStatusCrawled);
    });

    test('用户强制完成后，后台成功回流 CRAWLED，则升级为 CRAWLED', () {
      final forced = ResourceStatusStateMachine.reduce(
        current: AppConstants.resourceStatusScraping,
        event: ResourceStatusEvent.userForceComplete,
      );
      expect(forced, AppConstants.resourceStatusFailed);

      final next = ResourceStatusStateMachine.reduce(
        current: forced,
        event: ResourceStatusEvent.serverSnapshot,
        incoming: AppConstants.resourceStatusCrawled,
      );

      expect(next, AppConstants.resourceStatusCrawled);
    });

    test('用户强制完成后，后台失败回流 FAILED，保持 FAILED', () {
      final forced = ResourceStatusStateMachine.reduce(
        current: AppConstants.resourceStatusPending,
        event: ResourceStatusEvent.userForceComplete,
      );
      expect(forced, AppConstants.resourceStatusFailed);

      final next = ResourceStatusStateMachine.reduce(
        current: forced,
        event: ResourceStatusEvent.serverSnapshot,
        incoming: AppConstants.resourceStatusFailed,
      );

      expect(next, AppConstants.resourceStatusFailed);
    });
  });
}
