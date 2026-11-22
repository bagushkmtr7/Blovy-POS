import 'dart:async';
import 'dart:typed_data';
import 'package:printing/printing.dart';

Future<void> simpanPdfPlatform({
  required Uint8List bytes,
  required String filename,
}) async {
  try {
    await Printing.sharePdf(bytes: bytes, filename: filename)
        .timeout(const Duration(seconds: 25));
  } on TimeoutException {
    // Share sheet Android terkadang tidak menyelesaikan future setelah dibuka
  }
}

Future<void> previewPdfPlatform({
  required Future<Uint8List> Function() buildBytes,
  required String filename,
}) async {
  final bytes = await buildBytes().timeout(const Duration(seconds: 25));
  try {
    await Printing.layoutPdf(
      name: filename,
      onLayout: (_) async => bytes,
    ).timeout(const Duration(seconds: 25));
  } on TimeoutException {
    // Cegah spinner loading berputar selamanya jika spooler Android tidak merespons
  }
}
