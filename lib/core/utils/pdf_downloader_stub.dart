import 'dart:typed_data';
import 'package:printing/printing.dart';

Future<void> simpanPdfPlatform({
  required Uint8List bytes,
  required String filename,
}) async {
  await Printing.sharePdf(bytes: bytes, filename: filename);
}

Future<void> previewPdfPlatform({
  required String filename,
  required Future<Uint8List> Function() buildBytes,
}) async {
  await Printing.layoutPdf(
    name: filename,
    onLayout: (_) => buildBytes(),
  );
}
