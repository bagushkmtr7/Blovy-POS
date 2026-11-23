import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../widgets/pos_components.dart';

String _fmtTglSingkat(DateTime? dt) {
  if (dt == null) return '-';
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final y = dt.year.toString();
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$d/$m/$y $hh:$mm';
}

String _fmtRupiahPdf(int angka) {
  final neg = angka < 0 ? '-' : '';
  final s = angka.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${neg}Rp${buf.toString()}';
}

Future<Uint8List> generateKksoBeritaAcaraPdf(
  KksoDocument doc,
  PengaturanToko toko,
) async {
  final pdf = pw.Document();
  final selisihList = doc.itemsSelisih;
  final jenisLabel = doc.jenis == KksoJenis.grand
      ? 'GRAND - ${doc.areaLabel}'
      : 'PARTIAL - ${doc.areaLabel}';
  final tglAcuan = doc.tanggalPosted ?? doc.tanggalDibuat;
  final verifyUrl = 'https://blovy.my/verify/${doc.id}';

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      footer: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Verifikasi: $verifyUrl',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Dokumen digenerate otomatis oleh Blovy POS dan tercatat di Log Mutasi. Tidak ada foto bukti sesuai kebijakan toko.',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: verifyUrl,
                width: 48,
                height: 48,
              ),
            ],
          ),
        ],
      ),
      build: (ctx) => [
        // Kop Berita Acara
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.green900, width: 1.2),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'NUSANTARA RETAIL POS - BERITA ACARA STOCK OPNAME',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green900,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '${toko.namaToko} • ${toko.alamatToko}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.Divider(color: PdfColors.grey300),
              pw.Wrap(
                spacing: 18,
                runSpacing: 6,
                children: [
                  pw.Text('No: ${doc.id}', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Jenis: $jenisLabel', style: const pw.TextStyle(fontSize: 9.5)),
                  pw.Text('Tanggal: ${_fmtTglSingkat(tglAcuan)}', style: const pw.TextStyle(fontSize: 9.5)),
                  pw.Text('Status: ${doc.status.name.toUpperCase()}', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Petugas Hitung: ${doc.petugasHitung}', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('Disetujui Oleh: ${doc.disetujuiOleh ?? "-"}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),

        // Tabel Khusus Item Berselisih
        pw.Text(
          'Rincian Item Berselisih (${selisihList.length} SKU)',
          style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.4),
            1: const pw.FlexColumnWidth(1.2),
            2: const pw.FlexColumnWidth(0.9),
            3: const pw.FlexColumnWidth(0.9),
            4: const pw.FlexColumnWidth(0.9),
            5: const pw.FlexColumnWidth(1.2),
            6: const pw.FlexColumnWidth(1.4),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.green50),
              children: [
                for (final h in ['Produk', 'SKU', 'Sistem', 'Fisik', 'Selisih', 'HPP', 'Kerugian HPP'])
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
              ],
            ),
            if (selisihList.isEmpty)
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Seluruh item sesuai (0 selisih)', style: const pw.TextStyle(fontSize: 8.5)),
                  ),
                  for (int k = 0; k < 6; k++)
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('-', style: const pw.TextStyle(fontSize: 8.5))),
                ],
              )
            else
              for (final it in selisihList)
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(it.namaProduk, style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(it.kodeSku, style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${it.stokSistem}', style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${it.fisikFinal}', style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        it.selisih > 0 ? '+${it.selisih}' : '${it.selisih}',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: it.selisih < 0 ? PdfColors.red800 : PdfColors.green800,
                        ),
                      ),
                    ),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(_fmtRupiahPdf(it.hargaModal), style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        it.selisih < 0 ? _fmtRupiahPdf(it.nilaiSelisihHpp.abs()) : 'Rp0',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: it.selisih < 0 ? PdfColors.red800 : PdfColors.grey700,
                        ),
                      ),
                    ),
                  ],
                ),
          ],
        ),
        pw.SizedBox(height: 8),

        // Ringkasan Total
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total Selisih: ${doc.totalSelisihItem > 0 ? "+${doc.totalSelisihItem}" : "${doc.totalSelisihItem}"} Item',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Kerugian HPP: ${_fmtRupiahPdf(doc.totalKerugianHpp)}',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red800),
              ),
              pw.Text(
                'Kerugian Jual: ${_fmtRupiahPdf(doc.itemsSelisih.where((e) => e.selisih < 0).fold<int>(0, (s, e) => s + e.nilaiSelisihJual.abs()))}',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),

        // Persetujuan & Metode
        pw.Text('Persetujuan & Metode', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Alasan: ${doc.alasan ?? "-"}', style: const pw.TextStyle(fontSize: 9)),
        pw.Text('Catatan: ${(doc.catatan ?? "").trim().isEmpty ? "-" : doc.catatan!.trim()}', style: const pw.TextStyle(fontSize: 9)),
        pw.Text('Metode: Blind Count Wajib', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 14),

        // Tanda Tangan Digital 3 Kolom
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Dihitung oleh', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 18),
                  pw.Text(doc.petugasHitung, style: const pw.TextStyle(fontSize: 8.5)),
                  pw.Text('Time: ${_fmtTglSingkat(doc.tanggalSelesaiHitung ?? doc.tanggalDibuat)}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Dihitung ulang', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 18),
                  pw.Text(
                    doc.petugasDoubleCount ?? (doc.wajibDoubleCount ? 'Wajib Petugas ke-2' : 'Tidak Diperlukan'),
                    style: const pw.TextStyle(fontSize: 8.5),
                  ),
                  pw.Text(
                    doc.wajibDoubleCount ? 'Verifikasi Ganda (>Rp50rb / Grand)' : 'Selisih <= Rp50.000',
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Disetujui Pemilik', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 18),
                  pw.Text(doc.disetujuiOleh ?? 'Owner / SIS', style: const pw.TextStyle(fontSize: 8.5)),
                  pw.Text(
                    doc.pinSisTerverifikasi ? 'PIN SIS Terverifikasi' : 'Belum Terverifikasi',
                    style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );

  return pdf.save();
}

void _noopKksoInv(List<KksoDocument> _) {}

class SisInventorySoView extends StatefulWidget {
  final AppThemeConfig tema;
  final PengaturanToko? toko;
  final AkunStaff? currentStaff;
  final List<AkunStaff> daftarStaff;
  final List<Produk> daftarProduk;
  final List<LogStok> daftarLogStok;
  final List<KksoDocument> daftarKkso;
  final ValueChanged<List<KksoDocument>> onSimpanKkso;
  final void Function(Produk produk, bool isBaru) onSimpanProduk;
  final void Function(String produkId) onHapusProduk;
  final void Function({
    required Produk produk,
    required String tipe,
    required int perubahan,
    required String keterangan,
  }) onMutasiStok;

  const SisInventorySoView({
    super.key,
    required this.tema,
    this.toko,
    this.currentStaff,
    this.daftarStaff = const [],
    required this.daftarProduk,
    required this.daftarLogStok,
    this.daftarKkso = const [],
    this.onSimpanKkso = _noopKksoInv,
    required this.onSimpanProduk,
    required this.onHapusProduk,
    required this.onMutasiStok,
  });

  @override
  State<SisInventorySoView> createState() => _SisInventorySoViewState();
}

class _SisInventorySoViewState extends State<SisInventorySoView>
    with TickerProviderStateMixin {
  static const Color _kSoGreen = Color(0xFF0E5A3E);
  static const Color _kSoGreenSoft = Color(0xFFE8F3EE);

  KksoDocument? _aktifKkso;
  final TextEditingController _barcodeKksoCtrl = TextEditingController();
  final FocusNode _barcodeKksoFocus = FocusNode();
  final Map<String, int?> _draftFisikKkso = {};
  final Map<String, TextEditingController> _fastEntryCtrlMap = {};
  final Map<String, FocusNode> _fastEntryFocusMap = {};

  final List<String> _daftarAlasanKkso = const [
    'Hilang',
    'Rusak',
    'Expired',
    'Salah Input',
    'Pencurian',
  ];
  String _alasanTerpilihKkso = 'Hilang';
  final TextEditingController _catatanReviewKksoCtrl = TextEditingController();
  final TextEditingController _petugasDoubleCountCtrl = TextEditingController();
  final Map<String, int> _doubleCountMap = {};

  bool get _isOwnerOrSis {
    final st = widget.currentStaff;
    if (st == null) return true;
    final r = st.role.name.toLowerCase();
    return st.isStoreSystem ||
        r.contains('owner') ||
        r.contains('admin') ||
        r.contains('super');
  }

  String _buatNomorKkso() {
    final now = DateTime.now();
    final yy = (now.year % 100).toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final rnd = (now.millisecondsSinceEpoch % 900 + 100).toString();
    return 'KKSO-$yy$mm$dd-$rnd';
  }

  List<KksoItem> _produkKeKksoItems(List<Produk> list, String rakDefault) {
    return list.map((p) {
      final rak = p.kategori.trim().isEmpty ? rakDefault : 'Rak ${p.kategori.trim()}';
      return KksoItem(
        produkId: p.id,
        namaProduk: p.nama,
        kodeSku: p.kodeSku,
        barcode: p.kodeSku,
        kategori: p.kategori,
        satuan: p.satuan,
        lokasiRak: rak,
        stokSistem: p.stok,
        hargaModal: p.hargaModal,
        hargaJual: p.hargaJual,
        sudahDihitung: false,
      );
    }).toList();
  }

  void _bersihkanFastEntryControllers() {
    for (final c in _fastEntryCtrlMap.values) {
      c.dispose();
    }
    for (final f in _fastEntryFocusMap.values) {
      f.dispose();
    }
    _fastEntryCtrlMap.clear();
    _fastEntryFocusMap.clear();
  }

  TextEditingController _ctrlFastEntry(String produkId, int? initialQty) {
    return _fastEntryCtrlMap.putIfAbsent(
      produkId,
      () => TextEditingController(text: initialQty != null ? '$initialQty' : ''),
    );
  }

  FocusNode _focusFastEntry(String produkId) {
    return _fastEntryFocusMap.putIfAbsent(produkId, () {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) {
          final c = _fastEntryCtrlMap[produkId];
          if (c != null && c.text.isNotEmpty) {
            c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
          }
        }
      });
      return node;
    });
  }

  void _mulaiSesiKkso({
    required KksoJenis jenis,
    required String subJenis,
    required String areaLabel,
    required List<Produk> targetProduk,
  }) {
    final items = _produkKeKksoItems(targetProduk, areaLabel);
    final doc = KksoDocument(
      id: _buatNomorKkso(),
      jenis: jenis,
      subJenis: subJenis,
      areaLabel: areaLabel,
      status: KksoStatus.hitung,
      petugasHitung: widget.currentStaff?.nama ?? 'Petugas Toko',
      freezePenjualan: jenis == KksoJenis.grand,
      tanggalDibuat: DateTime.now(),
      items: items,
    );
    _bersihkanFastEntryControllers();
    setState(() {
      _aktifKkso = doc;
      _barcodeKksoCtrl.clear();
      _draftFisikKkso.clear();
      for (final it in items) {
        _draftFisikKkso[it.produkId] = null;
        _ctrlFastEntry(it.produkId, null);
        _focusFastEntry(it.produkId);
      }
    });
  }

  void _bukaPemilihanPartial(String modePartial) {
    if (widget.daftarProduk.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada produk untuk di-opname.')),
      );
      return;
    }

    if (modePartial == 'Quick 5 SKU Risiko Tinggi') {
      final sorted = List<Produk>.from(widget.daftarProduk)
        ..sort((a, b) {
          final skorA = a.stok - a.minStokAlert;
          final skorB = b.stok - b.minStokAlert;
          if (skorA != skorB) return skorA.compareTo(skorB);
          return b.hargaModal.compareTo(a.hargaModal);
        });
      final limaSku = sorted.take(5).toList();
      _mulaiSesiKkso(
        jenis: KksoJenis.partial,
        subJenis: 'Quick 5 SKU Risiko Tinggi',
        areaLabel: '5 SKU Rawan • ${limaSku.length} SKU',
        targetProduk: limaSku,
      );
      return;
    }

    final opsi = modePartial == 'Per Kategori'
        ? (<String>{
            for (final p in widget.daftarProduk)
              if (p.kategori.trim().isNotEmpty) p.kategori.trim(),
          }.toList())
        : (<String>{
            for (final p in widget.daftarProduk)
              p.kategori.trim().isEmpty
                  ? 'Rak Display 01'
                  : 'Rak ${p.kategori.trim()}',
          }.toList());

    if (opsi.isEmpty) opsi.add('Rak Display 01');
    String terpilih = opsi.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Partial Opname • $modePartial',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _kSoGreen),
          ),
          content: DropdownButtonFormField<String>(
            value: terpilih,
            decoration: InputDecoration(
              labelText: modePartial == 'Per Kategori' ? 'Pilih Kategori' : 'Pilih Rak / Area',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: [
              for (final o in opsi)
                DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13))),
            ],
            onChanged: (v) {
              if (v != null) setDlg(() => terpilih = v);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kSoGreen, foregroundColor: Colors.white),
              onPressed: () {
                final filtered = modePartial == 'Per Kategori'
                    ? widget.daftarProduk.where((p) => p.kategori.trim() == terpilih).toList()
                    : widget.daftarProduk.where((p) {
                        final rak = p.kategori.trim().isEmpty
                            ? 'Rak Display 01'
                            : 'Rak ${p.kategori.trim()}';
                        return rak == terpilih;
                      }).toList();
                Navigator.pop(ctx);
                final subKat = filtered.isNotEmpty && filtered.first.kategori.trim().isNotEmpty
                    ? filtered.first.kategori.trim()
                    : terpilih;
                _mulaiSesiKkso(
                  jenis: KksoJenis.partial,
                  subJenis: modePartial,
                  areaLabel: '$terpilih • $subKat • ${filtered.length} SKU',
                  targetProduk: filtered,
                );
              },
              child: const Text('Mulai Hitung', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  int? _ambilFisikQty(KksoItem it) {
    if (_draftFisikKkso.containsKey(it.produkId)) {
      return _draftFisikKkso[it.produkId];
    }
    return it.sudahDihitung ? it.stokFisik : null;
  }

  void _setQtyManualKkso(String produkId, int? nilai, {bool syncController = true}) {
    setState(() {
      _draftFisikKkso[produkId] = nilai;
      if (syncController) {
        final ctrl = _ctrlFastEntry(produkId, nilai);
        final teksBaru = nilai != null ? '$nilai' : '';
        if (ctrl.text != teksBaru) {
          ctrl.value = TextEditingValue(
            text: teksBaru,
            selection: TextSelection.collapsed(offset: teksBaru.length),
          );
        }
      }
    });
  }

  void _ubahQtyStepperKkso(KksoItem it, int delta) {
    final cur = _ambilFisikQty(it) ?? 0;
    final next = (cur + delta) < 0 ? 0 : (cur + delta);
    _setQtyManualKkso(it.produkId, next);
  }

  void _fokusKeBarcodeKkso(String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    final doc = _aktifKkso;
    if (q.isEmpty || doc == null) return;
    final idx = doc.items.indexWhere(
      (it) =>
          it.kodeSku.toLowerCase() == q ||
          it.barcode.toLowerCase() == q ||
          it.namaProduk.toLowerCase().contains(q),
    );
    if (idx == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Barcode/SKU "$rawQuery" tidak ditemukan di sesi ini.')),
      );
      return;
    }
    final target = doc.items[idx];
    final node = _focusFastEntry(target.produkId);
    final ctrl = _ctrlFastEntry(target.produkId, _ambilFisikQty(target));
    _barcodeKksoCtrl.clear();
    FocusScope.of(context).requestFocus(node);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ctrl.text.isNotEmpty) {
        ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fokus input: ${target.namaProduk} (${target.kodeSku})'),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _simpanProgresHitungKkso({required bool ajukanReview}) {
    final doc = _aktifKkso;
    if (doc == null) return;
    final updatedItems = doc.items.map((it) {
      final fisik = _ambilFisikQty(it);
      final sudah = fisik != null;
      return it.copyWith(
        stokFisik: fisik,
        clearStokFisik: !sudah,
        sudahDihitung: sudah,
      );
    }).toList();

    final semuaSelesai = updatedItems.every((e) => e.stokFisik != null && e.sudahDihitung);
    if (ajukanReview && !semuaSelesai) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi seluruh jumlah fisik produk (termasuk 0 jika kosong) sebelum Minta Review.')),
      );
      return;
    }

    final nextDoc = doc.copyWith(
      items: updatedItems,
      status: ajukanReview ? KksoStatus.review : KksoStatus.hitung,
      tanggalSelesaiHitung: ajukanReview ? DateTime.now() : doc.tanggalSelesaiHitung,
    );

    setState(() {
      _aktifKkso = nextDoc;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ajukanReview
              ? '${nextDoc.id} diajukan ke Review Owner.'
              : 'Progres ${nextDoc.totalTerhitung}/${nextDoc.totalSku} SKU tersimpan.',
        ),
      ),
    );
  }

  Widget _buildKksoPilihanAwal(AppThemeConfig t) {
    final totalSemuaSku = widget.daftarProduk.length;
    final grandCountLabel = totalSemuaSku > 0 ? '$totalSemuaSku SKU' : '120 SKU';
    final now = DateTime.now();
    final jamLabel =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return ListView(
      key: const ValueKey('kkso_pilih_jenis'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kSoGreen,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(32),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.visibility_off_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mode Blind Count Aktif',
                      style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Stok sistem disembunyikan • Petugas hanya mencatat hitungan fisik',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'KKSO / ${now.year} / ${_buatNomorKkso().split("-").last}',
              style: gayaAngka(const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _kSoGreen)),
            ),
            Text(
              'Progres 0/0 • Dimulai hari ini $jamLabel',
              style: TextStyle(fontSize: 11, color: t.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Pilih Jenis Stock Opname',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _kSoGreen),
        ),
        const Text(
          'Pilih mode untuk memulai. Semua penghitungan bersifat blind count.',
          style: TextStyle(fontSize: 11.5, color: Colors.black54),
        ),
        const SizedBox(height: 10),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _kSoGreen, width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _mulaiSesiKkso(
              jenis: KksoJenis.grand,
              subJenis: 'Full Inventory',
              areaLabel: 'Semua Area Toko • $grandCountLabel',
              targetProduk: widget.daftarProduk,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _kSoGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'GRAND OPNAME',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _kSoGreen),
                            ),
                            Text(
                              'Full inventory • $grandCountLabel • Estimasi 45 menit',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: _kSoGreen, size: 26),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: _kSoGreenSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Semua area toko • Wajib verifikasi ganda • Freeze penjualan',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kSoGreen),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kSoGreen.withAlpha(110)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kSoGreenSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.layers_rounded, color: _kSoGreen, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PARTIAL OPNAME',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _kSoGreen),
                        ),
                        Text(
                          'Pilih area tertentu untuk dihitung',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kSoGreen,
                        side: const BorderSide(color: _kSoGreen),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _bukaPemilihanPartial('Per Rak'),
                      icon: const Icon(Icons.shelves, size: 16),
                      label: const Text('Per Rak', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kSoGreen,
                        side: const BorderSide(color: _kSoGreen),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _bukaPemilihanPartial('Per Kategori'),
                      icon: const Icon(Icons.folder_copy_rounded, size: 16),
                      label: const Text('Per Kategori', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB45309),
                    side: const BorderSide(color: Color(0xFFD97706)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _bukaPemilihanPartial('Quick 5 SKU Risiko Tinggi'),
                  icon: const Icon(Icons.warning_amber_rounded, size: 17),
                  label: const Text(
                    'Quick 5 SKU Risiko Tinggi',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _kSoGreenSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Tips: Gunakan Partial untuk area cepat atau SKU risiko tinggi • Tanpa foto bukti.',
            style: TextStyle(fontSize: 11, color: _kSoGreen, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildKksoHitungBorongan(AppThemeConfig t, KksoDocument doc) {
    final total = doc.items.length;
    final hitungSekarang = doc.items.where((e) => _ambilFisikQty(e) != null).length;
    final progres = total == 0 ? 0.0 : (hitungSekarang / total).clamp(0.0, 1.0);
    final semuaSelesai = total > 0 && hitungSekarang >= total;

    // Urutkan otomatis: fisik_qty == null (belum dihitung) di atas, yang sudah diisi (termasuk 0) pindah ke bawah
    final indexed = doc.items.asMap().entries.toList();
    indexed.sort((a, b) {
      final aDone = _ambilFisikQty(a.value) != null;
      final bDone = _ambilFisikQty(b.value) != null;
      if (aDone != bDone) return aDone ? 1 : -1;
      return a.key.compareTo(b.key);
    });
    final sortedItems = [for (final e in indexed) e.value];

    return Column(
      key: const ValueKey('kkso_hitung_borongan'),
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _aktifKkso = null),
                    icon: const Icon(Icons.arrow_back_rounded, color: _kSoGreen),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.jenis == KksoJenis.grand ? 'GRAND OPNAME' : 'PARTIAL OPNAME',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _kSoGreen),
                        ),
                        Text(
                          doc.areaLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$hitungSekarang/$total',
                    style: gayaAngka(const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _kSoGreen)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progres,
                  minHeight: 7,
                  backgroundColor: _kSoGreenSoft,
                  valueColor: const AlwaysStoppedAnimation(_kSoGreen),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kSoGreen.withAlpha(80)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: _kSoGreen, size: 17),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Blind Count — Stok sistem disembunyikan untuk akurasi',
                            style: TextStyle(color: _kSoGreen, fontSize: 11.5, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Hitung fisik tanpa melihat stok sistem. Hasil akan divalidasi setelah simpan.',
                            style: TextStyle(color: Colors.black87, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _barcodeKksoCtrl,
                focusNode: _barcodeKksoFocus,
                onSubmitted: _fokusKeBarcodeKkso,
                decoration: InputDecoration(
                  hintText: 'Scan atau ketik barcode...',
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF6F8F7),
                  prefixIcon: const Icon(Icons.qr_code_scanner_rounded, color: _kSoGreen),
                  suffixIcon: IconButton(
                    tooltip: 'Cari & Fokus Produk',
                    onPressed: () => _fokusKeBarcodeKkso(_barcodeKksoCtrl.text),
                    icon: const Icon(Icons.barcode_reader, color: _kSoGreen),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _kSoGreen.withAlpha(110)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _kSoGreen.withAlpha(110)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'DAFTAR PRODUK ($total) — INPUT MANUAL',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, color: _kSoGreen, size: 16),
                        SizedBox(width: 2),
                        Text(
                          'Fast Entry',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _kSoGreen),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                  itemCount: sortedItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final it = sortedItems[idx];
                    final fisikQty = _ambilFisikQty(it);
                    final sudahDihitung = fisikQty != null;
                    final ctrl = _ctrlFastEntry(it.produkId, fisikQty);
                    final focusNode = _focusFastEntry(it.produkId);
                    final isLast = idx == sortedItems.length - 1;
                    final nextFocus = !isLast ? _focusFastEntry(sortedItems[idx + 1].produkId) : null;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: sudahDihitung ? const Color(0xFFE8F5E9) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: sudahDihitung ? _kSoGreen : Colors.grey.shade400,
                          width: sudahDihitung ? 1.6 : 1.1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: sudahDihitung ? Colors.white : const Color(0xFFF3F6F4),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.black12),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.inventory_2_rounded, color: _kSoGreen, size: 22),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      it.namaProduk,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'SKU: ${it.kodeSku}${it.kategori.isNotEmpty ? " • ${it.kategori}" : ""}',
                                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Stok Sistem: -----',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kSoGreen),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                sudahDihitung
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: sudahDihitung ? _kSoGreen : Colors.grey.shade400,
                                size: 24,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              // Tombol 0 cepat untuk rak kosong
                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _setQtyManualKkso(it.produkId, 0),
                                child: Container(
                                  height: 56,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: fisikQty == 0 ? _kSoGreen : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _kSoGreen, width: 1.3),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '0',
                                    style: gayaAngka(
                                      TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: fisikQty == 0 ? Colors.white : _kSoGreen,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Komponen unified: [-] [TextField angka besar >= 56px] [+]
                              Expanded(
                                child: Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _kSoGreen, width: 1.5),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Row(
                                    children: [
                                      InkWell(
                                        onTap: () => _ubahQtyStepperKkso(it, -1),
                                        onLongPress: () => _setQtyManualKkso(it.produkId, 0),
                                        child: Container(
                                          width: 54,
                                          height: 56,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            border: Border(
                                              right: BorderSide(color: _kSoGreen.withAlpha(70)),
                                            ),
                                          ),
                                          child: const Icon(Icons.remove_rounded, color: _kSoGreen, size: 24),
                                        ),
                                      ),
                                      Expanded(
                                        child: TextField(
                                          controller: ctrl,
                                          focusNode: focusNode,
                                          keyboardType: TextInputType.number,
                                          textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
                                          textAlign: TextAlign.center,
                                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                          style: gayaAngka(
                                            const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900,
                                              color: _kSoGreen,
                                            ),
                                          ),
                                          onTap: () {
                                            if (ctrl.text.isNotEmpty) {
                                              ctrl.selection = TextSelection(
                                                baseOffset: 0,
                                                extentOffset: ctrl.text.length,
                                              );
                                            }
                                          },
                                          onChanged: (val) {
                                            final trimmed = val.trim();
                                            if (trimmed.isEmpty) {
                                              _setQtyManualKkso(it.produkId, null, syncController: false);
                                            } else {
                                              final parsed = int.tryParse(trimmed);
                                              if (parsed != null) {
                                                _setQtyManualKkso(
                                                  it.produkId,
                                                  parsed < 0 ? 0 : parsed,
                                                  syncController: false,
                                                );
                                              }
                                            }
                                          },
                                          onSubmitted: (_) {
                                            if (nextFocus != null) {
                                              FocusScope.of(context).requestFocus(nextFocus);
                                            } else {
                                              FocusScope.of(context).unfocus();
                                            }
                                          },
                                          decoration: const InputDecoration(
                                            hintText: '-',
                                            hintStyle: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.black38,
                                            ),
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => _ubahQtyStepperKkso(it, 1),
                                        child: Container(
                                          width: 54,
                                          height: 56,
                                          color: _kSoGreen,
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Jumlah (ketik angka atau +/- • tekan 0 jika rak kosong)',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kSoGreen,
                    side: const BorderSide(color: _kSoGreen, width: 1.3),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (_barcodeKksoCtrl.text.trim().isNotEmpty) {
                      _fokusKeBarcodeKkso(_barcodeKksoCtrl.text);
                    } else {
                      FocusScope.of(context).requestFocus(_barcodeKksoFocus);
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: const Text('Pindai Barcode', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _kSoGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _simpanProgresHitungKkso(ajukanReview: semuaSelesai),
                  icon: Icon(
                    semuaSelesai ? Icons.fact_check_rounded : Icons.check_circle_outline_rounded,
                    size: 18,
                  ),
                  label: Text(
                    semuaSelesai ? 'Minta Review' : 'Simpan & Lanjut $hitungSekarang/$total',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  late AnimationController _pulseCtrl;
  late AnimationController _waveCtrl;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  int _modeSub = 0;
  String _filterStok = 'Semua';
  final TextEditingController _cariCtrl = TextEditingController();
  final Map<String, TextEditingController> _soControllers = {};

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _syncSoControllers();
  }

  @override
  void didUpdateWidget(covariant SisInventorySoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.daftarProduk.length != widget.daftarProduk.length) {
      _syncSoControllers();
    }
  }

  void _syncSoControllers() {
    for (final p in widget.daftarProduk) {
      _soControllers.putIfAbsent(
        p.id,
        () => TextEditingController(text: p.stok.toString()),
      );
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _clockTimer?.cancel();
    _cariCtrl.dispose();
    _barcodeKksoCtrl.dispose();
    _barcodeKksoFocus.dispose();
    _catatanReviewKksoCtrl.dispose();
    _petugasDoubleCountCtrl.dispose();
    _bersihkanFastEntryControllers();
    for (final c in _soControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _bukaFormProduk({Produk? editProduk}) {
    final t = widget.tema;
    final isBaru = editProduk == null;
    final namaCtrl = TextEditingController(text: editProduk?.nama ?? '');
    final katCtrl = TextEditingController(text: editProduk?.kategori ?? 'Sembako');
    final satuanCtrl = TextEditingController(text: editProduk?.satuan ?? 'pcs');
    final skuCtrl = TextEditingController(text: editProduk?.kodeSku ?? '');
    final jualCtrl = TextEditingController(text: (editProduk?.hargaJual ?? 0).toString());
    final modalCtrl = TextEditingController(text: (editProduk?.hargaModal ?? 0).toString());
    final stokCtrl = TextEditingController(text: (editProduk?.stok ?? 0).toString());
    final minCtrl = TextEditingController(text: (editProduk?.minStokAlert ?? 5).toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          isBaru ? 'Tambah SKU Baru' : 'Edit • ${editProduk.nama}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: namaCtrl,
                decoration: InputDecoration(
                  labelText: 'Nama Produk',
                  filled: true,
                  fillColor: t.inputColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: katCtrl,
                      decoration: InputDecoration(
                        labelText: 'Kategori',
                        filled: true,
                        fillColor: t.inputColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: satuanCtrl,
                      decoration: InputDecoration(
                        labelText: 'Satuan',
                        filled: true,
                        fillColor: t.inputColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: skuCtrl,
                decoration: InputDecoration(
                  labelText: 'SKU / Barcode',
                  filled: true,
                  fillColor: t.inputColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: modalCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'HPP',
                        filled: true,
                        fillColor: t.inputColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: jualCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Harga Jual',
                        filled: true,
                        fillColor: t.inputColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: stokCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Stok',
                        filled: true,
                        fillColor: t.inputColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Min Stok',
                        filled: true,
                        fillColor: t.inputColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: t.primaryColor, foregroundColor: Colors.white),
            onPressed: () {
              final nama = namaCtrl.text.trim();
              if (nama.isEmpty) return;
              int numVal(TextEditingController c, int fb) =>
                  int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? fb;
              widget.onSimpanProduk(
                Produk(
                  id: editProduk?.id ?? 'prd_${DateTime.now().millisecondsSinceEpoch}',
                  nama: nama,
                  kategori: katCtrl.text.trim().isEmpty ? 'Umum' : katCtrl.text.trim(),
                  satuan: satuanCtrl.text.trim().isEmpty ? 'pcs' : satuanCtrl.text.trim(),
                  hargaJual: numVal(jualCtrl, 0),
                  hargaModal: numVal(modalCtrl, 0),
                  hargaGrosir: editProduk?.hargaGrosir ?? 0,
                  minQtyGrosir: editProduk?.minQtyGrosir ?? 0,
                  stok: numVal(stokCtrl, 0),
                  minStokAlert: numVal(minCtrl, 5),
                  kodeSku: skuCtrl.text.trim().isEmpty
                      ? 'SKU-${DateTime.now().millisecondsSinceEpoch % 10000}'
                      : skuCtrl.text.trim(),
                ),
                isBaru,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _dialogMutasiCepat(Produk prd, String tipeAwal) {
    final t = widget.tema;
    String tipe = tipeAwal;
    final qtyCtrl = TextEditingController(text: tipe == 'Masuk' ? '12' : '1');
    final ketCtrl = TextEditingController(
      text: tipe == 'Masuk' ? 'Restok / DO Masuk' : 'Penyesuaian Keluar',
    );
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: t.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Mutasi • ${prd.nama}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _PillTabItem(
                      label: 'Masuk (+)',
                      selected: tipe == 'Masuk',
                      color: t.successColor,
                      onTap: () => setDlg(() => tipe = 'Masuk'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PillTabItem(
                      label: 'Keluar (-)',
                      selected: tipe == 'Keluar',
                      color: t.dangerColor,
                      onTap: () => setDlg(() => tipe = 'Keluar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                style: gayaAngka(const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                decoration: InputDecoration(
                  labelText: 'Jumlah (${prd.satuan})',
                  filled: true,
                  fillColor: t.inputColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ketCtrl,
                decoration: InputDecoration(
                  labelText: 'Keterangan',
                  filled: true,
                  fillColor: t.inputColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: tipe == 'Masuk' ? t.successColor : t.dangerColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final qty = int.tryParse(qtyCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                if (qty > 0) {
                  widget.onMutasiStok(
                    produk: prd,
                    tipe: tipe,
                    perubahan: tipe == 'Masuk' ? qty : -qty,
                    keterangan: ketCtrl.text.trim().isEmpty ? 'Mutasi $tipe' : ketCtrl.text.trim(),
                  );
                }
                Navigator.pop(ctx);
              },
              child: const Text('Terapkan', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  void _simpanDokumenKeArsip(KksoDocument doc) {
    final list = List<KksoDocument>.from(widget.daftarKkso);
    final idx = list.indexWhere((e) => e.id == doc.id);
    if (idx == -1) {
      list.insert(0, doc);
    } else {
      list[idx] = doc;
    }
    widget.onSimpanKkso(list);
  }

  void _tolakReviewKkso(KksoDocument doc) {
    if (doc.isLocked) return;
    final kembaliDraft = doc.copyWith(status: KksoStatus.hitung);
    _simpanDokumenKeArsip(kembaliDraft);
    setState(() {
      _aktifKkso = kembaliDraft;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${doc.id} dikembalikan ke tahap Hitung (Draft).')),
    );
  }

  void _bukaModalOtorisasiSis(KksoDocument doc) {
    if (doc.isLocked) return;
    if (!_isOwnerOrSis) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hanya role SIS / Owner yang dapat menyetujui & posting.')),
      );
      return;
    }

    final itemsTerupdate = doc.items.map((it) {
      if (_doubleCountMap.containsKey(it.produkId)) {
        return it.copyWith(stokDoubleCount: _doubleCountMap[it.produkId]);
      }
      return it;
    }).toList();

    final docSiap = doc.copyWith(
      items: itemsTerupdate,
      alasan: _alasanTerpilihKkso,
      catatan: _catatanReviewKksoCtrl.text.trim(),
      petugasDoubleCount: _petugasDoubleCountCtrl.text.trim().isEmpty
          ? null
          : _petugasDoubleCountCtrl.text.trim(),
    );

    if (docSiap.wajibDoubleCount &&
        (docSiap.petugasDoubleCount == null || docSiap.petugasDoubleCount!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kerugian > Rp50.000 / Grand Opname wajib diisi nama Petugas Double Count ke-2!'),
        ),
      );
      return;
    }

    String pinInput = '';
    String? errPin;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          void tekanAngka(String digit) {
            if (pinInput.length >= 6) return;
            setDlg(() {
              pinInput += digit;
              errPin = null;
            });
          }

          void hapusAngka() {
            if (pinInput.isEmpty) return;
            setDlg(() {
              pinInput = pinInput.substring(0, pinInput.length - 1);
              errPin = null;
            });
          }

          Future<void> prosesPosting() async {
            if (pinInput.length < 4) {
              setDlg(() => errPin = 'Masukkan PIN 6 digit (atau PIN SIS aktif).');
              return;
            }
            final pinValid = widget.daftarStaff.any(
              (s) =>
                  s.aktif &&
                  s.isStoreSystem &&
                  (s.pin == pinInput ||
                      (pinInput.length == 6 && pinInput.startsWith(s.pin))),
            );
            final fallbackOwner = widget.currentStaff?.pin != null &&
                (widget.currentStaff!.pin == pinInput ||
                    (pinInput.length == 6 &&
                        pinInput.startsWith(widget.currentStaff!.pin)));

            if (!pinValid && !fallbackOwner && widget.daftarStaff.isNotEmpty) {
              setDlg(() => errPin = 'PIN Otorisasi SIS tidak cocok.');
              return;
            }

            for (final it in docSiap.itemsSelisih) {
              final idxPrd = widget.daftarProduk.indexWhere((p) => p.id == it.produkId);
              if (idxPrd != -1) {
                widget.onMutasiStok(
                  produk: widget.daftarProduk[idxPrd],
                  tipe: 'Opname',
                  perubahan: it.selisih,
                  keterangan:
                      '${docSiap.id} [${docSiap.alasan}] Sys ${it.stokSistem}->Fis ${it.fisikFinal}',
                );
              }
            }

            final postedBase = docSiap.copyWith(
              status: KksoStatus.posted,
              disetujuiOleh: widget.currentStaff?.nama ?? 'Owner / SIS',
              pinSisTerverifikasi: true,
              freezePenjualan: false,
              tanggalPosted: DateTime.now(),
            );

            final messenger = ScaffoldMessenger.of(context);
            final toko = widget.toko ?? PengaturanToko.defaultAwal();
            final pdfBytes = await generateKksoBeritaAcaraPdf(postedBase, toko);
            final postedFinal = postedBase.copyWith(
              pdfBase64: base64Encode(pdfBytes),
            );

            _simpanDokumenKeArsip(postedFinal);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            setState(() {
              _aktifKkso = postedFinal;
            });
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  '${postedFinal.id} POSTED & Berita Acara PDF otomatis tersimpan!',
                ),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _kSoGreenSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.verified_user_rounded, color: _kSoGreen, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Otorisasi SIS',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _kSoGreen),
                            ),
                            Text(
                              'Masukkan PIN Owner untuk posting penyesuaian stok',
                              style: TextStyle(fontSize: 10.5, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDECEC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${docSiap.totalSelisihItem > 0 ? "+${docSiap.totalSelisihItem}" : "${docSiap.totalSelisihItem}"} item',
                          style: gayaAngka(const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFFB91C1C))),
                        ),
                        Text(
                          _fmtRupiahPdf(docSiap.totalSelisihHpp.abs()),
                          style: gayaAngka(const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black87)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('PIN Owner (6 Digit)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (i) {
                      final filled = i < pinInput.length;
                      return Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: filled ? _kSoGreenSoft : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: filled ? _kSoGreen : Colors.black26,
                            width: filled ? 1.5 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          filled ? '•' : '',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _kSoGreen),
                        ),
                      );
                    }),
                  ),
                  if (errPin != null) ...[
                    const SizedBox(height: 6),
                    Text(errPin!, style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C), fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: 12),
                  for (final row in [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                    ['', '0', 'DEL'],
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          for (int c = 0; c < 3; c++) ...[
                            Expanded(
                              child: row[c].isEmpty
                                  ? const SizedBox(height: 40)
                                  : SizedBox(
                                      height: 40,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          elevation: 0,
                                          backgroundColor: const Color(0xFFF1F5F3),
                                          foregroundColor: Colors.black87,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                                        ),
                                        onPressed: () {
                                          if (row[c] == 'DEL') {
                                            hapusAngka();
                                          } else {
                                            tekanAngka(row[c]);
                                          }
                                        },
                                        child: row[c] == 'DEL'
                                            ? const Icon(Icons.backspace_outlined, size: 18)
                                            : Text(
                                                row[c],
                                                style: gayaAngka(const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                                              ),
                                      ),
                                    ),
                            ),
                            if (c < 2) const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _kSoGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: prosesPosting,
                          child: const Text('Posting Sekarang', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKksoReviewOwner(AppThemeConfig t, KksoDocument doc) {
    if (!_isOwnerOrSis) {
      return Center(
        key: const ValueKey('kkso_review_denied'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person_rounded, size: 48, color: _kSoGreen),
              const SizedBox(height: 10),
              const Text(
                'Menunggu Review Owner / SIS',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _kSoGreen),
              ),
              const SizedBox(height: 6),
              Text(
                'Dokumen ${doc.id} sudah selesai dihitung oleh ${doc.petugasHitung}. Stok sistem hanya dapat dilihat oleh SIS / Owner.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () => setState(() => _aktifKkso = null),
                child: const Text('Kembali ke Menu KKSO'),
              ),
            ],
          ),
        ),
      );
    }

    final itemsPreview = doc.items.map((it) {
      if (_doubleCountMap.containsKey(it.produkId)) {
        return it.copyWith(stokDoubleCount: _doubleCountMap[it.produkId]);
      }
      return it;
    }).toList();
    final previewDoc = doc.copyWith(items: itemsPreview);
    final isPosted = previewDoc.isLocked;

    return ListView(
      key: const ValueKey('kkso_review_owner'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
      children: [
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _aktifKkso = null),
              icon: const Icon(Icons.arrow_back_rounded, color: _kSoGreen),
            ),
            const Expanded(
              child: Text(
                'Review Stock Opname',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _kSoGreen),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kSoGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Nusantara Retail POS',
                style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: _kSoGreenSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kSoGreen.withAlpha(90)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${previewDoc.id} • ${previewDoc.jenis == KksoJenis.grand ? "GRAND OPNAME" : "PARTIAL OPNAME"} • ${previewDoc.areaLabel}',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: _kSoGreen),
              ),
              const SizedBox(height: 2),
              Text(
                'Tanggal: ${_fmtTglSingkat(previewDoc.tanggalDibuat)} • Status: ${isPosted ? "POSTED (Terkunci)" : "Menunggu Persetujuan Pemilik"}',
                style: const TextStyle(fontSize: 10.5, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tidak ada foto bukti (No photo evidence)',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _kSoGreen),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Perbandingan Stok: Sistem vs Fisik',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(_kSoGreenSoft),
              columnSpacing: 14,
              horizontalMargin: 10,
              columns: const [
                DataColumn(label: Text('Produk', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5))),
                DataColumn(label: Text('SKU', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5))),
                DataColumn(label: Text('Sistem', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5))),
                DataColumn(label: Text('Fisik', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5))),
                DataColumn(label: Text('Selisih', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5))),
                DataColumn(label: Text('HPP', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5))),
                DataColumn(label: Text('Jual', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5))),
              ],
              rows: [
                for (final it in previewDoc.items)
                  DataRow(
                    color: WidgetStateProperty.all(
                      it.selisih < 0 ? const Color(0xFFFDECEC) : Colors.white,
                    ),
                    cells: [
                      DataCell(SizedBox(width: 110, child: Text(it.namaProduk, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)))),
                      DataCell(Text(it.kodeSku, style: const TextStyle(fontSize: 10.5))),
                      DataCell(Text('${it.stokSistem}', style: gayaAngka(const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)))),
                      DataCell(Text('${it.fisikFinal}', style: gayaAngka(const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)))),
                      DataCell(
                        Text(
                          it.selisih > 0 ? '+${it.selisih}' : '${it.selisih}',
                          style: gayaAngka(
                            TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: it.selisih < 0
                                  ? const Color(0xFFB91C1C)
                                  : (it.selisih > 0 ? _kSoGreen : Colors.black54),
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(_fmtRupiahPdf(it.nilaiSelisihHpp.abs()), style: gayaAngka(const TextStyle(fontSize: 11)))),
                      DataCell(Text(_fmtRupiahPdf(it.nilaiSelisihJual.abs()), style: gayaAngka(const TextStyle(fontSize: 11)))),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _KotakRingkasanReview(
                judul: 'Total Selisih',
                nilai: '${previewDoc.totalSelisihItem > 0 ? "+${previewDoc.totalSelisihItem}" : "${previewDoc.totalSelisihItem}"} item',
                warnaNilai: previewDoc.totalSelisihItem < 0 ? const Color(0xFFB91C1C) : _kSoGreen,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _KotakRingkasanReview(
                judul: 'Selisih HPP',
                nilai: _fmtRupiahPdf(previewDoc.totalSelisihHpp.abs()),
                warnaNilai: Colors.black87,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _KotakRingkasanReview(
                judul: 'Selisih Nilai Jual',
                nilai: _fmtRupiahPdf(previewDoc.totalSelisihJual.abs()),
                warnaNilai: Colors.black87,
              ),
            ),
          ],
        ),
        if (previewDoc.wajibDoubleCount && !isPosted) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD97706)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WAJIB DOUBLE COUNT (Kerugian > Rp50.000 / Grand Opname)',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF92400E)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _petugasDoubleCountCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nama Petugas Hitung Ulang (Ke-2) *',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (!isPosted) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Persetujuan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _alasanTerpilihKkso,
                  decoration: InputDecoration(
                    labelText: 'Alasan *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    for (final a in _daftarAlasanKkso)
                      DropdownMenuItem(value: a, child: Text(a)),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _alasanTerpilihKkso = val);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _catatanReviewKksoCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Catatan (Opsional)',
                    hintText: 'Contoh: Produk hilang saat display, diduga terjatuh',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _tolakReviewKkso(previewDoc),
                  child: const Text('Tolak', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _kSoGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _bukaModalOtorisasiSis(previewDoc),
                  icon: const Icon(Icons.lock_rounded, size: 17),
                  label: const Text('Setujui', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kSoGreenSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kSoGreen),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'POSTED • Berita Acara PDF Tersimpan (${previewDoc.id})',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: _kSoGreen),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Dokumen terkunci dan tercatat di Log Mutasi & Laporan > Stock Opname.',
                  style: TextStyle(fontSize: 11, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tema;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: _PillTabItem(
                  label: 'Master Stok',
                  selected: _modeSub == 0,
                  color: t.primaryColor,
                  onTap: () => setState(() => _modeSub = 0),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _PillTabItem(
                  label: 'Stock Opname',
                  selected: _modeSub == 1,
                  color: _kSoGreen,
                  onTap: () => setState(() => _modeSub = 1),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _PillTabItem(
                  label: 'Log Mutasi',
                  selected: _modeSub == 2,
                  color: t.primaryColor,
                  onTap: () => setState(() => _modeSub = 2),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _modeSub == 0
              ? _buildStok(t)
              : (_modeSub == 1 ? _buildSo(t) : _buildLog(t)),
        ),
      ],
    );
  }

  Widget _buildStok(AppThemeConfig t) {
    final q = _cariCtrl.text.trim().toLowerCase();
    final filtered = widget.daftarProduk.where((p) {
      final cocokCari = q.isEmpty ||
          p.nama.toLowerCase().contains(q) ||
          p.kodeSku.toLowerCase().contains(q) ||
          p.kategori.toLowerCase().contains(q);
      if (!cocokCari) return false;
      if (_filterStok == 'Menipis') return p.stok > 0 && p.stok <= p.minStokAlert;
      if (_filterStok == 'Habis') return p.stok <= 0;
      return true;
    }).toList();

    final totalAsetHpp = widget.daftarProduk.fold<int>(0, (s, p) => s + (p.stok * p.hargaModal));
    final totalMenipis = widget.daftarProduk.where((p) => p.stok <= p.minStokAlert).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: _GlowMetricTile(
                  tema: t,
                  title: 'Total SKU (Menipis: $totalMenipis)',
                  value: '${widget.daftarProduk.length} SKU',
                  accent: t.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GlowMetricTile(
                  tema: t,
                  title: 'Aset HPP • ${_now.hour.toString().padLeft(2, "0")}:${_now.minute.toString().padLeft(2, "0")}',
                  value: formatRupiah(totalAsetHpp),
                  accent: _kSoGreen,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cariCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Cari produk / SKU...',
                    isDense: true,
                    filled: true,
                    fillColor: t.inputColor,
                    prefixIcon: const Icon(Icons.search_rounded, size: 19),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: t.primaryColor, foregroundColor: Colors.white),
                onPressed: () => _bukaFormProduk(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Produk'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Row(
            children: [
              for (final f in ['Semua', 'Menipis', 'Habis']) ...[
                _PillTabItem(
                  label: f,
                  selected: _filterStok == f,
                  color: t.primaryColor,
                  compact: true,
                  onTap: () => setState(() => _filterStok = f),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final p = filtered[i];
              return Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: t.surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                          Text('${p.kodeSku} • ${p.kategori} • HPP ${formatRupiah(p.hargaModal)}', style: TextStyle(fontSize: 11, color: t.textSecondary)),
                          Text('Stok: ${p.stok} ${p.satuan} • Jual ${formatRupiah(p.hargaJual)}', style: gayaAngka(TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: p.stok <= p.minStokAlert ? t.dangerColor : t.primaryColor))),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Mutasi Cepat',
                      onPressed: () => _dialogMutasiCepat(p, 'Masuk'),
                      icon: Icon(Icons.swap_vert_circle_rounded, color: t.primaryColor),
                    ),
                    IconButton(
                      tooltip: 'Edit Produk',
                      onPressed: () => _bukaFormProduk(editProduk: p),
                      icon: const Icon(Icons.edit_rounded, size: 19),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSo(AppThemeConfig t) {
    final doc = _aktifKkso;
    if (doc == null) {
      return _buildKksoPilihanAwal(t);
    }
    if (doc.status == KksoStatus.hitung) {
      return _buildKksoHitungBorongan(t, doc);
    }
    return _buildKksoReviewOwner(t, doc);
  }

  Widget _buildLog(AppThemeConfig t) {
    final logs = [...widget.daftarLogStok]..sort((a, b) => b.tanggal.compareTo(a.tanggal));
    if (logs.isEmpty) {
      return Center(key: const ValueKey('inv_log_empty'), child: Text('Belum ada mutasi stok.', style: TextStyle(color: t.textSecondary)));
    }
    return ListView.separated(
      key: const ValueKey('inv_log'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final lg = logs[i];
        final isPlus = lg.perubahan >= 0;
        final clr = lg.tipe == 'Opname' ? Colors.indigo : (isPlus ? t.successColor : t.dangerColor);
        return Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: t.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.borderColor),
          ),
          child: Row(
            children: [
              StatusBadge(label: lg.tipe, color: clr),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lg.namaProduk, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                    Text(lg.keterangan, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: t.textSecondary)),
                    Text(formatTanggalWaktu(lg.tanggal), style: TextStyle(fontSize: 10, color: t.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isPlus ? '+${lg.perubahan}' : '${lg.perubahan}',
                    style: gayaAngka(TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: clr)),
                  ),
                  Text('Sisa ${lg.stokAkhir}', style: TextStyle(fontSize: 10.5, color: t.textSecondary)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PillTabItem extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  const _PillTabItem({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 11 : 10,
          vertical: compact ? 6 : 9,
        ),
        decoration: BoxDecoration(
          color: selected ? color : t.colorScheme.surfaceContainerHighest.withAlpha(110),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? color : t.dividerColor),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : t.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowMetricTile extends StatelessWidget {
  final AppThemeConfig tema;
  final String title;
  final String value;
  final Color accent;

  const _GlowMetricTile({
    required this.tema,
    required this.title,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: tema.surfaceColor.withAlpha(225),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: tema.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: gayaAngka(TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: accent)),
          ),
        ],
      ),
    );
  }
}

class _KotakRingkasanReview extends StatelessWidget {
  final String judul;
  final String nilai;
  final Color warnaNilai;

  const _KotakRingkasanReview({
    required this.judul,
    required this.nilai,
    required this.warnaNilai,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F3EE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0E5A3E).withAlpha(80)),
      ),
      child: Column(
        children: [
          Text(
            judul,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            nilai,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: gayaAngka(TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: warnaNilai)),
          ),
        ],
      ),
    );
  }
}
