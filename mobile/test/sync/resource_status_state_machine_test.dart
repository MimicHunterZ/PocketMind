import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/core/constants.dart';
import 'package:pocketmind/sync/resource_status_state_machine.dart';

void main() {
  group('ResourceStatusStateMachine.reduce', () {
    test('CRAWLED 遇到 serverSnapshot(PENDING) 时保持 CRAWLED', () {
      final next = ResourceStatusStateMachine.reduce(
        current: AppConstants.resourceStatusCrawled,
        event: ResourceStatusEvent.serverSnapshot,
        incoming: AppConstants.resourceStatusPending,
      );

      expect(next, AppConstants.resourceStatusCrawled);
    });

    test('CRAWLED 遇到 fetchFailed 时保持 CRAWLED', () {
      final next = ResourceStatusStateMachine.reduce(
        current: AppConstants.resourceStatusCrawled,
        event: ResourceStatusEvent.fetchFailed,
      );

      expect(next, AppConstants.resourceStatusCrawled);
    });

    test('PENDING 遇到 userForceComplete 时转为 FAILED', () {
      final next = ResourceStatusStateMachine.reduce(
        current: AppConstants.resourceStatusPending,
        event: ResourceStatusEvent.userForceComplete,
      );

      expect(next, AppConstants.resourceStatusFailed);
    });

    test('FAILED 遇到 fetchSucceeded 时升级为 CRAWLED', () {
      final next = ResourceStatusStateMachine.reduce(
        current: AppConstants.resourceStatusFailed,
        event: ResourceStatusEvent.fetchSucceeded,
      );

      expect(next, AppConstants.resourceStatusCrawled);
    });

    test('SCRAPING 遇到 userForceComplete 时转为 FAILED', () {
      final next = ResourceStatusStateMachine.reduce(
        current: AppConstants.resourceStatusScraping,
        event: ResourceStatusEvent.userForceComplete,
      );

      expect(next, AppConstants.resourceStatusFailed);
    });

    test('FAILED 遇到 serverSnapshot(PENDING) 时保持 FAILED', () {
      final next = ResourceStatusStateMachine.reduce(
        current: AppConstants.resourceStatusFailed,
        event: ResourceStatusEvent.serverSnapshot,
        incoming: AppConstants.resourceStatusPending,
      );

      expect(next, AppConstants.resourceStatusFailed);
    });
  });
}
