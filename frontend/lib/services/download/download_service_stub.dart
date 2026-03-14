import 'download_service.dart';

class StubDownloadService implements DownloadService {
  @override
  Future<void> saveZipBytes({
    required String fileName,
    required List<int> bytes,
  }) async {
    throw UnsupportedError(
      'La exportación ZIP no está disponible para esta plataforma.',
    );
  }
}

DownloadService createDownloadService() => StubDownloadService();
