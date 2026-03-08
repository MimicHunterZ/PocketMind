import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/sync/model/sync_dto.dart';

void main() {
  group('SyncPushResult.fromJson', () {
    test('默认 retryable 为 false', () {
      final result = SyncPushResult.fromJson({
        'mutationId': 'm-1',
        'accepted': false,
        'rejectReason': 'PERMANENT',
      });

      expect(result.retryable, isFalse);
    });

    test('可正确解析 retryable 服务端结果', () {
      final result = SyncPushResult.fromJson({
        'mutationId': 'm-2',
        'accepted': false,
        'retryable': true,
        'rejectReason': 'SERVER_ERROR',
      });

      expect(result.retryable, isTrue);
      expect(result.rejectReason, 'SERVER_ERROR');
    });
  });
}
