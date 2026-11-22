import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/pdf_berita_acara.dart';
import '../../models/pos_models.dart';
import '../../models/so_models.dart';
import '../../widgets/pos_components.dart';

class StockOpnameView extends StatefulWidget {
  final AppThemeConfig tema;
  final PengaturanToko? toko;
  final AkunStaff currentStaff;
  final List<AkunStaff> daftarStaff;
  final List<Produk> daftarProduk;
  final void Function({
    required Produk produk,
    required String tipe,
    required int perubahan,
    required String keterangan,
  }) onMutasiStok;

  const StockOpnameView({
    super.key,
    required this.tema,
    this.toko,
    required this.currentStaff,
    required this.daftarStaff,
    required this.daftarProduk,
    required this.onMutasiStok,
  });

  @override
  State<StockOpnameView> createState() => _StockOpnameViewState();
}

class _StockOpnameViewState extends State<StockOpnameView> {
  static const String _keyDraftSO = 'pos_so_blind_draft_v2';
  static const String _keyRiwayatSO = 'pos_so_blind_riwayat_v2';

  final TextEditingController _cariCtrl = TextEditingController();

  SesiStockOpname? _sesiAktif;
  List<SesiStockOpname> _riwayatSO = [];

  String _filterButa = 'Semua';
  String _filterKategoriSO = 'Semua';
  bool _modeScanTambahCepat = true;
  bool _sedangMembuatPdf = false;
  String _lastScanInfo = '';

  @override
  void initState() {
    super.initState();
    _muatDataSO();
  }

  @override
  void dispose() {
    _cariCtrl.dispose();
    super.dispose();
  }

  Future<void> _muatDataSO() async {
    final prefs = await SharedPreferences.getInstance();
    final draftRaw = prefs.getString(_keyDraftSO);
    final riwayatRaw = prefs.getString(_keyRiwayatSO);

    if (!mounted) return;
    setState(() {
      if (draftRaw != null && draftRaw.isNotEmpty) {
        try {
          _sesiAktif = SesiStockOpname.fromMap(
            jsonDecode(draftRaw) as Map<String, dynamic>,
          );
        } catch (_) {
          _sesiAktif = null;
        }
      }
      _riwayatSO = SesiStockOpname.decodeList(riwayatRaw);
    });
  }

  Future<void> _simpanDraftSO(SesiStockOpname? sesi) async {
    final prefs = await SharedPreferences.getInstance();
    if (sesi == null) {
      await prefs.remove(_keyDraftSO);
    } else {
      await prefs.setString(_keyDraftSO, jsonEncode(sesi.toMap()));
    }
  }

  Future<void> _simpanRiwayatSO(List<SesiStockOpname> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRiwayatSO, SesiStockOpname.encodeList(list));
  }

  String _buatNomorDokumenSO() {
    final now = DateTime.now();
    final tgl =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final urut = (_riwayatSO.length + 1).toString().padLeft(3, '0');
    return 'SO-$tgl-$urut';
  }

  void _bukaDialogMulaiSO() {
    final t = widget.tema;
    String jenisCakupan = 'Full SO Toko';
    String kategoriTerpilih = 'Makanan';
    final catatanCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          List<Produk> kandidat;
          String labelCakupan;
          if (jenisCakupan == 'Per Kategori') {
            kandidat = widget.daftarProduk
                .where((p) => p.kategori == kategoriTerpilih)
                .toList();
            labelCakupan = 'Partial SO: $kategoriTerpilih';
          } else if (jenisCakupan == 'Stok Menipis') {
            kandidat = widget.daftarProduk
                .where((p) => p.stok <= p.minStokAlert)
                .toList();
            labelCakupan = 'Cycle Count (Stok Kritis)';
          } else {
            kandidat = List<Produk>.from(widget.daftarProduk);
            labelCakupan = 'Grand / Full SO Toko';
          }

          return AlertDialog(
            backgroundColor: t.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(t.radius + 2),
            ),
            title: Row(
              children: [
                Icon(Icons.visibility_off_rounded, color: t.primaryColor),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Mulai Stock Opname',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: t.primaryColor.withAlpha(22),
                      borderRadius: BorderRadius.circular(t.radius),
                      border: Border.all(color: t.primaryColor.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_person_outlined,
                          size: 18,
                          color: t.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Audit Fisik Aktif: Jumlah stok sistem dikunci sementara sampai hitungan fisik selesai.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: t.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: jenisCakupan,
                    decoration: const InputDecoration(
                      labelText: 'Jenis & Cakupan Audit',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Full SO Toko',
                        child: Text('Grand / Full SO (Seluruh Produk)'),
                      ),
                      DropdownMenuItem(
                        value: 'Per Kategori',
                        child: Text('Partial SO (Per Kategori / Rak)'),
                      ),
                      DropdownMenuItem(
                        value: 'Stok Menipis',
                        child: Text('Cycle Count (Item Stok Menipis)'),
                      ),
                    ],
                    onChanged: (v) =>
                        setDlg(() => jenisCakupan = v ?? 'Full SO Toko'),
                  ),
                  if (jenisCakupan == 'Per Kategori') ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: kategoriTerpilih,
                      decoration: const InputDecoration(
                        labelText: 'Pilih Kategori / Gondola',
                        border: OutlineInputBorder(),
                      ),
                      items: kKategoriProduk
                          .where((k) => k != 'Semua')
                          .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                          .toList(),
                      onChanged: (v) =>
                          setDlg(() => kategoriTerpilih = v ?? 'Makanan'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: t.inputColor,
                      borderRadius: BorderRadius.circular(t.radius),
                      border: Border.all(color: t.borderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Snapshot Target SKU',
                          style: TextStyle(fontSize: 12, color: t.textSecondary),
                        ),
                        Text(
                          '${kandidat.length} SKU',
                          style: gayaAngka(
                            TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: t.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: catatanCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Sesi / Shift (Opsional)',
                      hintText: 'Contoh: SO Mingguan Shift Pagi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: t.primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: kandidat.isEmpty
                    ? null
                    : () {
                        final now = DateTime.now();
                        final itemsSO = kandidat
                            .map(
                              (p) => ItemHitunganSO(
                                produkId: p.id,
                                kodeSku: p.kodeSku,
                                namaProduk: p.nama,
                                kategori: p.kategori,
                                satuan: p.satuan,
                                stokSistem: p.stok,
                                hargaModal: p.hargaModal,
                                hargaJual: p.hargaJual,
                              ),
                            )
                            .toList();

                        final sesiBaru = SesiStockOpname(
                          id: 'so_${now.millisecondsSinceEpoch}',
                          nomorDokumen: _buatNomorDokumenSO(),
                          cakupan: labelCakupan,
                          operatorNama: widget.currentStaff.nama,
                          waktuMulai: now,
                          catatanUmum: catatanCtrl.text.trim(),
                          items: itemsSO,
                        );

                        Navigator.pop(ctx);
                        setState(() {
                          _sesiAktif = sesiBaru;
                          _filterButa = 'Semua';
                          _filterKategoriSO = 'Semua';
                          _lastScanInfo = '';
                          _cariCtrl.clear();
                        });
                        _simpanDraftSO(sesiBaru);
                      },
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Mulai Hitung Fisik'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _updateItemSO(
    String produkId, {
    int? qtyToko,
    int? qtyGudang,
    bool resetFisik = false,
    bool tandaiRecount = false,
    String? alasanSelisih,
    String? kondisiFisik,
    String? catatan,
  }) {
    final sesi = _sesiAktif;
    if (sesi == null) return;

    final updatedItems = sesi.items.map((item) {
      if (item.produkId != produkId) return item;
      return item.copyWith(
        qtyToko: qtyToko,
        qtyGudang: qtyGudang,
        resetFisik: resetFisik,
        sudahRecount: tandaiRecount ? true : item.sudahRecount,
        alasanSelisih: alasanSelisih,
        kondisiFisik: kondisiFisik,
        catatan: catatan,
        waktuHitung: DateTime.now(),
      );
    }).toList();

    final sesiBaru = sesi.copyWith(items: updatedItems);
    setState(() => _sesiAktif = sesiBaru);
    _simpanDraftSO(sesiBaru);
  }

  void _prosesScanBarcodeSO(String input) {
    final sesi = _sesiAktif;
    final kode = input.trim().toLowerCase();
    if (sesi == null || kode.isEmpty) return;

    final idx = sesi.items.indexWhere(
      (e) =>
          e.kodeSku.toLowerCase() == kode || e.namaProduk.toLowerCase() == kode,
    );
    if (idx == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SKU "$input" tidak ada dalam daftar sesi SO ini.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final item = sesi.items[idx];
    HapticFeedback.mediumImpact();
    _cariCtrl.clear();

    if (_modeScanTambahCepat && !sesi.terkunciUntukAudit) {
      final tokoBaru = (item.qtyToko ?? 0) + 1;
      final gudangSekarang = item.qtyGudang ?? 0;
      _updateItemSO(
        item.produkId,
        qtyToko: tokoBaru,
        qtyGudang: gudangSekarang,
      );
      setState(() {
        _lastScanInfo =
            'Scan +1: ${item.namaProduk} → Total Fisik: ${tokoBaru + gudangSekarang} ${item.satuan}';
      });
    } else {
      setState(() {});
      _bukaModalHitungFisik(
        item,
        isRecount: sesi.terkunciUntukAudit,
      );
    }
  }

  void _bukaModalHitungFisik(
    ItemHitunganSO item, {
    bool isRecount = false,
  }) {
    final t = widget.tema;
    final tokoCtrl = TextEditingController(
      text: item.qtyToko != null ? item.qtyToko.toString() : '0',
    );
    final gudangCtrl = TextEditingController(
      text: item.qtyGudang != null ? item.qtyGudang.toString() : '0',
    );
    final dusCtrl = TextEditingController(text: '1');
    final isiPerDusCtrl = TextEditingController(text: '24');
    final catatanCtrl = TextEditingController(text: item.catatan);

    String kondisi = item.kondisiFisik;
    bool kalkulatorDusTerbuka = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.radius + 6)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final qtyToko = int.tryParse(tokoCtrl.text) ?? 0;
          final qtyGudang = int.tryParse(gudangCtrl.text) ?? 0;
          final totalFisik = qtyToko + qtyGudang;

          final jmlDus = int.tryParse(dusCtrl.text) ?? 0;
          final isiDus = int.tryParse(isiPerDusCtrl.text) ?? 0;
          final hasilKarton = jmlDus * isiDus;

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(110),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: warnaKategori(item.kategori).withAlpha(28),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          inisialProduk(item.namaProduk),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: warnaKategori(item.kategori),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.namaProduk,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'SKU: ${item.kodeSku} • ${item.kategori} • Satuan: ${item.satuan}',
                              style: TextStyle(
                                fontSize: 11,
                                color: t.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(
                        label: isRecount ? 'HITUNG ULANG' : 'INPUT FISIK',
                        color: isRecount ? t.warningColor : t.primaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: t.primaryColor.withAlpha(22),
                      borderRadius: BorderRadius.circular(t.radius),
                      border: Border.all(color: t.primaryColor.withAlpha(90)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL FISIK DITEMUKAN',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                            Text(
                              'Rak Toko ($qtyToko) + Gudang ($qtyGudang)',
                              style: gayaAngka(
                                TextStyle(
                                  fontSize: 11,
                                  color: t.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$totalFisik ${item.satuan}',
                          style: gayaAngka(
                            TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: t.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _KartuInputLokasi(
                    tema: t,
                    judul: 'Area 1: Rak Display / Gondola Toko',
                    ikon: Icons.storefront_outlined,
                    controller: tokoCtrl,
                    onChanged: () => setModal(() {}),
                    onDelta: (d) {
                      final baru = ((int.tryParse(tokoCtrl.text) ?? 0) + d)
                          .clamp(0, 999999);
                      tokoCtrl.text = baru.toString();
                      setModal(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  _KartuInputLokasi(
                    tema: t,
                    judul: 'Area 2: Gudang / Stok Belakang',
                    ikon: Icons.warehouse_outlined,
                    controller: gudangCtrl,
                    onChanged: () => setModal(() {}),
                    onDelta: (d) {
                      final baru = ((int.tryParse(gudangCtrl.text) ?? 0) + d)
                          .clamp(0, 999999);
                      gudangCtrl.text = baru.toString();
                      setModal(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: dekorasiKartu(t, colorOverride: t.inputColor),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => setModal(
                            () => kalkulatorDusTerbuka = !kalkulatorDusTerbuka,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calculate_outlined,
                                  size: 18,
                                  color: t.accentColor,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Kalkulator Hitung Karton / Dus',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Icon(
                                  kalkulatorDusTerbuka
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (kalkulatorDusTerbuka)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: dusCtrl,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setModal(() {}),
                                        decoration: const InputDecoration(
                                          labelText: 'Jumlah Dus',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(
                                        '×',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: isiPerDusCtrl,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setModal(() {}),
                                        decoration: InputDecoration(
                                          labelText: 'Isi (${item.satuan}/dus)',
                                          isDense: true,
                                          border: const OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: hasilKarton <= 0
                                            ? null
                                            : () {
                                                final skrg = int.tryParse(
                                                        tokoCtrl.text) ??
                                                    0;
                                                tokoCtrl.text =
                                                    (skrg + hasilKarton)
                                                        .toString();
                                                setModal(() {});
                                              },
                                        child: Text(
                                          '+$hasilKarton ke Toko',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.tonal(
                                        onPressed: hasilKarton <= 0
                                            ? null
                                            : () {
                                                final skrg = int.tryParse(
                                                        gudangCtrl.text) ??
                                                    0;
                                                gudangCtrl.text =
                                                    (skrg + hasilKarton)
                                                        .toString();
                                                setModal(() {});
                                              },
                                        child: Text(
                                          '+$hasilKarton ke Gudang',
                                          style: const TextStyle(fontSize: 11),
                                        ),
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
                  const SizedBox(height: 10),
                  const Text(
                    'Kondisi Fisik Barang:',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: kKondisiFisikSO.map((k) {
                      final aktif = kondisi == k;
                      final warna = k == 'Normal'
                          ? t.successColor
                          : (k == 'Mendekati ED'
                              ? t.warningColor
                              : t.dangerColor);
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setModal(() => kondisi = k),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: aktif ? warna : t.surfaceColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: aktif ? warna : t.borderColor,
                              ),
                            ),
                            child: Text(
                              k,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: aktif ? Colors.white : t.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: catatanCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Lokasi Rak / Tanggal Expired (Opsional)',
                      hintText: 'Misal: Rak C2 baris atas / ED 12-2026',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (item.sudahDihitung && !isRecount)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: t.dangerColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 13,
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _updateItemSO(item.produkId, resetFisik: true);
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: t.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(t.radius),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.pop(ctx);
                            _updateItemSO(
                              item.produkId,
                              qtyToko: qtyToko,
                              qtyGudang: qtyGudang,
                              tandaiRecount: isRecount,
                              kondisiFisik: kondisi,
                              catatan: catatanCtrl.text.trim(),
                            );
                          },
                          icon: const Icon(Icons.check_circle_rounded, size: 19),
                          label: Text(
                            isRecount
                                ? 'Simpan Hasil Hitung Ulang ($totalFisik)'
                                : 'Simpan Hitungan Fisik ($totalFisik)',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
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

  void _kunciHitunganDanBukaAudit() {
    final sesi = _sesiAktif;
    if (sesi == null) return;
    final t = widget.tema;

    if (sesi.jumlahDihitung == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hitung minimal 1 produk terlebih dahulu sebelum mengunci.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final belumHitung = sesi.totalSku - sesi.jumlahDihitung;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surfaceColor,
        title: const Text(
          'Kunci Hitungan Fisik & Buka Data Sistem?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Text(
          belumHitung > 0
              ? 'Kamu telah menghitung ${sesi.jumlahDihitung} dari ${sesi.totalSku} SKU ($belumHitung SKU belum dihitung).\n\nSetelah dikunci, angka hitungan awal akan direkam dan stok sistem akan dibuka untuk verifikasi selisih & hitung ulang.'
              : 'Seluruh ${sesi.totalSku} SKU sudah selesai dihitung.\n\nSetelah dikunci, stok sistem akan dibuka untuk audit selisih dan penerbitan Berita Acara.',
          style: const TextStyle(fontSize: 13, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Lanjut Hitung'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: t.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final itemsTerkunci = sesi.items.map((item) {
                if (!item.sudahDihitung) return item;
                return item.copyWith(
                  hitunganPertama: item.hitunganPertama ?? item.stokFisik,
                );
              }).toList();

              final sesiAudit = sesi.copyWith(
                terkunciUntukAudit: true,
                items: itemsTerkunci,
              );

              Navigator.pop(ctx);
              setState(() => _sesiAktif = sesiAudit);
              _simpanDraftSO(sesiAudit);
            },
            child: const Text('Kunci & Buka Audit'),
          ),
        ],
      ),
    );
  }

  Future<void> _sahkanBeritaAcaraSO({
    required bool nolkanYangBelumDihitung,
  }) async {
    final sesi = _sesiAktif;
    if (sesi == null || _sedangMembuatPdf) return;
    final t = widget.tema;

    final itemsFinal = sesi.items.map((item) {
      if (!item.sudahDihitung && nolkanYangBelumDihitung) {
        return item.copyWith(
          qtyToko: 0,
          qtyGudang: 0,
          hitunganPertama: 0,
          alasanSelisih: 'Hilang / Shrinkage',
          catatan: 'Tidak ditemukan saat Full SO (Nol otomatis)',
          waktuHitung: DateTime.now(),
        );
      }
      return item;
    }).toList();

    final sesiSiapSah = sesi.copyWith(items: itemsFinal);
    final listSelisih = sesiSiapSah.items.where((e) => e.adaSelisih).toList();

    String approver = widget.currentStaff.nama;
    if (!widget.currentStaff.isStoreSystem && listSelisih.isNotEmpty) {
      final admin = await tampilkanOtorisasiSis(
        context: context,
        tema: t,
        daftarStaff: widget.daftarStaff,
        judul: 'Otorisasi Berita Acara SO',
        keterangan:
            'Terdapat ${listSelisih.length} SKU berselisih. Masukkan PIN Store Information System untuk menyesuaikan stok sistem.',
      );
      if (admin == null) return;
      approver = admin.nama;
    }

    setState(() => _sedangMembuatPdf = true);

    final sesiSelesai = sesiSiapSah.copyWith(
      approverNama: approver,
      waktuSelesai: DateTime.now(),
      selesai: true,
    );

    for (final item in sesiSelesai.items) {
      if (item.adaSelisih) {
        final pIdx =
            widget.daftarProduk.indexWhere((p) => p.id == item.produkId);
        if (pIdx != -1) {
          widget.onMutasiStok(
            produk: widget.daftarProduk[pIdx],
            tipe: 'Opname',
            perubahan: item.selisihQty,
            keterangan:
                '${sesiSelesai.nomorDokumen} • ${item.alasanSelisih}${item.sudahRecount ? ' (Recount)' : ''}',
          );
        }
      }
    }

    final riwayatBaru = [sesiSelesai, ..._riwayatSO];
    setState(() {
      _sesiAktif = null;
      _riwayatSO = riwayatBaru;
    });
    await _simpanDraftSO(null);
    await _simpanRiwayatSO(riwayatBaru);

    // Otomatis generate & unduh/bagikan PDF Berita Acara
    try {
      await unduhAtauBagikanPdfBA(
        sesi: sesiSelesai,
        tampilkanHpp: widget.currentStaff.isStoreSystem,
        toko: widget.toko,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF Berita Acara BA_${sesiSelesai.nomorDokumen}.pdf otomatis dibuat.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // Tetap lanjut buka preview detail Berita Acara jika share sheet ditutup
    } finally {
      if (mounted) {
        setState(() => _sedangMembuatPdf = false);
        _tampilkanDetailBeritaAcara(sesiSelesai);
      }
    }
  }

  void _tampilkanDetailBeritaAcara(SesiStockOpname sesi) {
    final t = widget.tema;
    final isAdmin = widget.currentStaff.isStoreSystem;
    final listSelisih = sesi.items.where((e) => e.adaSelisih).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.radius + 4)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (ctx, scrollCtrl) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(110),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: t.successColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: t.successColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Berita Acara ${sesi.nomorDokumen}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${sesi.cakupan} • ${formatTanggalWaktu(sesi.waktuSelesai ?? sesi.waktuMulai)}',
                          style:
                              TextStyle(fontSize: 11, color: t.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label:
                        'AKURASI ${sesi.persentaseAkurasi.toStringAsFixed(0)}%',
                    color: sesi.persentaseAkurasi >= 95
                        ? t.successColor
                        : t.warningColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      tema: t,
                      label: 'SKU Dihitung',
                      value: '${sesi.jumlahDihitung}/${sesi.totalSku}',
                      sublabel:
                          '${sesi.jumlahCocok} cocok • ${sesi.jumlahSelisih} selisih',
                      valueColor: t.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetricTile(
                      tema: t,
                      label: 'Total Fisik di Rak',
                      value: '${sesi.totalUnitFisik} unit',
                      sublabel: 'Toko + Gudang',
                      valueColor: t.accentColor,
                    ),
                  ),
                ],
              ),
              if (isAdmin) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: MetricTile(
                        tema: t,
                        label: 'Shrinkage (-) HPP',
                        value: '-${formatRupiah(sesi.totalMinusHpp)}',
                        sublabel: '${sesi.totalMinusQty} unit hilang/rusak',
                        valueColor: sesi.totalMinusHpp > 0
                            ? t.dangerColor
                            : t.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MetricTile(
                        tema: t,
                        label: 'Net Selisih Aset',
                        value:
                            '${sesi.netSelisihHpp >= 0 ? '+' : ''}${formatRupiah(sesi.netSelisihHpp)}',
                        sublabel: 'Surplus +${formatRupiah(sesi.totalPlusHpp)}',
                        valueColor: sesi.netSelisihHpp >= 0
                            ? t.successColor
                            : t.dangerColor,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: dekorasiKartu(t, colorOverride: t.inputColor),
                child: Column(
                  children: [
                    _BarisBA('Operator Stock Opname', sesi.operatorNama),
                    if (sesi.approverNama.isNotEmpty)
                      _BarisBA('Otorisasi & Pengesahan', sesi.approverNama),
                    _BarisBA(
                      'Durasi Pelaksanaan',
                      _hitungDurasi(sesi.waktuMulai, sesi.waktuSelesai),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                listSelisih.isEmpty
                    ? 'Hasil Audit: 100% Sesuai Stok Sistem'
                    : 'Rincian SKU Berselisih (${listSelisih.length} Item):',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: listSelisih.isEmpty
                    ? Center(
                        child: Text(
                          'Seluruh item yang dihitung cocok dengan stok sistem.',
                          style:
                              TextStyle(fontSize: 12, color: t.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        itemCount: listSelisih.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (ctx, idx) {
                          final item = listSelisih[idx];
                          final plus = item.selisihQty > 0;
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: dekorasiKartu(t),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.namaProduk,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                    if (item.sudahRecount)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(right: 5),
                                        child: StatusBadge(
                                          label: 'RECOUNT',
                                          color: t.accentColor,
                                        ),
                                      ),
                                    StatusBadge(
                                      label:
                                          '${plus ? '+' : ''}${item.selisihQty} ${item.satuan}',
                                      color: plus
                                          ? t.accentColor
                                          : t.dangerColor,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Sistem: ${item.stokSistem} • Fisik: ${item.stokFisik} (Toko: ${item.qtyToko ?? 0}, Gudang: ${item.qtyGudang ?? 0})',
                                  style: gayaAngka(
                                    TextStyle(
                                      fontSize: 11,
                                      color: t.textSecondary,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Alasan: ${item.alasanSelisih}${isAdmin ? ' • Nilai HPP: ${plus ? '+' : ''}${formatRupiah(item.selisihNilaiHpp)}' : ''}',
                                  style: gayaAngka(
                                    TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: t.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 10),
              // Baris Utama: Unduh PDF & Pratinjau Cetak PDF
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: t.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(t.radius),
                        ),
                      ),
                      onPressed: () => unduhAtauBagikanPdfBA(
                        sesi: sesi,
                        tampilkanHpp: isAdmin,
                        toko: widget.toko,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: const Text(
                        'Unduh PDF',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(t.radius),
                        ),
                      ),
                      onPressed: () => pratinjauCetakPdfBA(
                        sesi: sesi,
                        tampilkanHpp: isAdmin,
                        toko: widget.toko,
                      ),
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text(
                        'Preview / Print',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Baris Sekunder: Salin Teks & Export CSV
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final teks = sesi.buatTeksBeritaAcara(
                          tampilkanHpp: isAdmin,
                        );
                        await Clipboard.setData(ClipboardData(text: teks));
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Teks Berita Acara disalin ke clipboard.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text(
                        'Salin Teks',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final csv = sesi.buatCsvBeritaAcara();
                        await Clipboard.setData(ClipboardData(text: csv));
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('CSV Detail Stock Opname disalin.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.table_chart_outlined, size: 16),
                      label: const Text(
                        'Salin CSV',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _hitungDurasi(DateTime mulai, DateTime? selesai) {
    final akhir = selesai ?? DateTime.now();
    final diff = akhir.difference(mulai);
    if (diff.inMinutes < 1) return '< 1 menit';
    if (diff.inHours < 1) return '${diff.inMinutes} menit';
    return '${diff.inHours} jam ${diff.inMinutes % 60} menit';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tema;
    final sesi = _sesiAktif;

    if (sesi == null) {
      return _buildBerandaSO(t);
    }

    if (sesi.terkunciUntukAudit) {
      return _buildTahapRekonsiliasiDanRecount(t, sesi);
    }

    return _buildTahapHitungButa(t, sesi);
  }

  Widget _buildBerandaSO(AppThemeConfig t) {
    final isAdmin = widget.currentStaff.isStoreSystem;
    final rataAkurasi = _riwayatSO.isEmpty
        ? 100.0
        : _riwayatSO.fold<double>(0, (s, e) => s + e.persentaseAkurasi) /
            _riwayatSO.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                t.primaryColor,
                t.primaryColor.withAlpha(215),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(t.radius + 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.visibility_off_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SISTEM AUDIT STOCK OPNAME',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                        Text(
                          'Audit fisik multi-area (Toko + Gudang) & auto PDF Berita Acara',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _MiniStatBanner(
                    label: 'Total Audit Selesai',
                    value: '${_riwayatSO.length} Dokumen',
                  ),
                  const SizedBox(width: 10),
                  _MiniStatBanner(
                    label: 'Rata-rata Akurasi',
                    value: '${rataAkurasi.toStringAsFixed(1)}%',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: t.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(t.radius),
                  ),
                ),
                onPressed: _bukaDialogMulaiSO,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 19),
                label: const Text(
                  'MULAI SESI STOCK OPNAME',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionHeader(
          title: 'Arsip Berita Acara Stock Opname',
          subtitle: 'Ketuk dokumen untuk pratinjau atau unduh ulang PDF BA',
        ),
        const SizedBox(height: 8),
        if (_riwayatSO.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: dekorasiKartu(t),
            child: Column(
              children: [
                Icon(
                  Icons.inventory_outlined,
                  size: 36,
                  color: t.textSecondary.withAlpha(110),
                ),
                const SizedBox(height: 8),
                Text(
                  'Belum ada Berita Acara Stock Opname.\nMulai sesi baru untuk mengaudit stok rak & gudang.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: t.textSecondary),
                ),
              ],
            ),
          )
        else
          ..._riwayatSO.map(
            (so) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TactilePress(
                onTap: () => _tampilkanDetailBeritaAcara(so),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: dekorasiKartu(t),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: (so.persentaseAkurasi >= 95
                                  ? t.successColor
                                  : t.warningColor)
                              .withAlpha(24),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (so.persentaseAkurasi >= 95
                                    ? t.successColor
                                    : t.warningColor)
                                .withAlpha(90),
                          ),
                        ),
                        child: Text(
                          '${so.persentaseAkurasi.toStringAsFixed(0)}%',
                          style: gayaAngka(
                            TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: so.persentaseAkurasi >= 95
                                  ? t.successColor
                                  : t.warningColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  so.nomorDokumen,
                                  style: gayaAngka(
                                    const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                StatusBadge(
                                  label: so.jumlahSelisih == 0
                                      ? 'COCOK'
                                      : '${so.jumlahSelisih} SELISIH',
                                  color: so.jumlahSelisih == 0
                                      ? t.successColor
                                      : t.warningColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${so.cakupan} • ${so.jumlahDihitung}/${so.totalSku} SKU',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Oleh: ${so.operatorNama} • ${formatTanggalWaktu(so.waktuSelesai ?? so.waktuMulai)}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: t.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Unduh PDF Berita Acara',
                        onPressed: () => unduhAtauBagikanPdfBA(
                          sesi: so,
                          tampilkanHpp: isAdmin,
                          toko: widget.toko,
                        ),
                        icon: Icon(
                          Icons.picture_as_pdf_rounded,
                          color: t.primaryColor,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTahapHitungButa(AppThemeConfig t, SesiStockOpname sesi) {
    final query = _cariCtrl.text.trim().toLowerCase();
    final progres =
        sesi.totalSku > 0 ? (sesi.jumlahDihitung / sesi.totalSku) : 0.0;

    final listItem = sesi.items.where((item) {
      final cocokKat =
          _filterKategoriSO == 'Semua' || item.kategori == _filterKategoriSO;
      final cocokCari = query.isEmpty ||
          item.namaProduk.toLowerCase().contains(query) ||
          item.kodeSku.toLowerCase().contains(query);
      if (!cocokKat || !cocokCari) return false;

      if (_filterButa == 'Belum Hitung') return !item.sudahDihitung;
      if (_filterButa == 'Sudah Hitung') return item.sudahDihitung;
      if (_filterButa == 'Kondisi Khusus') {
        return item.sudahDihitung && item.kondisiFisik != 'Normal';
      }
      return true;
    }).toList();

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          padding: const EdgeInsets.all(11),
          decoration: dekorasiKartu(t),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: t.primaryColor.withAlpha(24),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.visibility_off_rounded,
                      size: 18,
                      color: t.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              sesi.nomorDokumen,
                              style: gayaAngka(
                                const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            StatusBadge(
                              label: '1. HITUNG FISIK',
                              color: t.primaryColor,
                            ),
                          ],
                        ),
                        Text(
                          '${sesi.jumlahDihitung}/${sesi.totalSku} SKU • Total Fisik: ${sesi.totalUnitFisik} unit',
                          style: gayaAngka(
                            TextStyle(fontSize: 11, color: t.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Batalkan Sesi SO?'),
                          content: const Text(
                            'Draft hitungan saat ini akan dihapus tanpa mengubah stok.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Kembali'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: t.dangerColor,
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() => _sesiAktif = null);
                                _simpanDraftSO(null);
                              },
                              child: const Text('Hapus Draft'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Text(
                      'Batal',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: t.dangerColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: t.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(t.radius),
                      ),
                    ),
                    onPressed: _kunciHitunganDanBukaAudit,
                    child: const Text(
                      'Kunci & Audit ▶',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progres,
                  minHeight: 6,
                  backgroundColor: t.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(t.primaryColor),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cariCtrl,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: _prosesScanBarcodeSO,
                  decoration: InputDecoration(
                    hintText: _modeScanTambahCepat
                        ? 'Scan Barcode (Otomatis +1 Toko)...'
                        : 'Scan Barcode (Buka Kalkulator Area)...',
                    hintStyle: const TextStyle(fontSize: 11.5),
                    prefixIcon:
                        const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    suffixIcon: _cariCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 17),
                            onPressed: () {
                              _cariCtrl.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: t.surfaceColor,
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(t.radius),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => setState(
                  () => _modeScanTambahCepat = !_modeScanTambahCepat,
                ),
                borderRadius: BorderRadius.circular(t.radius),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _modeScanTambahCepat
                        ? t.primaryColor
                        : t.surfaceColor,
                    borderRadius: BorderRadius.circular(t.radius),
                    border: Border.all(
                      color: _modeScanTambahCepat
                          ? t.primaryColor
                          : t.borderColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _modeScanTambahCepat
                            ? Icons.bolt_rounded
                            : Icons.edit_note_rounded,
                        size: 17,
                        color: _modeScanTambahCepat
                            ? Colors.white
                            : t.textPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _modeScanTambahCepat ? '+1' : 'Detail',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _modeScanTambahCepat
                              ? Colors.white
                              : t.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_lastScanInfo.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: t.successColor.withAlpha(24),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: t.successColor.withAlpha(90)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 15, color: t.successColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _lastScanInfo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: gayaAngka(
                      TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: t.successColor,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _lastScanInfo = ''),
                  child: Icon(Icons.close, size: 15, color: t.successColor),
                ),
              ],
            ),
          ),
        SizedBox(
          height: 30,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              for (final f in [
                'Semua',
                'Belum Hitung',
                'Sudah Hitung',
                'Kondisi Khusus'
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _filterButa = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _filterButa == f
                            ? t.primaryColor
                            : t.surfaceColor,
                        borderRadius: BorderRadius.circular(t.radius - 2),
                        border: Border.all(
                          color: _filterButa == f
                              ? t.primaryColor
                              : t.borderColor,
                        ),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _filterButa == f
                              ? Colors.white
                              : t.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
            itemCount: listItem.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final item = listItem[idx];
              final sudah = item.sudahDihitung;
              final aksenKat = warnaKategori(item.kategori);
              final kondisiBermasalah =
                  sudah && item.kondisiFisik != 'Normal';

              return TactilePress(
                onTap: () => _bukaModalHitungFisik(item),
                child: Container(
                  decoration: dekorasiKartu(
                    t,
                    borderOverride: sudah ? t.successColor : t.borderColor,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 76,
                        color: sudah ? t.successColor : aksenKat,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          item.kodeSku,
                                          style: gayaAngka(
                                            TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: t.textSecondary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        StatusBadge(
                                          label: item.kategori.toUpperCase(),
                                          color: aksenKat,
                                        ),
                                        if (kondisiBermasalah) ...[
                                          const SizedBox(width: 5),
                                          StatusBadge(
                                            label:
                                                item.kondisiFisik.toUpperCase(),
                                            color: t.warningColor,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.namaProduk,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      sudah
                                          ? 'Toko: ${item.qtyToko ?? 0} • Gudang: ${item.qtyGudang ?? 0}${item.catatan.isNotEmpty ? ' • ${item.catatan}' : ''}'
                                          : 'Belum dihitung • Ketuk untuk input rak & gudang',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: gayaAngka(
                                        TextStyle(
                                          fontSize: 11,
                                          color: sudah
                                              ? t.textPrimary
                                              : t.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _updateItemSO(
                                    item.produkId,
                                    qtyToko: (item.qtyToko ?? 0) + 1,
                                    qtyGudang: item.qtyGudang ?? 0,
                                  );
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: t.inputColor,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: t.borderColor),
                                  ),
                                  child: const Text(
                                    '+1',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                constraints: const BoxConstraints(minWidth: 56),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 8,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: sudah
                                      ? t.successColor.withAlpha(24)
                                      : t.primaryColor.withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: sudah
                                        ? t.successColor
                                        : t.primaryColor.withAlpha(80),
                                  ),
                                ),
                                child: Text(
                                  sudah ? '${item.stokFisik}' : 'Hitung',
                                  style: gayaAngka(
                                    TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      color: sudah
                                          ? t.successColor
                                          : t.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTahapRekonsiliasiDanRecount(
    AppThemeConfig t,
    SesiStockOpname sesi,
  ) {
    final isAdmin = widget.currentStaff.isStoreSystem;
    final listSelisih = sesi.items.where((e) => e.adaSelisih).toList();
    final belumHitung = sesi.totalSku - sesi.jumlahDihitung;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: dekorasiKartu(t),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              sesi.nomorDokumen,
                              style: gayaAngka(
                                const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            StatusBadge(
                              label: '2. AUDIT & RECOUNT',
                              color: t.accentColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Data stok sistem dibuka untuk verifikasi selisih & hitung ulang',
                          style:
                              TextStyle(fontSize: 11, color: t.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      final bukaKembali =
                          sesi.copyWith(terkunciUntukAudit: false);
                      setState(() => _sesiAktif = bukaKembali);
                      _simpanDraftSO(bukaKembali);
                    },
                    icon: const Icon(Icons.lock_open_rounded, size: 16),
                    label: const Text(
                      'Audit Fisik',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      tema: t,
                      label: 'Akurasi Hitungan',
                      value: '${sesi.persentaseAkurasi.toStringAsFixed(1)}%',
                      sublabel:
                          '${sesi.jumlahCocok}/${sesi.jumlahDihitung} SKU cocok',
                      valueColor: sesi.persentaseAkurasi >= 95
                          ? t.successColor
                          : t.warningColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetricTile(
                      tema: t,
                      label: 'Item Selisih',
                      value: '${listSelisih.length} SKU',
                      sublabel:
                          '+${sesi.totalPlusQty} / -${sesi.totalMinusQty} unit',
                      valueColor: listSelisih.isEmpty
                          ? t.successColor
                          : t.dangerColor,
                    ),
                  ),
                ],
              ),
              if (isAdmin) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: MetricTile(
                        tema: t,
                        label: 'Shrinkage (-) HPP',
                        value: '-${formatRupiah(sesi.totalMinusHpp)}',
                        sublabel:
                            'Nilai jual: -${formatRupiah(sesi.totalMinusJual)}',
                        valueColor: sesi.totalMinusHpp > 0
                            ? t.dangerColor
                            : t.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MetricTile(
                        tema: t,
                        label: 'Net Selisih Aset',
                        value:
                            '${sesi.netSelisihHpp >= 0 ? '+' : ''}${formatRupiah(sesi.netSelisihHpp)}',
                        sublabel: 'Surplus +${formatRupiah(sesi.totalPlusHpp)}',
                        valueColor: sesi.netSelisihHpp >= 0
                            ? t.successColor
                            : t.dangerColor,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionHeader(
          title: listSelisih.isEmpty
              ? 'Semua SKU Cocok 100%'
              : 'Verifikasi Item Berselisih (${listSelisih.length} SKU)',
          subtitle: listSelisih.isEmpty
              ? 'Tidak ditemukan perbedaan antara stok fisik dan stok sistem'
              : 'Gunakan tombol Recount jika perlu menghitung ulang fisik di rak',
        ),
        const SizedBox(height: 8),
        if (listSelisih.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: dekorasiKartu(t),
            child: Column(
              children: [
                Icon(Icons.verified_rounded, size: 42, color: t.successColor),
                const SizedBox(height: 8),
                const Text(
                  'Stok fisik di toko dan gudang sesuai dengan catatan sistem.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        else
          ...listSelisih.map((item) {
            final plus = item.selisihQty > 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(11),
              decoration: dekorasiKartu(
                t,
                borderOverride: plus ? t.accentColor : t.dangerColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.namaProduk,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      if (item.sudahRecount)
                        Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: StatusBadge(
                            label: 'RECOUNTED',
                            color: t.accentColor,
                          ),
                        ),
                      StatusBadge(
                        label:
                            '${plus ? '+' : ''}${item.selisihQty} ${item.satuan}',
                        color: plus ? t.accentColor : t.dangerColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: t.inputColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sistem: ${item.stokSistem}',
                          style: gayaAngka(
                            TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: t.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          'Fisik: ${item.stokFisik} (T:${item.qtyToko ?? 0} + G:${item.qtyGudang ?? 0})',
                          style: gayaAngka(
                            const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (isAdmin)
                          Text(
                            '${plus ? '+' : ''}${formatRupiah(item.selisihNilaiHpp)}',
                            style: gayaAngka(
                              TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: plus ? t.accentColor : t.dangerColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (item.sudahRecount && item.hitunganPertama != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Riwayat Hitung: Hitungan ke-1 = ${item.hitunganPertama} ${item.satuan} → Recount = ${item.stokFisik} ${item.satuan}',
                        style: gayaAngka(
                          TextStyle(
                            fontSize: 10.5,
                            color: t.accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: kAlasanSelisihSO.contains(item.alasanSelisih)
                              ? item.alasanSelisih
                              : kAlasanSelisihSO.first,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Penyebab Selisih',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(),
                          ),
                          items: kAlasanSelisihSO
                              .map((a) => DropdownMenuItem(
                                  value: a,
                                  child: Text(
                                    a,
                                    style: const TextStyle(fontSize: 11.5),
                                  )))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              _updateItemSO(item.produkId, alasanSelisih: v);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 11,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(t.radius),
                          ),
                        ),
                        onPressed: () =>
                            _bukaModalHitungFisik(item, isRecount: true),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text(
                          'Recount',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: t.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(t.radius),
            ),
          ),
          onPressed: _sedangMembuatPdf
              ? null
              : () {
                  if (belumHitung == 0) {
                    _sahkanBeritaAcaraSO(nolkanYangBelumDihitung: false);
                    return;
                  }
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: t.surfaceColor,
                      title: const Text(
                        'Perlakuan Item Belum Dihitung',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      content: Text(
                        'Masih ada $belumHitung SKU yang belum dihitung pada sesi ini. Bagaimana perlakuan terhadap stok sistem item tersebut?',
                        style: const TextStyle(fontSize: 13),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Batal'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _sahkanBeritaAcaraSO(nolkanYangBelumDihitung: false);
                          },
                          child: const Text('Biarkan Tetap'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: t.dangerColor,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _sahkanBeritaAcaraSO(nolkanYangBelumDihitung: true);
                          },
                          child: const Text('Nol-kan Stok (0)'),
                        ),
                      ],
                    ),
                  );
                },
          icon: _sedangMembuatPdf
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.picture_as_pdf_rounded, size: 20),
          label: Text(
            _sedangMembuatPdf
                ? 'MEMBUAT PDF BERITA ACARA...'
                : 'SAHKAN & AUTO BUAT PDF BERITA ACARA',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _KartuInputLokasi extends StatelessWidget {
  final AppThemeConfig tema;
  final String judul;
  final IconData ikon;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final void Function(int delta) onDelta;

  const _KartuInputLokasi({
    required this.tema,
    required this.judul,
    required this.ikon,
    required this.controller,
    required this.onChanged,
    required this.onDelta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: dekorasiKartu(tema),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, size: 16, color: tema.primaryColor),
              const SizedBox(width: 6),
              Text(
                judul,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _BtnDeltaLokasi(
                tema: tema,
                label: '-1',
                onTap: () => onDelta(-1),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (_) => onChanged(),
                  style: gayaAngka(
                    const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _BtnDeltaLokasi(
                tema: tema,
                label: '+1',
                onTap: () => onDelta(1),
              ),
              const SizedBox(width: 5),
              _BtnDeltaLokasi(
                tema: tema,
                label: '+5',
                onTap: () => onDelta(5),
              ),
              const SizedBox(width: 5),
              _BtnDeltaLokasi(
                tema: tema,
                label: '+10',
                onTap: () => onDelta(10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BtnDeltaLokasi extends StatelessWidget {
  final AppThemeConfig tema;
  final String label;
  final VoidCallback onTap;

  const _BtnDeltaLokasi({
    required this.tema,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: tema.inputColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: tema.borderColor),
        ),
        child: Text(
          label,
          style: gayaAngka(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _MiniStatBanner extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStatBanner({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(26),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: gayaAngka(
                const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarisBA extends StatelessWidget {
  final String label;
  final String nilai;

  const _BarisBA(this.label, this.nilai);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5)),
          Text(
            nilai,
            style: gayaAngka(
              const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
