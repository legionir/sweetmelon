import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/security/lib/security.dart';

void main() {
  group('ExecutionGuard', () {
    late ExecutionGuard guard;

    setUp(() {
      guard = ExecutionGuard(defaultTimeoutMs: 1000);
    });

    test('executes successfully', () async {
      final result = await guard.execute(
        requestId: 'req_1',
        fn: () async => 42,
      );

      expect(result, 42);
    });

    test('times out after duration', () async {
      expect(
        () => guard.execute(
          requestId: 'req_2',
          fn: () async {
            await Future.delayed(const Duration(seconds: 5));
            return 'too late';
          },
          timeoutMs: 100,
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('tracks active executions', () async {
      final completer = Completer<void>();

      final future = guard.execute(
        requestId: 'req_3',
        fn: () async {
          await completer.future;
          return 'done';
        },
      );

      expect(guard.activeCount, 1);
      expect(guard.isActive('req_3'), true);

      completer.complete();
      await future;

      expect(guard.activeCount, 0);
      expect(guard.isActive('req_3'), false);
    });

    test('removes from active on error', () async {
      try {
        await guard.execute(
          requestId: 'req_4',
          fn: () async => throw Exception('error'),
        );
      } catch (_) {}

      expect(guard.isActive('req_4'), false);
    });
  });
}
