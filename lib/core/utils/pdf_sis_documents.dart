import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/pos_models.dart';
import '../../models/sis_models.dart';
import 'formatters.dart';
import 'pdf_downloader_stub.dart'
    if (dart.library.html) 'pdf_downloader_web.dart'
    if (dart.library.io) 'pdf_downloader_io.dart';

String _formatTanggalPendek(DateTime dt) {
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  return '$d/$m/${dt.year}';
}

pw.Widget _kopTokoPdf({
  required PengaturanToko toko,
  required String judulDokumen,
  required String nomorDokumen,
  PdfColor aksenWarna = PdfColors.blueGrey900,
}) {
  final mapToko = toko.toMap();
  final nama = toko.namaToko.isNotEmpty
      ? toko.namaToko.toUpperCase()
      : 'STORE INFORMATION SYSTEM';
  final alamat = (mapToko['alamatToko'] ?? mapToko['alamat'] ?? '').toString();
  final telp = (mapToko['teleponToko'] ?? mapToko['telepon'] ?? '').toString();

  return pw.Column(
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
                  nama,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                ),
                if (alamat.isNotEmpty)
                  pw.Text(
                    alamat,
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColors.grey700,
                    ),
                  ),
                if (telp.isNotEmpty)
                  pw.Text(
                    'Telp: $telp',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColors.grey700,
                    ),
                  ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: aksenWarna,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  judulDokumen,
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  nomorDokumen,
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
      pw.Divider(color: aksenWarna, thickness: 1.4),
      pw.SizedBox(height: 6),
    ],
  );
}

// ==================== 1. PDF PURCHASE ORDER ====================

Future<Uint8List> generatePdfPurchaseOrder({
  required PurchaseOrderSis po,
  required PengaturanToko toko,
}) async {
  final doc = pw.Document(title: 'Purchase Order ${po.nomorPo}');
  final fontReg = pw.Font.helvetica();
  final fontBold = pw.Font.helveticaBold();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      theme: pw.ThemeData.withFont(base: fontReg, bold: fontBold),
      header: (_) => _kopTokoPdf(
        toko: toko,
        judulDokumen: 'PURCHASE ORDER (SURAT PESANAN)',
        nomorDokumen: po.nomorPo,
      ),
      build: (_) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.7),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _metaRow('Kepada Supplier', po.namaSupplier),
                    _metaRow('Status Dokumen', po.status.toUpperCase()),
                    _metaRow('Dibuat Oleh', po.dibuatOleh),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _metaRow('Tanggal Order', formatTanggalWaktu(po.tanggalOrder)),
                    _metaRow('Estimasi Tiba', _formatTanggalPendek(po.estimasiTiba)),
                    if (po.catatan.isNotEmpty) _metaRow('Catatan PO', po.catatan),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: [
            'No',
            'SKU / Barcode',
            'Nama Produk',
            'Stok Toko',
            'Qty Order',
            'Satuan',
            'Harga Beli',
            'Subtotal',
          ],
          data: List.generate(po.items.length, (i) {
            final item = po.items[i];
            return [
              '${i + 1}',
              item.kodeSku,
              item.namaProduk,
              '${item.stokSaatOrder}',
              '${item.qtyOrder}',
              item.satuan,
              formatRupiah(item.hargaBeliSatuan),
              formatRupiah(item.subtotal),
            ];
          }),
          headerStyle: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          cellStyle: const pw.TextStyle(fontSize: 8.5),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4.5),
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
          cellAlignments: {
            0: pw.Alignment.center,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.center,
            6: pw.Alignment.centerRight,
            7: pw.Alignment.centerRight,
          },
        ),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            width: 230,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey50,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColors.blueGrey200),
            ),
            child: pw.Column(
              children: [
                _metaRow('Total Item SKU', '${po.items.length} SKU'),
                _metaRow('Total Kuantitas', '${po.totalQty} unit'),
                _metaRow('Estimasi Total PO', formatRupiah(po.totalNilaiHpp)),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 24),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _ttdBox('Purchasing / Merchandising', po.dibuatOleh),
            _ttdBox('Kepala Toko / Menyetujui', '................................'),
            _ttdBox('Konfirmasi Supplier', po.namaSupplier),
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

Future<void> unduhPdfPurchaseOrder({
  required PurchaseOrderSis po,
  required PengaturanToko toko,
}) async {
  final bytes = await generatePdfPurchaseOrder(po: po, toko: toko);
  await simpanPdfPlatform(bytes: bytes, filename: '${po.nomorPo}.pdf');
}

// ==================== 2. PDF RETUR / BAD STOCK ====================

Future<Uint8List> generatePdfBadStock({
  required DokumenBadStock dok,
  required PengaturanToko toko,
}) async {
  final isRetur = dok.jenis == 'Retur Supplier';
  final doc = pw.Document(title: '${dok.jenis} ${dok.nomorDokumen}');
  final fontReg = pw.Font.helvetica();
  final fontBold = pw.Font.helveticaBold();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      theme: pw.ThemeData.withFont(base: fontReg, bold: fontBold),
      header: (_) => _kopTokoPdf(
        toko: toko,
        judulDokumen: isRetur
            ? 'NOTA RETUR BARANG KE SUPPLIER'
            : 'BERITA ACARA PEMUSNAHAN BAD STOCK',
        nomorDokumen: dok.nomorDokumen,
        aksenWarna: isRetur ? PdfColors.amber900 : PdfColors.red900,
      ),
      build: (_) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.7),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _metaRow('Jenis Dokumen', dok.jenis),
                    if (dok.namaSupplier.isNotEmpty)
                      _metaRow('Supplier Tujuan', dok.namaSupplier),
                    _metaRow('Alasan Utama', dok.alasanUtama),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _metaRow('Tanggal', formatTanggalWaktu(dok.tanggal)),
                    _metaRow('Operator SIS', dok.operatorNama),
                    if (dok.catatan.isNotEmpty) _metaRow('Catatan', dok.catatan),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: [
            'No',
            'SKU',
            'Nama Produk',
            'Kondisi',
            'Qty',
            'Satuan',
            'HPP Satuan',
            'Total Nilai HPP',
          ],
          data: List.generate(dok.items.length, (i) {
            final item = dok.items[i];
            return [
              '${i + 1}',
              item.kodeSku,
              item.namaProduk,
              item.kondisi,
              '${item.qty}',
              item.satuan,
              formatRupiah(item.hargaModalSatuan),
              formatRupiah(item.totalNilaiHpp),
            ];
          }),
          headerStyle: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(
            color: isRetur ? PdfColors.amber900 : PdfColors.red900,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8.5),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4.5),
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
          cellAlignments: {
            0: pw.Alignment.center,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.center,
            6: pw.Alignment.centerRight,
            7: pw.Alignment.centerRight,
          },
        ),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            width: 240,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.red50,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColors.red200),
            ),
            child: pw.Column(
              children: [
                _metaRow('Total Kuantitas', '${dok.totalUnit} unit'),
                _metaRow(
                  isRetur ? 'Total Klaim Retur (HPP)' : 'Total Kerugian (HPP)',
                  formatRupiah(dok.totalKerugianHpp),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 18),
        pw.Text(
          isRetur
              ? 'Barang tersebut di atas telah dikembalikan kepada pihak supplier dan stok sistem toko telah disesuaikan.'
              : 'Barang rusak/kedaluwarsa tersebut di atas telah dimusnahkan secara fisik sehingga tidak dapat dijual kembali dan stok sistem telah disesuaikan.',
          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 18),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _ttdBox('Dibuat Oleh (SIS)', dok.operatorNama),
            _ttdBox('Menyetujui (Kepala Toko)', '................................'),
            _ttdBox(
              isRetur ? 'Penerima (Driver/Supplier)' : 'Saksi Pemusnahan',
              '................................',
            ),
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

Future<void> unduhPdfBadStock({
  required DokumenBadStock dok,
  required PengaturanToko toko,
}) async {
  final bytes = await generatePdfBadStock(dok: dok, toko: toko);
  await simpanPdfPlatform(bytes: bytes, filename: '${dok.nomorDokumen}.pdf');
}

// ==================== 3. PDF LABEL HARGA RAK & BARCODE ====================

Future<Uint8List> generatePdfLabelHargaRak({
  required List<Produk> daftarProduk,
  required PengaturanToko toko,
}) async {
  final doc = pw.Document(title: 'Label Harga Rak & Barcode');
  final fontReg = pw.Font.helvetica();
  final fontBold = pw.Font.helveticaBold();
  final tglCetak = _formatTanggalPendek(DateTime.now());

  // 24 label per halaman A4 (3 kolom x 8 baris)
  const perHalaman = 24;
  final totalHalaman = (daftarProduk.length / perHalaman).ceil().clamp(1, 999);

  for (int h = 0; h < totalHalaman; h++) {
    final slice = daftarProduk.skip(h * perHalaman).take(perHalaman).toList();
    final rows = <pw.TableRow>[];

    for (int r = 0; r < 8; r++) {
      final cells = <pw.Widget>[];
      for (int c = 0; c < 3; c++) {
        final idx = r * 3 + c;
        if (idx >= slice.length) {
          cells.add(pw.Container(height: 92));
          continue;
        }
        final p = slice[idx];
        final skuAman = p.kodeSku.trim().isEmpty ? p.id : p.kodeSku.trim();

        cells.add(
          pw.Container(
            height: 92,
            margin: const pw.EdgeInsets.all(2.5),
            padding: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.9),
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Container(
                  color: PdfColors.amber300,
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: pw.Text(
                    p.nama.toUpperCase(),
                    maxLines: 2,
                    overflow: pw.TextOverflow.clip,
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                ),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Rp',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      formatRupiah(p.hargaJual).replaceFirst('Rp ', ''),
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '/${p.satuan}',
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                  ],
                ),
                if (p.hargaGrosir > 0 && p.minQtyGrosir > 0)
                  pw.Text(
                    'Grosir >=${p.minQtyGrosir}: ${formatRupiah(p.hargaGrosir)}',
                    style: pw.TextStyle(
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red900,
                    ),
                  ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.SizedBox(
                            height: 15,
                            width: 95,
                            child: pw.BarcodeWidget(
                              barcode: pw.Barcode.code128(),
                              data: skuAman,
                              drawText: false,
                            ),
                          ),
                          pw.Text(
                            skuAman,
                            style: const pw.TextStyle(fontSize: 6.5),
                          ),
                        ],
                      ),
                    ),
                    pw.Text(
                      tglCetak,
                      style: const pw.TextStyle(
                        fontSize: 6,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
      rows.add(pw.TableRow(children: cells));
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(14),
        theme: pw.ThemeData.withFont(base: fontReg, bold: fontBold),
        build: (_) => pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(1),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(1),
          },
          children: rows,
        ),
      ),
    );
  }

  return doc.save();
}

Future<void> unduhPdfLabelHargaRak({
  required List<Produk> daftarProduk,
  required PengaturanToko toko,
}) async {
  final bytes = await generatePdfLabelHargaRak(
    daftarProduk: daftarProduk,
    toko: toko,
  );
  final now = DateTime.now();
  final stamp =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  await simpanPdfPlatform(
    bytes: bytes,
    filename: 'LABEL_HARGA_$stamp.pdf',
  );
}

pw.Widget _metaRow(String label, String nilai) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 95,
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

pw.Widget _ttdBox(String jabatan, String nama) {
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
