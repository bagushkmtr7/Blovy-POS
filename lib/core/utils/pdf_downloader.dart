import 'dart:typed_data';
import 'pdf_downloader_stub.dart'
    if (dart.library.html) 'pdf_downloader_web.dart';

Future<void> unduhAtauCetakPdf({
  required Uint8List bytes,
  required String filename,
}) {
  return simpanPdfPlatform(bytes: bytes, filename: filename);
}
