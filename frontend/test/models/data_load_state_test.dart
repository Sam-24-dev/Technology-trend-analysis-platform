import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/data_load_state.dart';

void main() {
  test('DataLoadState.data sets data status', () {
    final state = DataLoadState<int>.data(42, message: 'ok');

    expect(state.status, DataStatus.data);
    expect(state.data, 42);
    expect(state.message, 'ok');
    expect(state.isData, true);
    expect(state.isDegraded, false);
    expect(state.isError, false);
  });

  test('DataLoadState.degraded sets degraded status', () {
    final state = DataLoadState<String>.degraded(
      'partial',
      message: 'fallback',
    );

    expect(state.status, DataStatus.degraded);
    expect(state.data, 'partial');
    expect(state.message, 'fallback');
    expect(state.isDegraded, true);
  });

  test('DataLoadState.error sets error status', () {
    final state = DataLoadState<String>.error('failed', fallbackData: 'cached');

    expect(state.status, DataStatus.error);
    expect(state.data, 'cached');
    expect(state.message, 'failed');
    expect(state.isError, true);
  });
}
