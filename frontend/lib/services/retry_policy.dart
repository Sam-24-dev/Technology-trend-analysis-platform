typedef RetryPredicate = bool Function(Object error);

class RetryPolicy {
  final int maxAttempts;
  final List<Duration> backoff;
  final RetryPredicate shouldRetry;

  const RetryPolicy({
    this.maxAttempts = 3,
    this.backoff = const [
      Duration(milliseconds: 300),
      Duration(milliseconds: 900),
      Duration(milliseconds: 1800),
    ],
    this.shouldRetry = _defaultShouldRetry,
  });

  static bool _defaultShouldRetry(Object error) {
    final text = error.toString().toLowerCase();

    if (text.contains('404')) return false;
    if (text.contains('not found')) return false;

    return text.contains('timeout') ||
        text.contains('http 5') ||
        text.contains('socket') ||
        text.contains('connection') ||
        text.contains('tempor') ||
        text.contains('network');
  }

  Future<T> run<T>(Future<T> Function() action) async {
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await action();
      } catch (error) {
        lastError = error;
        final canRetry = attempt < maxAttempts && shouldRetry(error);
        if (!canRetry) {
          rethrow;
        }

        final waitIndex = attempt - 1;
        final delay = waitIndex < backoff.length
            ? backoff[waitIndex]
            : backoff.last;
        await Future<void>.delayed(delay);
      }
    }

    throw lastError ?? Exception('Retry failed without error details');
  }
}
