import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/retry_policy.dart';

void main() {
  test('RetryPolicy retries and eventually succeeds', () async {
    var attempts = 0;
    final policy = RetryPolicy(
      maxAttempts: 3,
      backoff: const [Duration.zero, Duration.zero, Duration.zero],
    );

    final result = await policy.run(() async {
      attempts++;
      if (attempts < 3) {
        throw Exception('timeout');
      }
      return 'ok';
    });

    expect(result, 'ok');
    expect(attempts, 3);
  });

  test('RetryPolicy does not retry 404-style errors', () async {
    var attempts = 0;
    final policy = RetryPolicy(
      maxAttempts: 3,
      backoff: const [Duration.zero, Duration.zero, Duration.zero],
    );

    await expectLater(
      policy.run(() async {
        attempts++;
        throw Exception('HTTP 404');
      }),
      throwsA(isA<Exception>()),
    );

    expect(attempts, 1);
  });

  test('RetryPolicy retries transient HTTP 503 errors', () async {
    var attempts = 0;
    final policy = RetryPolicy(
      maxAttempts: 3,
      backoff: const [Duration.zero, Duration.zero, Duration.zero],
    );

    final result = await policy.run(() async {
      attempts++;
      if (attempts < 3) {
        throw Exception('HTTP 503 service unavailable');
      }
      return 'ok';
    });

    expect(result, 'ok');
    expect(attempts, 3);
  });

  test('RetryPolicy does not retry not-found errors', () async {
    var attempts = 0;
    final policy = RetryPolicy(
      maxAttempts: 3,
      backoff: const [Duration.zero, Duration.zero, Duration.zero],
    );

    await expectLater(
      policy.run(() async {
        attempts++;
        throw Exception('resource not found');
      }),
      throwsA(isA<Exception>()),
    );

    expect(attempts, 1);
  });
}
