import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
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
  static const Color _kSoBlue = Color(0xFF1E40AF);
  static const String _kPinSisValid = '123456';

  int _kksoStep = 0;
  KksoDocument? _aktifKkso;

  KksoJenis _step0Jenis = KksoJenis.grand;
  final String _step0SubMode = 'Semua Area Toko';
  String _step0Area = 'Rak Display 01';
  final DateTime _step0Tgl = DateTime.now();
  final TextEditingController _kksoIdCtrl = TextEditingController();

  final Map<String, int?> _draftFisik = {};
  final Map<String, int?> _snapEdit = {};
  String? _fokusId;
  String _padBuf = '';
  bool _padReplace = true;
  final TextEditingController _editCatatanCtrl = TextEditingController();

  final TextEditingController _pinSisCtrl = TextEditingController();
  bool _pinErr = false;
  bool _busyAdjust = false;
  KksoDocument? _step6Doc;

  String _genNoKkso([DateTime? ref]) {
    final n = ref ?? DateTime.now();
    final yy = (n.year % 100).toString().padLeft(2, '0');
    final mm = n.month.toString().padLeft(2, '0');
    final dd = n.day.toString().padLeft(2, '0');
    final r = (n.millisecondsSinceEpoch % 900 + 100).toString();
    return 'KKSO-$yy$mm$dd-$r';
  }

  String _fmtRp(int v) {
    final neg = v < 0 ? '-' : '';
    final str = v.abs().toString();
    final b = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) b.write('.');
      b.write(str[i]);
    }
    return '${neg}Rp${b.toString()}';
  }

  List<KksoItem> _toItems(List<Produk> list, String rakDef) {
    return list.map((p) {
      final rak = p.kategori.trim().isEmpty ? rakDef : 'Rak ${p.kategori.trim()}';
      return KksoItem(
        produkId: p.id,
        namaProduk: p.nama,
        kodeSku: p.kodeSku,
        barcode: p.kodeSku,
        kategori: p.kategori,
        satuan: p.satuan,
        lokasiRak: rak,
        stokSistem: p.stok,
        stokFisik: null,
        hargaModal: p.hargaModal,
        hargaJual: p.hargaJual,
        sudahDihitung: false,
      );
    }).toList();
  }

  int? _fisikOf(KksoItem it) {
    if (_draftFisik.containsKey(it.produkId)) return _draftFisik[it.produkId];
    return it.sudahDihitung ? it.stokFisik : null;
  }

  int _sumHppSelisih(List<KksoItem> items) {
    int sum = 0;
    for (final it in items) {
      final f = _fisikOf(it);
      if (f != null && f != it.stokSistem) {
        sum += (it.stokSistem - f) * it.hargaModal;
      }
    }
    return sum;
  }

  int _sumOrigHpp(List<KksoItem> items) {
    int sum = 0;
    for (final it in items) {
      final f = _fisikOf(it);
      if (f != null && f != it.stokSistem) sum += it.stokSistem * it.hargaModal;
    }
    return sum;
  }

  int _sumAdjHpp(List<KksoItem> items) {
    int sum = 0;
    for (final it in items) {
      final f = _fisikOf(it);
      if (f != null && f != it.stokSistem) sum += f * it.hargaModal;
    }
    return sum;
  }

  // ignore: unused_element
  void _bukaStep0Mulai({KksoJenis? jenisAwal}) {
    if (_kksoIdCtrl.text.trim().isEmpty) {
      _kksoIdCtrl.text = _genNoKkso(_step0Tgl);
    }
    setState(() {
      if (jenisAwal != null) _step0Jenis = jenisAwal;
      _kksoStep = 0;
      _aktifKkso = null;
    });
  }

  void _mulaiStep1() {
    if (widget.daftarProduk.isEmpty) return;
    List<Produk> target;
    String area;
    if (_step0Jenis == KksoJenis.grand) {
      target = List<Produk>.from(widget.daftarProduk);
      area = 'Semua Area Toko • ${target.length} SKU';
    } else if (_step0SubMode == 'Quick 5 SKU Risiko Tinggi') {
      final s = List<Produk>.from(widget.daftarProduk)
        ..sort((a, b) => (a.stok - a.minStokAlert).compareTo(b.stok - b.minStokAlert));
      target = s.take(5).toList();
      area = '5 SKU Rawan • ${target.length} SKU';
    } else {
      target = widget.daftarProduk.where((p) {
        final rak = p.kategori.trim().isEmpty ? 'Rak Display 01' : 'Rak ${p.kategori.trim()}';
        return rak == _step0Area;
      }).toList();
      if (target.isEmpty) target = List<Produk>.from(widget.daftarProduk);
      area = '$_step0Area • ${target.length} SKU';
    }

    final idStr = _kksoIdCtrl.text.trim().isEmpty ? _genNoKkso(_step0Tgl) : _kksoIdCtrl.text.trim();
    final items = _toItems(target, area);
    final doc = KksoDocument(
      id: idStr,
      jenis: _step0Jenis,
      subJenis: _step0Jenis == KksoJenis.grand ? 'Grand Opname' : _step0SubMode,
      areaLabel: area,
      status: KksoStatus.hitung,
      petugasHitung: widget.currentStaff?.nama ?? 'Petugas Toko',
      freezePenjualan: _step0Jenis == KksoJenis.grand,
      tanggalDibuat: _step0Tgl,
      items: items,
    );

    _draftFisik.clear();
    for (final it in items) {
      _draftFisik[it.produkId] = null;
    }
    widget.onSimpanKkso([doc, ...widget.daftarKkso.where((d) => d.id != doc.id)]);

    setState(() {
      _aktifKkso = doc;
      _kksoStep = 1;
      _fokusId = items.isNotEmpty ? items.first.produkId : null;
      _padBuf = '';
      _padReplace = true;
    });
  }

  void _pilihFokus(KksoItem it, {bool editMode = false}) {
    final q = _fisikOf(it);
    setState(() {
      _fokusId = it.produkId;
      _padBuf = q != null ? '$q' : '';
      _padReplace = true;
      if (editMode) _snapEdit.putIfAbsent(it.produkId, () => q);
    });
  }

  void _onDigit(String d) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_padReplace) {
        _padBuf = d;
        _padReplace = false;
      } else if (_padBuf == '0') {
        _padBuf = d;
      } else if (_padBuf.length < 6) {
        _padBuf += d;
      }
    });
  }

  void _onClear() {
    HapticFeedback.selectionClick();
    setState(() {
      _padBuf = '';
      _padReplace = false;
    });
  }

  void _onConfirm(KksoDocument doc, KksoItem item, {bool editMode = false}) {
    HapticFeedback.mediumImpact();
    final qty = _padBuf.trim().isEmpty ? 0 : (int.tryParse(_padBuf.trim()) ?? 0);
    setState(() {
      _draftFisik[item.produkId] = qty;
      if (editMode) {
        final prev = _snapEdit[item.produkId] ?? _fisikOf(item) ?? 0;
        if (prev != qty) {
          final now = DateTime.now();
          const bln = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
          final tgl = '${now.day} ${bln[(now.month - 1).clamp(0, 11)]} ${now.year}';
          final jam = '${now.hour.toString().padLeft(2, "0")}:${now.minute.toString().padLeft(2, "0")}';
          final petugas = widget.currentStaff?.nama ?? 'Kasir-07';
          final note = _editCatatanCtrl.text.trim();
          final line = 'Terakhir diubah $tgl • $jam • oleh $petugas${note.isNotEmpty ? " • $note" : ""}';
          _aktifKkso = doc.copyWith(editLogs: [...doc.editLogs, line]);
        }
        _snapEdit[item.produkId] = qty;
      }

      final curIdx = doc.items.indexWhere((e) => e.produkId == item.produkId);
      KksoItem? nextNull;
      for (int s = 1; s <= doc.items.length; s++) {
        final cand = doc.items[(curIdx + s) % doc.items.length];
        if (cand.produkId != item.produkId && _fisikOf(cand) == null) {
          nextNull = cand;
          break;
        }
      }
      if (nextNull != null) {
        _fokusId = nextNull.produkId;
        final nq = _fisikOf(nextNull);
        _padBuf = nq != null ? '$nq' : '';
        _padReplace = true;
      } else {
        _padBuf = '$qty';
        _padReplace = true;
      }
    });
  }

  KksoDocument _syncDoc(KksoDocument doc, {KksoStatus? st}) {
    final items = doc.items.map((it) {
      final f = _fisikOf(it);
      final done = f != null;
      return it.copyWith(stokFisik: f, clearStokFisik: !done, sudahDihitung: done);
    }).toList();
    return doc.copyWith(items: items, status: st ?? doc.status, tanggalSelesaiHitung: DateTime.now());
  }

  Future<void> _cetakSelisihPdf(KksoDocument doc) async {
    final diffItems = doc.items.where((it) {
      final f = _fisikOf(it);
      return f != null && f != it.stokSistem;
    }).toList();
    final hppSelisih = _sumHppSelisih(doc.items);
    final ver = (doc.lastPrint?.versi ?? 0) + 1;

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(widget.toko?.namaToko ?? 'Nusantara Retail POS', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.Text('DRAFT • BUKAN ADJUST (v$ver)', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Text('Cetak Selisih — Ultra Blind Count', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('${doc.id} • ${doc.areaLabel}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Divider(height: 20),
            for (final it in diffItems)
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(it.namaProduk, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Has Difference', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
                  ],
                ),
              ),
            pw.Spacer(),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(color: PdfColors.blue50, border: pw.Border.all(color: PdfColors.blue700), borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total HPP Selisih', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_fmtRp(hppSelisih), style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final bytes = await pdf.save();
    final synced = _syncDoc(doc, st: KksoStatus.review).copyWith(
      lastPrint: KksoPrint(versi: ver, totalHppSelisih: hppSelisih, dicetakPada: DateTime.now(), ringkasanVersi: doc.editLogs),
    );
    setState(() => _aktifKkso = synced);
    widget.onSimpanKkso([synced, ...widget.daftarKkso.where((d) => d.id != synced.id)]);
    await Printing.sharePdf(bytes: bytes, filename: 'Draft_Selisih_${doc.id}_v$ver.pdf');
  }

  Future<void> _prosesFixedAdjust(KksoDocument doc) async {
    if (_pinSisCtrl.text.trim() != _kPinSisValid) {
      setState(() => _pinErr = true);
      return;
    }
    setState(() {
      _pinErr = false;
      _busyAdjust = true;
    });

    final syncedInput = _syncDoc(doc, st: KksoStatus.posted);
    final postedBase = syncedInput.copyWith(
      disetujuiOleh: widget.currentStaff?.nama ?? 'Owner / SIS',
      pinSisTerverifikasi: true,
      tanggalPosted: DateTime.now(),
      alasan: doc.alasan ?? 'Fixed Adjust Stock Opname',
      catatan: _editCatatanCtrl.text.trim().isNotEmpty
          ? _editCatatanCtrl.text.trim()
          : (doc.editLogs.isNotEmpty ? doc.editLogs.last : 'PIN SIS Valid'),
    );

    final updatedItems = <KksoItem>[];
    for (final it in postedBase.items) {
      final f = it.stokFisik;
      if (f != null && (f - it.stokSistem).abs() > 0.0001) {
        final deltaNum = f - it.stokSistem;
        final prd = widget.daftarProduk.firstWhere(
          (p) => p.id == it.produkId,
          orElse: () => Produk(
            id: it.produkId,
            nama: it.namaProduk,
            kodeSku: it.kodeSku,
            kategori: it.kategori,
            satuan: it.satuan,
            hargaModal: it.hargaModal,
            hargaJual: it.hargaJual,
            stok: it.stokSistem,
          ),
        );
        final stokFinal = f.round();
        final produkBaru = prd.copyWith(stok: stokFinal);
        widget.onSimpanProduk(produkBaru, false);
        widget.onMutasiStok(
          produk: produkBaru,
          tipe: deltaNum > 0 ? 'Masuk' : 'Keluar',
          perubahan: deltaNum.abs().round(),
          keterangan: 'KKSO ${postedBase.id} FIXED ADJUST (${it.stokSistem} -> $f)',
        );
        updatedItems.add(it.copyWith(stokFisik: f));
      } else {
        updatedItems.add(it);
      }
    }

    final postedDoc = postedBase.copyWith(items: updatedItems);
    final pdfBytes = await generateKksoBeritaAcaraPdf(
      postedDoc,
      widget.toko ?? PengaturanToko.defaultAwal(),
    );
    final finalDoc = postedDoc.copyWith(pdfBase64: base64Encode(pdfBytes));
    widget.onSimpanKkso([finalDoc, ...widget.daftarKkso.where((d) => d.id != finalDoc.id)]);

    setState(() {
      _busyAdjust = false;
      _step6Doc = finalDoc;
      _aktifKkso = finalDoc;
      _kksoStep = 6;
      _pinSisCtrl.clear();
    });
  }
  // ignore: unused_element
  Widget _buildKksoFlow(AppThemeConfig t, KksoDocument doc) {
    if (_kksoStep == 1) return _buildStep1(doc);
    if (_kksoStep == 2) return _buildStep2(doc);
    if (_kksoStep == 3) return _buildStep3(doc);
    if (_kksoStep == 4) return _buildStep4(doc);
    if (_kksoStep == 5) return _buildStep5(doc);
    if (_kksoStep == 6) return _buildStep6(doc);
    return _buildStep0(jenisAwal: doc.jenis);
  }

  String _namaBulanStep6(int m) {
    const bln = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return bln[(m - 1).clamp(0, 11)];
  }

  Future<void> _exportBeritaAcaraStep6(KksoDocument doc, {bool shareMode = true}) async {
    final diffItems = doc.items.where((it) {
      final f = it.stokFisik;
      return f != null && (f - it.stokSistem).abs() > 0.0001;
    }).toList();

    int minusProduk = 0;
    int minusPcs = 0;
    int minusHpp = 0;
    int plusProduk = 0;
    int plusPcs = 0;
    int plusHpp = 0;

    for (final it in diffItems) {
      final f = it.stokFisik!;
      final deltaNum = f - it.stokSistem;
      final deltaInt = deltaNum.round();
      final hppInt = (deltaNum * it.hargaModal).round();
      if (deltaInt < 0) {
        minusProduk += 1;
        minusPcs += deltaInt.abs();
        minusHpp += hppInt.abs();
      } else if (deltaInt > 0) {
        plusProduk += 1;
        plusPcs += deltaInt;
        plusHpp += hppInt.abs();
      }
    }

    final netSelisihHpp = plusHpp - minusHpp;
    final postedBy = (doc.disetujuiOleh?.trim().isNotEmpty ?? false)
        ? doc.disetujuiOleh!.trim()
        : (widget.currentStaff?.nama.trim().isNotEmpty ?? false)
            ? widget.currentStaff!.nama.trim()
            : 'Admin Operasional';
    final tglPosted = doc.tanggalPosted ?? DateTime.now();
    final tglLabel = '${tglPosted.day} ${_namaBulanStep6(tglPosted.month)} ${tglPosted.year}';
    final jamLabel = '${tglPosted.hour.toString().padLeft(2, "0")}:${tglPosted.minute.toString().padLeft(2, "0")} WIB';

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Final Stock Opname Result Report', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text('FIXED POSTED', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text('${widget.toko?.namaToko ?? "Nusantara Retail POS"} • Dokumen ${doc.id}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Divider(height: 18),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.red300), borderRadius: pw.BorderRadius.circular(6)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Minus', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                        pw.Text('$minusProduk Produk • -$minusPcs pcs', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text('${_fmtRp(minusHpp)} HPP', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.green300), borderRadius: pw.BorderRadius.circular(6)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Plus', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                        pw.Text('$plusProduk Produk • +$plusPcs pcs', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text('${_fmtRp(plusHpp)} HPP', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.amber600), borderRadius: pw.BorderRadius.circular(6)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Net Selisih', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900)),
                        pw.Text(_fmtRp(netSelisihHpp), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Total selisih nilai HPP', style: const pw.TextStyle(fontSize: 8.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Text('Detail Selisih Produk', style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            for (final it in diffItems) ...[
              () {
                final f = it.stokFisik!;
                final dPcs = (f - it.stokSistem).round();
                final hppVal = ((f - it.stokSistem) * it.hargaModal).round();
                final isPlus = dPcs > 0;
                final signStr = isPlus ? '+$dPcs pcs' : '$dPcs pcs';
                final kat = it.kategori.trim().isEmpty ? 'Umum' : it.kategori.trim();
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(5)),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(it.namaProduk, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            pw.Text('SKU: ${it.kodeSku} • Kategori: $kat', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                          ],
                        ),
                      ),
                      pw.Text(signStr, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(width: 10),
                      pw.Text(_fmtRp(hppVal), style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(width: 10),
                      pw.Text(isPlus ? 'PLUS' : 'MINUS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: isPlus ? PdfColors.green800 : PdfColors.red800)),
                    ],
                  ),
                );
              }(),
            ],
            pw.Spacer(),
            pw.Divider(),
            pw.Text('Total Net Selisih: ${_fmtRp(netSelisihHpp)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Text('Selisih negatif akan dicatat sebagai penyesuaian untuk periode 26 Nov 2023. Hasil telah di-posting dan tidak dapat diedit kembali.', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 4),
            pw.Text('Diposting oleh $postedBy • $tglLabel $jamLabel', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ],
        ),
      ),
    );

    final bytes = await pdf.save();
    if (shareMode) {
      await Printing.sharePdf(bytes: bytes, filename: 'Berita_Acara_Final_${doc.id}.pdf');
    } else {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    }
  }

  Widget _buildStep6(KksoDocument doc) {
    

    final reportDoc = _step6Doc ?? doc;
    final diffItems = reportDoc.items.where((it) {
      final f = it.stokFisik;
      return f != null && (f - it.stokSistem).abs() > 0.0001;
    }).toList();

    int minusProduk = 0;
    int minusPcs = 0;
    int minusHpp = 0;
    int plusProduk = 0;
    int plusPcs = 0;
    int plusHpp = 0;

    for (final it in diffItems) {
      final f = it.stokFisik!;
      final deltaNum = f - it.stokSistem;
      final deltaInt = deltaNum.round();
      final hppInt = (deltaNum * it.hargaModal).round();
      if (deltaInt < 0) {
        minusProduk += 1;
        minusPcs += deltaInt.abs();
        minusHpp += hppInt.abs();
      } else if (deltaInt > 0) {
        plusProduk += 1;
        plusPcs += deltaInt;
        plusHpp += hppInt.abs();
      }
    }

    final netSelisihHpp = plusHpp - minusHpp;
    final postedBy = (reportDoc.disetujuiOleh?.trim().isNotEmpty ?? false)
        ? reportDoc.disetujuiOleh!.trim()
        : (widget.currentStaff?.nama.trim().isNotEmpty ?? false)
            ? widget.currentStaff!.nama.trim()
            : 'Admin Operasional';
    final tglPosted = reportDoc.tanggalPosted ?? DateTime.now();
    final tglLabel = '${tglPosted.day} ${_namaBulanStep6(tglPosted.month)} ${tglPosted.year}';
    final jamLabel = '${tglPosted.hour.toString().padLeft(2, "0")}:${tglPosted.minute.toString().padLeft(2, "0")} WIB';
    final tokoLabel = widget.toko?.namaToko ?? 'Nusantara Retail POS';

    String fmtSignedRp(int val) => val > 0 ? '+${_fmtRp(val)}' : _fmtRp(val);

    return Scaffold(
      key: const ValueKey('step6_final_report'),
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF3F6F4),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() {
                          _aktifKkso = null;
                          _step6Doc = null;
                          _kksoStep = 0;
                        }),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
                      ),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Final Stock Opname Result Report',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Ringkasan Hasil Akhir Untuk Owner',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          foregroundColor: Colors.black87,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _exportBeritaAcaraStep6(reportDoc, shareMode: false),
                        icon: const Icon(Icons.print_rounded, size: 15),
                        label: const Text('Print', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 6),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _exportBeritaAcaraStep6(reportDoc, shareMode: true),
                        icon: const Icon(Icons.download_rounded, size: 15),
                        label: const Text('Export PDF', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Hasil Stock Opname • ${reportDoc.id} • $tglLabel • $jamLabel',
                          style: const TextStyle(fontSize: 10.5, color: Colors.black54, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF15803D)),
                            SizedBox(width: 4),
                            Text(
                              'FIXED POSTED',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF15803D)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF87171),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.trending_down_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Minus $minusProduk Produk',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.black87),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '-${minusPcs.abs()} pcs',
                          style: gayaAngka(const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFB91C1C))),
                        ),
                        Text(
                          '${_fmtRp(minusHpp)} HPP',
                          style: gayaAngka(const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.black54)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF6EE7B7)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4ADE80),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Plus $plusProduk Produk',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.black87),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '+$plusPcs pcs',
                          style: gayaAngka(const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF047857))),
                        ),
                        Text(
                          '${_fmtRp(plusHpp)} HPP',
                          style: gayaAngka(const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.black54)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBBF24),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.scale_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Net Selisih',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.black87),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fmtSignedRp(netSelisihHpp),
                          style: gayaAngka(const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Color(0xFFB45309))),
                        ),
                        const Text(
                          'Total selisih nilai HPP',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Detail Selisih Produk',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black87),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Ringkasan untuk Owner',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 4, child: Text('PRODUK', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.black54))),
                        Expanded(flex: 2, child: Text('SKU', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.black54))),
                        Expanded(flex: 2, child: Text('SELISIH', textAlign: TextAlign.center, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.black54))),
                        Expanded(flex: 2, child: Text('NILAI HPP', textAlign: TextAlign.right, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.black54))),
                        SizedBox(width: 6),
                        SizedBox(width: 46, child: Text('STATUS', textAlign: TextAlign.center, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.black54))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (diffItems.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Tidak ada produk yang memiliki selisih.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    )
                  else
                    for (final it in diffItems) ...[
                      () {
                        final f = it.stokFisik!;
                        final dPcs = (f - it.stokSistem).round();
                        final hppVal = ((f - it.stokSistem) * it.hargaModal).round();
                        final isPlus = dPcs > 0;
                        final selisihLabel = isPlus ? '+$dPcs pcs' : '$dPcs pcs';
                        final katLabel = it.kategori.trim().isEmpty ? 'Umum' : it.kategori.trim();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(it.namaProduk, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                    Text('Kategori: $katLabel', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  it.kodeSku,
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.black87),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  selisihLabel,
                                  textAlign: TextAlign.center,
                                  style: gayaAngka(
                                    TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                      color: isPlus ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  fmtSignedRp(hppVal),
                                  textAlign: TextAlign.right,
                                  style: gayaAngka(
                                    TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isPlus ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 46,
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                decoration: BoxDecoration(
                                  color: isPlus ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  isPlus ? 'PLUS' : 'MINUS',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: isPlus ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }(),
                    ],
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Net Selisih:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                      Text(
                        fmtSignedRp(netSelisihHpp),
                        style: gayaAngka(
                          TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: netSelisihHpp >= 0 ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: Colors.black54),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Selisih negatif akan dicatat sebagai penyesuaian untuk periode 26 Nov 2023. Hasil telah di-posting dan tidak dapat diedit kembali.',
                          style: TextStyle(fontSize: 10.5, color: Colors.black87, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Text(
                        'Diposting oleh $postedBy • $tglLabel • $jamLabel',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black54),
                      ),
                      Text(
                        'Dokumen resmi • $tokoLabel',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black45),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep0({KksoJenis? jenisAwal}) {
    final j = jenisAwal ?? _step0Jenis;
    final rakList = <String>{
      for (final p in widget.daftarProduk) p.kategori.trim().isEmpty ? 'Rak Display 01' : 'Rak ${p.kategori.trim()}',
    }.toList();
    if (rakList.isEmpty) rakList.add('Rak Display 01');
    final curRak = rakList.contains(_step0Area) ? _step0Area : rakList.first;

    return Scaffold(
      key: const ValueKey('step0'),
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF6F9F7),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: _kSoGreen, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                IconButton(onPressed: () => setState(() => _aktifKkso = null), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                const Expanded(child: Text('Nusantara Retail POS', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900))),
                const Text('DRAFT-HITUNG', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('Step 0 of 3 • Mulai Stock Opname', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _JenisTile(title: 'Grand Opname', sub: 'Hitung seluruh stok di semua lokasi', selected: j == KksoJenis.grand, onTap: () => setState(() => _step0Jenis = KksoJenis.grand)),
          const SizedBox(height: 8),
          _JenisTile(title: 'Partial Opname', sub: 'Hitung sebagian stok sesuai kategori/lokasi', selected: j == KksoJenis.partial, onTap: () => setState(() => _step0Jenis = KksoJenis.partial)),
          if (j == KksoJenis.partial) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: curRak,
              decoration: InputDecoration(labelText: 'Pilih Rak / Area', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              items: [for (final r in rakList) DropdownMenuItem(value: r, child: Text(r))],
              onChanged: (v) { if (v != null) setState(() => _step0Area = v); },
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _kksoIdCtrl,
            decoration: InputDecoration(
              labelText: 'KKSO ID',
              filled: true,
              fillColor: Colors.white,
              suffixIcon: IconButton(onPressed: () => _kksoIdCtrl.text = _genNoKkso(_step0Tgl), icon: const Icon(Icons.refresh_rounded, color: _kSoGreen)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kSoGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
              onPressed: _mulaiStep1,
              child: const Text('Mulai', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1(KksoDocument doc) {
    final total = doc.items.length;
    final doneCount = doc.items.where((e) => _fisikOf(e) != null).length;

    final indexed = doc.items.asMap().entries.toList()
      ..sort((a, b) {
        final ad = _fisikOf(a.value) != null;
        final bd = _fisikOf(b.value) != null;
        if (ad != bd) return ad ? 1 : -1;
        return a.key.compareTo(b.key);
      });
    final listUnified = [for (final e in indexed) e.value];

    final fokus = listUnified.isEmpty
        ? null
        : listUnified.firstWhere((e) => e.produkId == _fokusId, orElse: () => listUnified.firstWhere((e) => _fisikOf(e) == null, orElse: () => listUnified.first));
    final fQty = fokus != null ? _fisikOf(fokus) : null;
    final bigVal = _padBuf.isNotEmpty ? _padBuf : (fQty != null ? '$fQty' : '-');

    return Scaffold(
      key: const ValueKey('step1'),
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF3F6F4),
      body: Column(
        children: [
          Container(
            color: _kSoBlue,
            padding: const EdgeInsets.fromLTRB(8, 6, 12, 8),
            child: Row(
              children: [
                IconButton(onPressed: () => setState(() => _kksoStep = 0), icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${doc.id} • STEP 1 INPUT', style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900)),
                      const Text('System Qty: --- • Hidden (Ultra Blind Count)', style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                    ],
                  ),
                ),
                Text('$doneCount/$total', style: gayaAngka(const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900))),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              itemCount: listUnified.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (ctx, i) {
                final it = listUnified[i];
                final q = _fisikOf(it);
                final done = q != null;
                final sel = fokus?.produkId == it.produkId;
                return InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => _pilihFokus(it),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: done ? const Color(0xFFE8F5E9) : Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: sel ? _kSoBlue : (done ? _kSoGreen : Colors.grey.shade300), width: sel ? 1.7 : 1),
                    ),
                    child: Row(
                      children: [
                        Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 16, color: done ? _kSoGreen : Colors.grey.shade400),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            done ? '${it.namaProduk} - OK $q' : it.namaProduk,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, fontWeight: done || sel ? FontWeight.w800 : FontWeight.w600, color: done ? _kSoGreen : Colors.black87),
                          ),
                        ),
                        const Text('Sys: ---', style: TextStyle(fontSize: 10.5, color: Colors.black45)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (fokus != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: fQty != null ? const Color(0xFFE8F5E9) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kSoBlue, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_rounded, color: _kSoBlue, size: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fokus.namaProduk, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                          Text('SKU: ${fokus.kodeSku} • System Qty: ---', style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
                          const Text('Ketuk angka untuk ubah', style: TextStyle(fontSize: 10, color: _kSoBlue, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _padReplace = true),
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 82),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _kSoBlue)),
                        alignment: Alignment.center,
                        child: Text(bigVal, style: gayaAngka(TextStyle(fontSize: 48, height: 1.05, fontWeight: FontWeight.w900, color: bigVal == '-' ? Colors.black38 : _kSoBlue))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: doneCount > 0 ? _kSoGreenSoft : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      final synced = _syncDoc(doc);
                      widget.onSimpanKkso([
                        synced,
                        ...widget.daftarKkso.where((d) => d.id != synced.id),
                      ]);
                      setState(() {
                        _aktifKkso = synced;
                        _kksoStep = 2;
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kSoGreen, width: 1.4),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.fact_check_rounded, size: 17, color: _kSoGreen),
                          const SizedBox(width: 6),
                          Text(
                            'Step 2: Cek Qty ($doneCount/$total)',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: _kSoGreen),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                _NumKeypad(
                  color: _kSoBlue,
                  confirmText: 'CONFIRM COUNT',
                  onDigit: _onDigit,
                  onClear: _onClear,
                  onConfirm: fokus == null ? () {} : () => _onConfirm(doc, fokus),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(KksoDocument doc) {
    final total = doc.items.length;
    final doneCount = doc.items.where((e) => _fisikOf(e) != null).length;

    return Scaffold(
      key: const ValueKey('step2'),
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          Container(
            color: _kSoBlue,
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
            child: Row(
              children: [
                IconButton(onPressed: () => setState(() => _kksoStep = 1), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                const Expanded(child: Text('Step 2: Cek Qty Stock Opname', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900))),
                Text('$doneCount/$total', style: gayaAngka(const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900))),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10), border: Border.all(color: _kSoBlue.withAlpha(80))),
            child: const Text('Hanya input Qty Fisik. Qty Sistem tidak ditampilkan (---).', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _kSoBlue)),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: doc.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (ctx, i) {
                final it = doc.items[i];
                final q = _fisikOf(it);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                  child: Row(
                    children: [
                      Icon(q != null ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: q != null ? _kSoGreen : Colors.grey.shade400, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(it.namaProduk, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
                      Text('Qty Fisik: ${q != null ? "$q" : "-"}', style: gayaAngka(const TextStyle(fontSize: 12, fontWeight: FontWeight.w900))),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _kSoBlue, foregroundColor: Colors.white),
                onPressed: () => setState(() {
                  _aktifKkso = _syncDoc(doc);
                  _kksoStep = 3;
                }),
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text('Cek dan Cetak Selisih', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3(KksoDocument doc) {
    final diffItems = doc.items.where((it) {
      final f = _fisikOf(it);
      return f != null && f != it.stokSistem;
    }).toList();
    final hppSelisih = _sumHppSelisih(doc.items);

    return Scaffold(
      key: const ValueKey('step3'),
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF3F5F8),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Expanded(
              child: _DraftSelisihCard(
                tokoNama: widget.toko?.namaToko ?? 'Nusantara Retail POS',
                itemsSelisih: diffItems,
                totalHppLabel: _fmtRp(hppSelisih),
                onEdit: () {
                  _snapEdit.clear();
                  for (final it in doc.items) { _snapEdit[it.produkId] = _fisikOf(it); }
                  final first = diffItems.isNotEmpty ? diffItems.first : doc.items.first;
                  setState(() {
                    _fokusId = first.produkId;
                    final q = _fisikOf(first);
                    _padBuf = q != null ? '$q' : '';
                    _padReplace = true;
                    _kksoStep = 4;
                  });
                },
                onPrint: () => _cetakSelisihPdf(doc),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => setState(() => _kksoStep = 2), child: const Text('Kembali'))),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                    onPressed: () => setState(() {
                      _aktifKkso = _syncDoc(doc);
                      _kksoStep = 5;
                    }),
                    child: const Text('Fixed Adjust', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep4(KksoDocument doc) {
    final item = doc.items.firstWhere(
      (e) => e.produkId == _fokusId,
      orElse: () => doc.items.first,
    );
    final tercatat = _snapEdit[item.produkId] ?? _fisikOf(item) ?? 0;
    final jumlahBaruStr = _padBuf.isNotEmpty ? _padBuf : '$tercatat';
    final kategoriLabel = item.kategori.trim().isEmpty ? 'Bahan Pokok' : item.kategori.trim();
    final riwayatTerakhir = doc.editLogs.isNotEmpty
        ? doc.editLogs.last
        : 'Terakhir diubah 12 Okt 2024 • 14:22 • oleh Kasir-07';

    return Scaffold(
      key: const ValueKey('step4_perbaiki_hitungan'),
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(8, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          _editCatatanCtrl.clear();
                          setState(() => _kksoStep = 3);
                        },
                        icon: const Icon(Icons.chevron_left_rounded, size: 28, color: Colors.black87),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Perbaiki Hitungan',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text(
                      'Nusantara Retail POS',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(12),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 84,
                          height: 104,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.oil_barrel_rounded, size: 36, color: Color(0xFFD97706)),
                              const SizedBox(height: 4),
                              Text(
                                item.satuan.isNotEmpty ? item.satuan : '1L',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.namaProduk,
                                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.black87),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  kategoriLabel,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'SKU: ${item.kodeSku} • Kategori: $kategoriLabel',
                                style: const TextStyle(fontSize: 11, color: Colors.black54),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Jumlah Tercatat',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54),
                                    ),
                                    Text(
                                      '$tercatat',
                                      style: gayaAngka(const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 1),
                                    child: Icon(Icons.history_rounded, size: 13, color: Colors.black45),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Riwayat edit: $riwayatTerakhir',
                                      style: const TextStyle(fontSize: 10, color: Colors.black45, height: 1.3),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Jumlah Baru',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            jumlahBaruStr,
                            style: gayaAngka(const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black87)),
                          ),
                        ),
                        const Icon(Icons.edit_rounded, size: 22, color: Colors.black45),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Catatan (opsional)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _editCatatanCtrl,
                    decoration: InputDecoration(
                      hintText: 'Tambahkan catatan...',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PerbaikiKeypad(
                    onDigit: _onDigit,
                    onDot: () {},
                    onBackspace: _onClear,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              side: BorderSide(color: Colors.grey.shade400),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              _editCatatanCtrl.clear();
                              setState(() => _kksoStep = 3);
                            },
                            child: const Text('Batal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              _onConfirm(doc, item, editMode: true);
                              final updated = _syncDoc(_aktifKkso ?? doc);
                              widget.onSimpanKkso([
                                updated,
                                ...widget.daftarKkso.where((d) => d.id != updated.id),
                              ]);
                              setState(() => _aktifKkso = updated);
                            },
                            child: const Text('Simpan Perubahan', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFEA580C),
                        side: const BorderSide(color: Color(0xFFEA580C), width: 1.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        final updated = _syncDoc(_aktifKkso ?? doc);
                        setState(() {
                          _aktifKkso = updated;
                          _kksoStep = 3;
                        });
                      },
                      icon: const Icon(Icons.print_outlined, size: 19, color: Color(0xFFEA580C)),
                      label: const Text(
                        'Cetak Ulang Selisih HPP',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep5(KksoDocument doc) {
    final origRp = _sumOrigHpp(doc.items);
    final adjRp = _sumAdjHpp(doc.items);
    final validPin = _pinSisCtrl.text.trim() == _kPinSisValid;

    return Scaffold(
      key: const ValueKey('step5'),
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF5F7FA),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(color: _kSoBlue, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                IconButton(onPressed: () => setState(() => _kksoStep = 3), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                const Expanded(child: Text('Step 5 • Fixed Adjust', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('Original Price', style: TextStyle(fontSize: 11, color: Colors.black54)),
                      Text(_fmtRp(origRp), style: gayaAngka(const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded),
                Expanded(
                  child: Column(
                    children: [
                      const Text('Adjusted Price', style: TextStyle(fontSize: 11, color: _kSoGreen, fontWeight: FontWeight.w800)),
                      Text(_fmtRp(adjRp), style: gayaAngka(const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _kSoGreen))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pinSisCtrl,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() => _pinErr = false),
            decoration: InputDecoration(
              labelText: 'PIN 6 Digit SIS (default: 123456)',
              errorText: _pinErr ? 'PIN SIS salah' : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: validPin ? const Color(0xFFB91C1C) : Colors.grey.shade400, foregroundColor: Colors.white),
              onPressed: (!validPin || _busyAdjust) ? null : () => _prosesFixedAdjust(doc),
              child: Text(_busyAdjust ? 'MEMPROSES...' : 'FIXED ADJUST', style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  bool get _isOwnerOrSis {
    final role = (widget.currentStaff?.role.toString() ?? '').toLowerCase();
    return role.contains('owner') || role.contains('sis') || role.contains('admin') || role.isEmpty;
  }
  final Map<String, int> _doubleCountMap = {};
  String _alasanTerpilihKkso = 'Selisih Hitung Rak';
  static const List<String> _daftarAlasanKkso = [
    'Selisih Hitung Rak',
    'Barang Rusak / Expired',
    'Retur / Koreksi Nota',
    'Pencurian / Susut',
  ];
  final TextEditingController _catatanReviewKksoCtrl = TextEditingController();
  final TextEditingController _petugasDoubleCountCtrl = TextEditingController();
  // ignore: unused_element
  Widget _buildKksoPilihanAwal(AppThemeConfig t) => _buildStep0();
  // ignore: unused_element
  Widget _buildKksoHitungBorongan(AppThemeConfig t, KksoDocument doc) => _buildStep1(doc);

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

  // ignore: unused_element
  Widget _buildKksoReviewOwner(AppThemeConfig t, KksoDocument doc) {
    

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
    if (_kksoStep == 6 && _aktifKkso != null) return _buildStep6(_aktifKkso!);

    final t = widget.tema;
    final activeDoc = _aktifKkso;
    if (_modeSub == 1 && activeDoc != null && _kksoStep == 4) {
      return _buildStep4(activeDoc);
    }
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
      return _buildStep0();
    }
    if (_kksoStep == 2) return _buildStep2(doc);
    if (_kksoStep == 3) return _buildStep3(doc);
    if (_kksoStep == 4) return _buildStep4(doc);
    if (_kksoStep == 5) return _buildStep5(doc);
    if (_kksoStep == 6) return _buildStep6(doc);
    if (_kksoStep == 1) return _buildStep1(doc);
    if (doc.status == KksoStatus.hitung) {
      return _buildStep1(doc);
    }
    return _buildStep3(doc);
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


class _JenisTile extends StatelessWidget {
  final String title;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  const _JenisTile({required this.title, required this.sub, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const g = Color(0xFF0E5A3E);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? g : Colors.grey.shade300, width: selected ? 1.7 : 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                  Text(sub, style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
                ],
              ),
            ),
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: selected ? g : Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _DraftSelisihCard extends StatelessWidget {
  final String tokoNama;
  final List<KksoItem> itemsSelisih;
  final String totalHppLabel;
  final VoidCallback onEdit;
  final VoidCallback onPrint;

  const _DraftSelisihCard({
    required this.tokoNama,
    required this.itemsSelisih,
    required this.totalHppLabel,
    required this.onEdit,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    const b = Color(0xFF1E40AF);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cetak Selisih • Ultra Blind Count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: b)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
                child: const Text('DRAFT • BUKAN ADJUST', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFFB91C1C))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(tokoNama, style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w700)),
          const Divider(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: itemsSelisih.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (ctx, i) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFFAFAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(itemsSelisih[i].namaProduk, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                    const Text('Has Difference', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10), border: Border.all(color: b.withAlpha(100))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total HPP Selisih', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
                Text(totalHppLabel, style: gayaAngka(const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: b))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: onEdit, child: const Text('Edit'))),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: b, foregroundColor: Colors.white),
                  onPressed: onPrint,
                  child: const Text('Print', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumKeypad extends StatelessWidget {
  final Color color;
  final String confirmText;
  final void Function(String) onDigit;
  final VoidCallback onClear;
  final VoidCallback onConfirm;

  const _NumKeypad({required this.color, required this.confirmText, required this.onDigit, required this.onClear, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', 'OK'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int r = 0; r < rows.length; r++) ...[
          Row(
            children: [
              for (int c = 0; c < rows[r].length; c++) ...[
                Expanded(child: _btn(rows[r][c])),
                if (c < rows[r].length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
          if (r < rows.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _btn(String k) {
    final isC = k == 'C';
    final isOk = k == 'OK';
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => isC ? onClear() : (isOk ? onConfirm() : onDigit(k)),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isOk ? color : (isC ? const Color(0xFFFEE2E2) : const Color(0xFFF4F7F5)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isOk ? color : Colors.black12),
        ),
        alignment: Alignment.center,
        child: Text(
          isOk ? confirmText : k,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: gayaAngka(TextStyle(fontSize: isOk ? 11.5 : 22, fontWeight: FontWeight.w900, color: isOk ? Colors.white : (isC ? const Color(0xFFB91C1C) : Colors.black87))),
        ),
      ),
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


class CustomKeypad extends StatelessWidget {
  final Color primaryColor;
  final void Function(String digit) onDigit;
  final VoidCallback onClear;
  final VoidCallback onEnter;

  const CustomKeypad({
    super.key,
    required this.primaryColor,
    required this.onDigit,
    required this.onClear,
    required this.onEnter,
  });

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', 'ENTER'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int r = 0; r < rows.length; r++) ...[
          Row(
            children: [
              for (int c = 0; c < rows[r].length; c++) ...[
                Expanded(
                  child: _buildKey(rows[r][c]),
                ),
                if (c < rows[r].length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
          if (r < rows.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildKey(String label) {
    final isClear = label == 'C';
    final isEnter = label == 'ENTER';

    final Color bgColor = isEnter
        ? primaryColor
        : (isClear ? const Color(0xFFFEE2E2) : const Color(0xFFF4F7F5));
    final Color fgColor = isEnter
        ? Colors.white
        : (isClear ? const Color(0xFFB91C1C) : Colors.black87);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isClear) {
            onClear();
          } else if (isEnter) {
            onEnter();
          } else {
            onDigit(label);
          }
        },
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isEnter ? primaryColor : Colors.black12,
              width: 1.1,
            ),
          ),
          alignment: Alignment.center,
          child: isEnter
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.keyboard_return_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 4),
                    Text(
                      'Enter',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ],
                )
              : Text(
                  label,
                  style: gayaAngka(
                    TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: fgColor,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _PerbaikiKeypad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onDot;
  final VoidCallback onBackspace;

  const _PerbaikiKeypad({
    required this.onDigit,
    required this.onDot,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', 'DEL'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int r = 0; r < rows.length; r++) ...[
          Row(
            children: [
              for (int c = 0; c < rows[r].length; c++) ...[
                Expanded(child: _tile(rows[r][c])),
                if (c < rows[r].length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
          if (r < rows.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _tile(String keyLabel) {
    final isDel = keyLabel == 'DEL';
    final isDot = keyLabel == '.';

    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(14),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (isDel) {
              onBackspace();
            } else if (isDot) {
              onDot();
            } else {
              onDigit(keyLabel);
            }
          },
          child: Center(
            child: isDel
                ? const Icon(Icons.backspace_outlined, size: 22, color: Colors.black87)
                : Text(
                    keyLabel,
                    style: gayaAngka(
                      const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.black87),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
