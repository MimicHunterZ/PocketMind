import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/core/constants.dart';
import 'package:pocketmind/sync/resource_status_state_machine.dart';

void main() {
  group('ResourceStatusStateMachine.reduce 三态领域模型', () {
    test('null + localCreatedWithUrl → PENDING', () {
      expect(
        ResourceStatusStateMachine.reduce(
          current: null,
          event: ResourceStatusEvent.localCreatedWithUrl,
        ),
        AppConstants.resourceStatusPending,
      );
    });

    test('PENDING + attemptSucceeded → CRAWLED', () {
      expect(
        ResourceStatusStateMachine.reduce(
          current: AppConstants.resourceStatusPending,
          event: ResourceStatusEvent.attemptSucceeded,
        ),
        AppConstants.resourceStatusCrawled,
      );
    });

    test('PENDING + attemptTerminallyFailed → FAILED', () {
      expect(
        ResourceStatusStateMachine.reduce(
          current: AppConstants.resourceStatusPending,
          event: ResourceStatusEvent.attemptTerminallyFailed,
        ),
        AppConstants.resourceStatusFailed,
      );
    });

    test('PENDING + userForceComplete → FAILED', () {
      expect(
        ResourceStatusStateMachine.reduce(
          current: AppConstants.resourceStatusPending,
          event: ResourceStatusEvent.userForceComplete,
        ),
        AppConstants.resourceStatusFailed,
      );
    });

    test('FAILED + userRequestedRetry → PENDING', () {
      expect(
        ResourceStatusStateMachine.reduce(
          current: AppConstants.resourceStatusFailed,
          event: ResourceStatusEvent.userRequestedRetry,
        ),
        AppConstants.resourceStatusPending,
      );
    });

    test('FAILED + attemptSucceeded → CRAWLED（终态可以被升级）', () {
      expect(
        ResourceStatusStateMachine.reduce(
          current: AppConstants.resourceStatusFailed,
          event: ResourceStatusEvent.attemptSucceeded,
        ),
        AppConstants.resourceStatusCrawled,
      );
    });

    group('CRAWLED 终态保持', () {
      for (final event in ResourceStatusEvent.values) {
        test('CRAWLED + $event → CRAWLED', () {
          expect(
            ResourceStatusStateMachine.reduce(
              current: AppConstants.resourceStatusCrawled,
              event: event,
              incoming: AppConstants.resourceStatusPending,
            ),
            AppConstants.resourceStatusCrawled,
          );
        });
      }
    });

    group('serverSnapshot 合并语义', () {
      test('PENDING + serverSnapshot(CRAWLED) → CRAWLED', () {
        expect(
          ResourceStatusStateMachine.reduce(
            current: AppConstants.resourceStatusPending,
            event: ResourceStatusEvent.serverSnapshot,
            incoming: AppConstants.resourceStatusCrawled,
          ),
          AppConstants.resourceStatusCrawled,
        );
      });

      test('FAILED + serverSnapshot(PENDING) → FAILED（不被降级）', () {
        expect(
          ResourceStatusStateMachine.reduce(
            current: AppConstants.resourceStatusFailed,
            event: ResourceStatusEvent.serverSnapshot,
            incoming: AppConstants.resourceStatusPending,
          ),
          AppConstants.resourceStatusFailed,
        );
      });

      test('FAILED + serverSnapshot(CRAWLED) → CRAWLED（升级）', () {
        expect(
          ResourceStatusStateMachine.reduce(
            current: AppConstants.resourceStatusFailed,
            event: ResourceStatusEvent.serverSnapshot,
            incoming: AppConstants.resourceStatusCrawled,
          ),
          AppConstants.resourceStatusCrawled,
        );
      });

      test('serverSnapshot 无 incoming → 维持当前', () {
        expect(
          ResourceStatusStateMachine.reduce(
            current: AppConstants.resourceStatusPending,
            event: ResourceStatusEvent.serverSnapshot,
          ),
          AppConstants.resourceStatusPending,
        );
      });
    });

    test('未知历史状态（如 SCRAPING）被规范化为 PENDING', () {
      expect(
        ResourceStatusStateMachine.reduce(
          current: 'SCRAPING',
          event: ResourceStatusEvent.attemptSucceeded,
        ),
        AppConstants.resourceStatusCrawled,
      );

      // 当 current 是未知值，按 PENDING 处理：localCreatedWithUrl 应回 PENDING
      expect(
        ResourceStatusStateMachine.reduce(
          current: 'SCRAPING',
          event: ResourceStatusEvent.localCreatedWithUrl,
        ),
        AppConstants.resourceStatusPending,
      );
    });
  });
}
