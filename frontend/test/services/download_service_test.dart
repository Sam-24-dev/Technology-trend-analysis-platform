import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/download/download_service.dart';

void main() {
  test('download service uses stub on non-web tests', () async {
    final service = createDownloadService();

    await expectLater(
      service.saveZipBytes(fileName: 'sample', bytes: [1, 2, 3]),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
