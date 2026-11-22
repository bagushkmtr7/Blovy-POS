import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/clerek_model.dart';
import '../../models/pos_models.dart';
import 'formatters.dart';
import 'pdf_downloader_stub.dart'
    if (dart.library.html) 'pdf_downloader_web.dart'
    if (dart.library.io) 'pdf_downloader_io.dart';

String _formatSelisih(int nilai) {
  if (nilai == 0) return 'Rp 0 (KLOP)';
  final tanda = nilai > 0 ? '+' : '-';
  return '$tanda${formatRupiah(nilai.abs())}';
}

Future<Uint8List> generatePdfLaporanClerek({
  required LaporanClerekShift laporan,
  required PengaturanToko toko,
}) async {
  final doc = pw.Document(title: 'Z-Report Clerek ${laporan.nomorClerek}');
  final fontReg = pw.Font.helvetica();
  final fontBold = pw.Font.helveticaBold();

  final statusKlop =
      laporan.selisihTunai == 0 && laporan.selisihNonTunai == 0;
  final statusKurang =
      laporan.selisihTunai < 0 || laporan.selisihNonTunai < 0;
  final warnaBadge = !laporan.sudahDirekonsiliasi
      ? PdfColors.blueGrey700
      : (statusKlop
          ? PdfColors.green800
          : (statusKurang ? PdfColors.red800 : PdfColors.amber900));

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(26),
      theme: pw.ThemeData.withFont(base: fontReg, bold: fontBold),
      build: (_) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    toko.namaToko.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (toko.alamatToko.isNotEmpty)
                    pw.Text(
                      toko.alamatToko,
                      style: const pw.TextStyle(
                        fontSize: 8.5,
                        color: PdfColors.grey700,
                      ),
                    ),
                ],
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey900,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Z-REPORT CLEREK SETORAN KASIR',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    laporan.nomorClerek,
                    style: pw.TextStyle(
                      fontSize: 10.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.amber200,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1.3, color: PdfColors.blueGrey800),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.all(9),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _barisMeta('Kasir Bertugas', laporan.namaKasir),
                    _barisMeta('Otorisasi Tutup', laporan.namaOtorisasiTutup),
                    _barisMeta('Waktu Tutup Shift', formatTanggalWaktu(laporan.waktuClerek)),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _barisMeta('Petugas SIS', laporan.namaPejabatRekonsiliasi.isEmpty ? '-' : laporan.namaPejabatRekonsiliasi),
                    _barisMeta('Struk / Item', '${laporan.jumlahStrukSukses} struk (${laporan.totalItemTerjual} item)'),
                    _barisMeta('Status Rekonsiliasi', laporan.statusRekonsiliasi),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: warnaBadge,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'NET SETORAN TUNAI KE BRANKAS / HEAD OFFICE',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    'Total Fisik Tunai ${formatRupiah(laporan.totalFisikTunai)} - Modal Ditinggal ${formatRupiah(laporan.modalDitinggalLaci)}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey200,
                    ),
                  ),
                ],
              ),
              pw.Text(
                formatRupiah(laporan.netSetoranBrankas),
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'REKONSILIASI SETORAN FISIK CLEREK (SIS) VS SISTEM POS',
          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        pw.TableHelper.fromTextArray(
          headers: ['Komponen Setoran', 'Sistem POS', 'Input Fisik SIS', 'Selisih'],
          data: [
            ['Modal Awal Laci', formatRupiah(laporan.modalAwalSistem), '-', '-'],
            ['Penjualan Tunai', formatRupiah(laporan.penjualanTunaiSistem), '-', '-'],
            ['Pengeluaran Kas Laci', '-${formatRupiah(laporan.pengeluaranLaciSistem)}', '-', '-'],
            [
              'TOTAL KAS TUNAI LACI',
              formatRupiah(laporan.kasSeharusnyaSistem),
              formatRupiah(laporan.totalFisikTunai),
              _formatSelisih(laporan.selisihTunai),
            ],
            ['Settlement QRIS', '-', formatRupiah(laporan.fisikSettlementQris), '-'],
            ['Settlement EDC / Transfer', '-', formatRupiah(laporan.fisikSettlementEdcTransfer), '-'],
            [
              'TOTAL NON-TUNAI',
              formatRupiah(laporan.penjualanNonTunaiSistem),
              formatRupiah(laporan.totalFisikNonTunai),
              _formatSelisih(laporan.selisihNonTunai),
            ],
            [
              'Nota Kasbon Baru',
              formatRupiah(laporan.kasbonBaruSistem),
              formatRupiah(laporan.fisikNotaKasbon),
              _formatSelisih(laporan.selisihKasbon),
            ],
          ],
          headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          cellStyle: const pw.TextStyle(fontSize: 8.5),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
          cellAlignments: {
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
        ),
        if (laporan.catatanRekonsiliasi.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text('Catatan: ${laporan.catatanRekonsiliasi}', style: const pw.TextStyle(fontSize: 8.5)),
        ],
        pw.SizedBox(height: 22),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _kotakTtd('Kasir Shift', laporan.namaKasir),
            _kotakTtd('Otorisasi Tutup', laporan.namaOtorisasiTutup),
            _kotakTtd('Verifikasi SIS', laporan.namaPejabatRekonsiliasi.isEmpty ? '..........................' : laporan.namaPejabatRekonsiliasi),
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

Future<void> unduhPdfLaporanClerek({
  required LaporanClerekShift laporan,
  required PengaturanToko toko,
}) async {
  final bytes = await generatePdfLaporanClerek(laporan: laporan, toko: toko);
  await simpanPdfPlatform(
    bytes: bytes,
    filename: '${laporan.nomorClerek}.pdf',
  );
}

pw.Widget _barisMeta(String label, String nilai) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2.5),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 92, child: pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700))),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 8)),
          pw.Expanded(child: pw.Text(nilai, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
        ],
      ),
    );

pw.Widget _kotakTtd(String jabatan, String nama) => pw.Container(
      width: 162,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: [
          pw.Text(jabatan, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.SizedBox(height: 34),
          pw.Text('( $nama )', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
