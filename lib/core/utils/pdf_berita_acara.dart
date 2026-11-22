import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'pdf_downloader_stub.dart' if (dart.library.html) 'pdf_downloader_web.dart' if (dart.library.io) 'pdf_downloader_io.dart';
import '../../models/pos_models.dart';
import '../../models/so_models.dart';
import 'formatters.dart';

Future<Uint8List> generatePdfBeritaAcara({
  required SesiStockOpname sesi,
  required bool tampilkanHpp,
  PengaturanToko? toko,
}) async {
  final doc = pw.Document(
    title: 'Berita Acara Stock Opname ${sesi.nomorDokumen}',
    author: sesi.operatorNama,
  );

  final regularData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
  final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
  final fontRegular = pw.Font.ttf(regularData);
  final fontBold = pw.Font.ttf(boldData);

  final mapToko = toko?.toMap() ?? const <String, dynamic>{};
  final namaToko = (toko?.namaToko.isNotEmpty ?? false)
      ? toko!.namaToko.toUpperCase()
      : 'TOKO RITEL POS';
  final rawAlamat = (mapToko['alamatToko'] ??
          mapToko['alamat'] ??
          mapToko['headerStruk'] ??
          '')
      .toString()
      .trim();
  final alamatToko = rawAlamat.isNotEmpty
      ? rawAlamat
      : 'Dokumen Audit Resmi Inventaris Toko & Gudang';
  final rawTelp = (mapToko['noTelp'] ??
          mapToko['noTelepon'] ??
          mapToko['telepon'] ??
          mapToko['kontak'] ??
          '')
      .toString()
      .trim();
  final telpToko = rawTelp.isNotEmpty ? 'Telp: $rawTelp' : '';

  final listSelisih = sesi.items.where((e) => e.adaSelisih).toList();
  final listTerhitung = sesi.items.where((e) => e.sudahDihitung).toList();

  final durasiMenit = (sesi.waktuSelesai ?? DateTime.now())
      .difference(sesi.waktuMulai)
      .inMinutes;
  final teksDurasi = durasiMenit < 1
      ? '< 1 menit'
      : (durasiMenit < 60
          ? '$durasiMenit menit'
          : '${durasiMenit ~/ 60} jam ${durasiMenit % 60} menit');

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      namaToko,
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      alamatToko,
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    if (telpToko.isNotEmpty)
                      pw.Text(
                        telpToko,
                        style: const pw.TextStyle(
                          fontSize: 9,
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
                      'BERITA ACARA STOCK OPNAME',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      sesi.nomorDokumen,
                      style: pw.TextStyle(
                        fontSize: 11,
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
          pw.Divider(color: PdfColors.blueGrey900, thickness: 1.5),
          pw.SizedBox(height: 6),
        ],
      ),
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: PdfColors.grey300, width: 0.7),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Dokumen Sah Hasil Audit Fisik • ${sesi.nomorDokumen}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Halaman ${context.pageNumber} dari ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
      build: (context) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.7),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _barisMetaPdf('Cakupan Audit', sesi.cakupan),
                    _barisMetaPdf('Metode Hitung', '100% Physical Count'),
                    _barisMetaPdf('Operator Hitung', sesi.operatorNama),
                    _barisMetaPdf(
                      'Disahkan Oleh',
                      sesi.approverNama.isNotEmpty
                          ? sesi.approverNama
                          : sesi.operatorNama,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _barisMetaPdf(
                      'Waktu Mulai',
                      formatTanggalWaktu(sesi.waktuMulai),
                    ),
                    _barisMetaPdf(
                      'Waktu Selesai',
                      formatTanggalWaktu(sesi.waktuSelesai ?? sesi.waktuMulai),
                    ),
                    _barisMetaPdf('Durasi Audit', teksDurasi),
                    if (sesi.catatanUmum.isNotEmpty)
                      _barisMetaPdf('Catatan', sesi.catatanUmum),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            _kotakKpiPdf(
              'Akurasi SO',
              '${sesi.persentaseAkurasi.toStringAsFixed(1)}%',
              sesi.persentaseAkurasi >= 95
                  ? PdfColors.green800
                  : PdfColors.amber900,
            ),
            pw.SizedBox(width: 6),
            _kotakKpiPdf(
              'SKU Dihitung',
              '${sesi.jumlahDihitung} / ${sesi.totalSku}',
              PdfColors.blueGrey900,
            ),
            pw.SizedBox(width: 6),
            _kotakKpiPdf(
              'SKU Cocok',
              '${sesi.jumlahCocok} SKU',
              PdfColors.green800,
            ),
            pw.SizedBox(width: 6),
            _kotakKpiPdf(
              'SKU Selisih',
              '${sesi.jumlahSelisih} SKU',
              sesi.jumlahSelisih == 0 ? PdfColors.green800 : PdfColors.red800,
            ),
            pw.SizedBox(width: 6),
            _kotakKpiPdf(
              'Total Fisik',
              '${sesi.totalUnitFisik} unit',
              PdfColors.blueGrey900,
            ),
          ],
        ),
        if (tampilkanHpp) ...[
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              _kotakKpiPdf(
                'Surplus (+) HPP',
                '+${formatRupiah(sesi.totalPlusHpp)}',
                PdfColors.blue800,
              ),
              pw.SizedBox(width: 6),
              _kotakKpiPdf(
                'Shrinkage (-) HPP',
                '-${formatRupiah(sesi.totalMinusHpp)}',
                PdfColors.red800,
              ),
              pw.SizedBox(width: 6),
              _kotakKpiPdf(
                'Net Selisih Aset (HPP)',
                '${sesi.netSelisihHpp >= 0 ? '+' : ''}${formatRupiah(sesi.netSelisihHpp)}',
                sesi.netSelisihHpp >= 0
                    ? PdfColors.green800
                    : PdfColors.red800,
              ),
            ],
          ),
        ],
        pw.SizedBox(height: 14),
        pw.Text(
          listSelisih.isEmpty
              ? '1. HASIL AUDIT SELISIH: 100% COCOK (TIDAK ADA SELISIH STOK)'
              : '1. RINCIAN ITEM BERSELISIH (${listSelisih.length} SKU)',
          style: pw.TextStyle(
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey900,
          ),
        ),
        pw.SizedBox(height: 5),
        if (listSelisih.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColors.green300, width: 0.7),
            ),
            child: pw.Text(
              'Seluruh barang yang dihitung secara fisik di area toko dan gudang sesuai 100% dengan catatan stok sistem.',
              style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.green900),
            ),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: tampilkanHpp
                ? [
                    'No',
                    'SKU',
                    'Nama Produk',
                    'Sistem',
                    'Toko',
                    'Gdg',
                    'Fisik',
                    'Selisih',
                    'Nilai HPP',
                    'Alasan Selisih',
                  ]
                : [
                    'No',
                    'SKU',
                    'Nama Produk',
                    'Sistem',
                    'Toko',
                    'Gdg',
                    'Fisik',
                    'Selisih',
                    'Alasan Selisih',
                  ],
            data: List.generate(listSelisih.length, (i) {
              final item = listSelisih[i];
              final tanda = item.selisihQty > 0 ? '+' : '';
              final alasan =
                  '${item.alasanSelisih}${item.sudahRecount ? ' [Recount]' : ''}';
              if (tampilkanHpp) {
                return [
                  '${i + 1}',
                  item.kodeSku,
                  item.namaProduk,
                  '${item.stokSistem}',
                  '${item.qtyToko ?? 0}',
                  '${item.qtyGudang ?? 0}',
                  '${item.stokFisik ?? 0}',
                  '$tanda${item.selisihQty}',
                  '$tanda${formatRupiah(item.selisihNilaiHpp)}',
                  alasan,
                ];
              }
              return [
                '${i + 1}',
                item.kodeSku,
                item.namaProduk,
                '${item.stokSistem}',
                '${item.qtyToko ?? 0}',
                '${item.qtyGudang ?? 0}',
                '${item.stokFisik ?? 0}',
                '$tanda${item.selisihQty}',
                alasan,
              ];
            }),
            headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey800,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 4,
            ),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
            cellAlignments: {
              0: pw.Alignment.center,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
              if (tampilkanHpp) 8: pw.Alignment.centerRight,
            },
          ),
        pw.SizedBox(height: 14),
        pw.Text(
          '2. LAMPIRAN DAFTAR SELURUH ITEM TERHITUNG (${listTerhitung.length} SKU)',
          style: pw.TextStyle(
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey900,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.TableHelper.fromTextArray(
          headers: [
            'No',
            'SKU',
            'Nama Produk',
            'Kategori',
            'Sistem',
            'Fisik',
            'Selisih',
            'Kondisi',
          ],
          data: List.generate(listTerhitung.length, (i) {
            final item = listTerhitung[i];
            final tanda = item.selisihQty > 0 ? '+' : '';
            return [
              '${i + 1}',
              item.kodeSku,
              item.namaProduk,
              item.kategori,
              '${item.stokSistem}',
              '${item.stokFisik ?? 0}',
              item.selisihQty == 0 ? '0' : '$tanda${item.selisihQty}',
              item.kondisiFisik,
            ];
          }),
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColors.blueGrey700,
          ),
          cellStyle: const pw.TextStyle(fontSize: 7.5),
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 3.5,
          ),
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
          cellAlignments: {
            0: pw.Alignment.center,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
            6: pw.Alignment.centerRight,
          },
        ),
        pw.SizedBox(height: 20),
        pw.Wrap(
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  'Demikian Berita Acara Stock Opname ini dibuat dengan sebenar-benarnya berdasarkan hasil penghitungan fisik di lapangan untuk digunakan sebagai dasar penyesuaian stok sistem.',
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _kotakTandaTanganPdf(
                      jabatan: 'Dibuat Oleh (Operator SO)',
                      nama: sesi.operatorNama,
                    ),
                    _kotakTandaTanganPdf(
                      jabatan: 'Diperiksa & Disahkan Oleh',
                      nama: sesi.approverNama.isNotEmpty
                          ? sesi.approverNama
                          : 'Kepala Toko / Admin',
                    ),
                    _kotakTandaTanganPdf(
                      jabatan: 'Saksi / Mengetahui',
                      nama: '................................',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

Future<void> unduhAtauBagikanPdfBA({
  required SesiStockOpname sesi,
  required bool tampilkanHpp,
  PengaturanToko? toko,
}) async {
  final bytes = await generatePdfBeritaAcara(
    sesi: sesi,
    tampilkanHpp: tampilkanHpp,
    toko: toko,
  );
  await simpanPdfPlatform(
    bytes: bytes,
    filename: 'BA_${sesi.nomorDokumen}.pdf',
  );
}

Future<void> pratinjauCetakPdfBA({
  required SesiStockOpname sesi,
  required bool tampilkanHpp,
  PengaturanToko? toko,
}) async {
  await previewPdfPlatform(
    filename: 'BA_${sesi.nomorDokumen}.pdf',
    buildBytes: () => generatePdfBeritaAcara(
      sesi: sesi,
      tampilkanHpp: tampilkanHpp,
      toko: toko,
    ),
  );
}

pw.Widget _barisMetaPdf(String label, String nilai) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 82,
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
          ),
        ),
        pw.Text(': ', style: const pw.TextStyle(fontSize: 8.5)),
        pw.Expanded(
          child: pw.Text(
            nilai,
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _kotakKpiPdf(String label, String nilai, PdfColor warna) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.7),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            nilai,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: warna,
            ),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _kotakTandaTanganPdf({
  required String jabatan,
  required String nama,
}) {
  return pw.Container(
    width: 160,
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      children: [
        pw.Text(
          jabatan,
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 36),
        pw.Text(
          '( $nama )',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );
}
