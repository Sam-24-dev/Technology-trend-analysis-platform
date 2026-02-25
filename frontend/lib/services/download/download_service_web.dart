import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

import 'download_service.dart';

class WebDownloadService implements DownloadService {
  @override
  Future<void> saveZipBytes({
    required String fileName,
    required List<int> bytes,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError('No se puede descargar un ZIP vacio');
    }

    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'zip',
      mimeType: MimeType.custom,
      customMimeType: 'application/zip',
    );
  }
}

DownloadService createDownloadService() => WebDownloadService();
