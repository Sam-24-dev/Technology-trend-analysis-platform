import 'download_service.dart';

class StubDownloadService implements DownloadService {
  @override
  Future<void> saveZipBytes({
    required String fileName,
    required List<int> bytes,
  }) async {
    throw UnsupportedError(
      'La exportacion ZIP no esta disponible para esta plataforma.',
    );
  }
}

DownloadService createDownloadService() => StubDownloadService();
