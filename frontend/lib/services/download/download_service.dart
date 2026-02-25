import 'download_service_stub.dart'
    if (dart.library.html) 'download_service_web.dart'
    as impl;

abstract class DownloadService {
  Future<void> saveZipBytes({
    required String fileName,
    required List<int> bytes,
  });
}

DownloadService createDownloadService() => impl.createDownloadService();
