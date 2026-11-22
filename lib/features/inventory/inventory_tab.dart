import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/pdf_downloader.dart';
import '../../models/pos_models.dart';
import '../../widgets/pos_components.dart';
import 'stock_opname_view.dart';

class InventoryTab extends StatefulWidget {
  final AppThemeConfig tema;
  final PengaturanToko? toko;
  final AkunStaff currentStaff;
  final List<AkunStaff> daftarStaff;
  final List<Produk> daftarProduk;
  final List<LogStok> daftarLogStok;
  final void Function(Produk produk, bool isBaru) onSimpanProduk;
  final void Function(String produkId) onHapusProduk;
  final void Function({
    required Produk produk,
    required String tipe,
    required int perubahan,
    required String keterangan,
  }) onMutasiStok;

  const InventoryTab({
    super.key,
    required this.tema,
    this.toko,
    required this.currentStaff,
    required this.daftarStaff,
    required this.daftarProduk,
    required this.daftarLogStok,
    required this.onSimpanProduk,
    required this.onHapusProduk,
    required this.onMutasiStok,
  });

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  int _subTab = 0; // 0: Katalog, 1: Blind SO, 2: Kartu Stok, 3: Label Harga

  // State Katalog Komersial
  final TextEditingController _cariCtrl = TextEditingController();
  String _kategoriFilter = 'Semua';
  String _statusStokFilter = 'Semua'; // Semua, Menipis, Habis, Grosir
  String _urutkanKatalog = 'Nama A-Z'; // Nama A-Z, Stok Terendah, Margin Tertinggi, Aset Tertinggi

  // State Kartu Stok Komersial
  final TextEditingController _cariLogCtrl = TextEditingController();
  String _tipeLogFilter = 'Semua'; // Semua, Masuk, Keluar, Opname, Void

  // State Label Harga Rak
  final TextEditingController _cariLabelCtrl = TextEditingController();
  final Map<String, int> _qtyLabel = {};
  bool _tampilkanGrosirDiLabel = true;

  @override
  void dispose() {
    _cariCtrl.dispose();
    _cariLogCtrl.dispose();
    _cariLabelCtrl.dispose();
    super.dispose();
  }

  Future<bool> _cekHakAdmin(String judul, String ket) async {
    if (widget.currentStaff.isStoreSystem) return true;
    final admin = await tampilkanOtorisasiSis(
      context: context,
      tema: widget.tema,
      daftarStaff: widget.daftarStaff,
      judul: judul,
      keterangan: ket,
    );
    return admin != null;
  }

  void _bukaFormProduk({Produk? editProduk}) async {
    final boleh = await _cekHakAdmin(
      'Otorisasi Master Produk',
      'Tambah atau ubah harga/HPP produk memerlukan izin Store Information System.',
    );
    if (!boleh || !mounted) return;

    final t = widget.tema;
    final isBaru = editProduk == null;
    final namaCtrl = TextEditingController(text: editProduk?.nama ?? '');
    final skuCtrl = TextEditingController(
      text: editProduk?.kodeSku ??
          '899${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}',
    );
    final jualCtrl = TextEditingController(
      text: editProduk != null ? editProduk.hargaJual.toString() : '',
    );
    final modalCtrl = TextEditingController(
      text: editProduk != null ? editProduk.hargaModal.toString() : '',
    );
    final grosirCtrl = TextEditingController(
      text: editProduk != null && editProduk.hargaGrosir > 0
          ? editProduk.hargaGrosir.toString()
          : '',
    );
    final minGrosirCtrl = TextEditingController(
      text: editProduk != null && editProduk.minQtyGrosir > 0
          ? editProduk.minQtyGrosir.toString()
          : '',
    );
    final stokCtrl = TextEditingController(
      text: editProduk != null ? editProduk.stok.toString() : '10',
    );
    final alertCtrl = TextEditingController(
      text: editProduk != null ? editProduk.minStokAlert.toString() : '5',
    );

    final daftarKat = kKategoriProduk.where((e) => e != 'Semua').toList();
    String kategori = editProduk != null && daftarKat.contains(editProduk.kategori)
        ? editProduk.kategori
        : (daftarKat.isNotEmpty ? daftarKat.first : 'Makanan');
    const daftarSatuan = ['pcs', 'box', 'pack', 'kg', 'liter', 'botol', 'renteng'];
    String satuan = editProduk != null && daftarSatuan.contains(editProduk.satuan)
        ? editProduk.satuan
        : 'pcs';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final jualPreview =
              int.tryParse(jualCtrl.text.replaceAll('.', '')) ?? 0;
          final modalPreview =
              int.tryParse(modalCtrl.text.replaceAll('.', '')) ?? 0;
          final profitPreview = jualPreview - modalPreview;
          final marginPct = jualPreview > 0
              ? ((profitPreview / jualPreview) * 100).toStringAsFixed(1)
              : '0.0';

          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isBaru ? 'Tambah Master SKU Baru' : 'Edit Master Produk',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: namaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Produk *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: kategori,
                          decoration: const InputDecoration(
                            labelText: 'Kategori',
                            border: OutlineInputBorder(),
                          ),
                          items: daftarKat
                              .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setModalState(() => kategori = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: satuan,
                          decoration: const InputDecoration(
                            labelText: 'Satuan Jual',
                            border: OutlineInputBorder(),
                          ),
                          items: daftarSatuan
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setModalState(() => satuan = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: modalCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setModalState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Harga Modal (HPP)',
                            prefixText: 'Rp ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: jualCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setModalState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Harga Jual Ecer *',
                            prefixText: 'Rp ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (jualPreview > 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: profitPreview >= 0
                            ? t.successColor.withAlpha(20)
                            : t.dangerColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Estimasi Margin: ${formatRupiah(profitPreview)} / $satuan ($marginPct%)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: profitPreview >= 0 ? t.successColor : t.dangerColor,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: grosirCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Harga Grosir (Opsional)',
                            prefixText: 'Rp ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: minGrosirCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Min. Qty Grosir',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: stokCtrl,
                          keyboardType: TextInputType.number,
                          enabled: isBaru,
                          decoration: InputDecoration(
                            labelText: isBaru ? 'Stok Awal' : 'Stok (Ubah via Mutasi)',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: alertCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Batas Stok Menipis',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: skuCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Kode SKU / Barcode',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: t.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(t.radius),
                      ),
                    ),
                    onPressed: () {
                      final nama = namaCtrl.text.trim();
                      final jual =
                          int.tryParse(jualCtrl.text.replaceAll('.', '')) ?? 0;
                      final modal =
                          int.tryParse(modalCtrl.text.replaceAll('.', '')) ?? 0;
                      if (nama.isEmpty || jual <= 0) return;

                      final produkBaru = Produk(
                        id: editProduk?.id ??
                            'prd_${DateTime.now().millisecondsSinceEpoch}',
                        nama: nama,
                        kategori: kategori,
                        satuan: satuan,
                        hargaJual: jual,
                        hargaModal: modal,
                        hargaGrosir: int.tryParse(
                                grosirCtrl.text.replaceAll('.', '')) ??
                            0,
                        minQtyGrosir: int.tryParse(minGrosirCtrl.text) ?? 0,
                        stok: editProduk?.stok ?? (int.tryParse(stokCtrl.text) ?? 0),
                        minStokAlert: int.tryParse(alertCtrl.text) ?? 5,
                        kodeSku: skuCtrl.text.trim(),
                      );
                      Navigator.pop(ctx);
                      widget.onSimpanProduk(produkBaru, isBaru);
                    },
                    child: Text(isBaru ? 'Simpan Produk' : 'Update Master Produk'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _dialogMutasiStok({Produk? produkAwal, bool defaultMasuk = true}) {
    if (widget.daftarProduk.isEmpty) return;
    final t = widget.tema;
    Produk produkTerpilih = produkAwal ?? widget.daftarProduk.first;
    bool isMasuk = defaultMasuk;
    final qtyCtrl = TextEditingController(text: '10');
    final ketCtrl = TextEditingController(
      text: defaultMasuk ? 'Penerimaan Supplier / Faktur' : 'Barang Rusak / Kedaluwarsa',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: t.surfaceColor,
          title: const Text(
            'Catat Mutasi Stok Gudang / Toko',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: produkTerpilih.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Pilih Produk',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: widget.daftarProduk
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            '${p.nama} (Stok: ${p.stok})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    final found = widget.daftarProduk.firstWhere((e) => e.id == id);
                    setDlgState(() => produkTerpilih = found);
                  },
                ),
                const SizedBox(height: 10),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.add_box_outlined, size: 16),
                      label: Text('Stok Masuk (+)', style: TextStyle(fontSize: 11)),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.indeterminate_check_box_outlined, size: 16),
                      label: Text('Stok Keluar (-)', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                  selected: {isMasuk},
                  onSelectionChanged: (v) {
                    setDlgState(() {
                      isMasuk = v.first;
                      ketCtrl.text = isMasuk
                          ? 'Penerimaan Supplier / Faktur'
                          : 'Barang Rusak / Kedaluwarsa';
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Jumlah (${produkTerpilih.satuan})',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ketCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan / No. Faktur / Alasan',
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
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isMasuk ? t.successColor : t.dangerColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final jumlah = int.tryParse(qtyCtrl.text) ?? 0;
                if (jumlah <= 0) return;
                if (!isMasuk && jumlah > produkTerpilih.stok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Stok keluar melebihi sisa stok (${produkTerpilih.stok}).',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                widget.onMutasiStok(
                  produk: produkTerpilih,
                  tipe: isMasuk ? 'Masuk' : 'Keluar',
                  perubahan: isMasuk ? jumlah : -jumlah,
                  keterangan: ketCtrl.text.trim().isEmpty
                      ? (isMasuk ? 'Barang Masuk' : 'Koreksi Stok Keluar')
                      : ketCtrl.text.trim(),
                );
              },
              child: Text(isMasuk ? 'Simpan Masuk' : 'Simpan Keluar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cetakPdfLabelHarga() async {
    final daftarCetak = <Produk>[];
    for (final p in widget.daftarProduk) {
      final qty = _qtyLabel[p.id] ?? 0;
      for (int i = 0; i < qty; i++) {
        daftarCetak.add(p);
      }
    }

    if (daftarCetak.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal 1 produk untuk dicetak label harganya.'),
        ),
      );
      return;
    }

    final namaToko = widget.toko?.namaToko ?? 'NUSANTARA RETAIL POS';
    final now = DateTime.now();
    final tglCetak =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final doc = pw.Document();
    const perHalaman = 18;

    for (int offset = 0; offset < daftarCetak.length; offset += perHalaman) {
      final slice = daftarCetak.skip(offset).take(perHalaman).toList();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(18),
          build: (pw.Context ctx) {
            return pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: slice.map((produk) {
                final adaGrosir = _tampilkanGrosirDiLabel &&
                    produk.hargaGrosir > 0 &&
                    produk.minQtyGrosir > 0;
                return pw.Container(
                  width: 178,
                  height: 112,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: PdfColors.grey700,
                      width: 1.0,
                    ),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              namaToko.toUpperCase(),
                              maxLines: 1,
                              style: pw.TextStyle(
                                fontSize: 6.5,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ),
                          pw.Text(
                            tglCetak,
                            style: const pw.TextStyle(
                              fontSize: 6.5,
                              color: PdfColors.grey600,
                            ),
                          ),
                        ],
                      ),
                      pw.Text(
                        produk.nama,
                        maxLines: 2,
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green900,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              formatRupiah(produk.hargaJual),
                              style: pw.TextStyle(
                                fontSize: 13.5,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.Text(
                              '/ ${produk.satuan}',
                              style: const pw.TextStyle(
                                fontSize: 7.5,
                                color: PdfColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'SKU: ${produk.kodeSku}',
                            style: const pw.TextStyle(
                              fontSize: 7,
                              color: PdfColors.grey800,
                            ),
                          ),
                          if (adaGrosir)
                            pw.Text(
                              'Grosir >=${produk.minQtyGrosir}: ${formatRupiah(produk.hargaGrosir)}',
                              style: pw.TextStyle(
                                fontSize: 6.8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue900,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      );
    }

    final bytes = await doc.save();
    final namaFile = 'Label_Harga_Rak_${now.millisecondsSinceEpoch}.pdf';
    await unduhAtauCetakPdf(bytes: bytes, filename: namaFile);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'File $namaFile berhasil diunduh (${daftarCetak.length} label).',
          ),
        ),
      );
    }
  }

  Widget _buildTabKatalogKomersial(AppThemeConfig t, bool isAdmin) {
    final query = _cariCtrl.text.trim().toLowerCase();

    final listProduk = widget.daftarProduk.where((p) {
      final cocokKategori =
          _kategoriFilter == 'Semua' || p.kategori == _kategoriFilter;
      bool cocokStatus = true;
      if (_statusStokFilter == 'Menipis') {
        cocokStatus = p.stok > 0 && p.stok <= p.minStokAlert;
      } else if (_statusStokFilter == 'Habis') {
        cocokStatus = p.stok <= 0;
      } else if (_statusStokFilter == 'Grosir') {
        cocokStatus = p.hargaGrosir > 0 && p.minQtyGrosir > 0;
      }

      final cocokCari = query.isEmpty ||
          p.nama.toLowerCase().contains(query) ||
          p.kodeSku.toLowerCase().contains(query) ||
          p.kategori.toLowerCase().contains(query);
      return cocokKategori && cocokStatus && cocokCari;
    }).toList();

    listProduk.sort((a, b) {
      switch (_urutkanKatalog) {
        case 'Stok Terendah':
          return a.stok.compareTo(b.stok);
        case 'Margin Tertinggi':
          final mA = a.hargaJual - a.hargaModal;
          final mB = b.hargaJual - b.hargaModal;
          return mB.compareTo(mA);
        case 'Aset Tertinggi':
          return (b.hargaModal * b.stok).compareTo(a.hargaModal * a.stok);
        default:
          return a.nama.toLowerCase().compareTo(b.nama.toLowerCase());
      }
    });

    final totalAsetModal = widget.daftarProduk
        .fold<int>(0, (s, p) => s + (p.hargaModal * p.stok));
    final potensiOmzet = widget.daftarProduk
        .fold<int>(0, (s, p) => s + (p.hargaJual * p.stok));
    final estimasiLaba = potensiOmzet - totalAsetModal;
    final jumlahMenipis = widget.daftarProduk
        .where((p) => p.stok > 0 && p.stok <= p.minStokAlert)
        .length;
    final jumlahHabis = widget.daftarProduk.where((p) => p.stok <= 0).length;

    return Column(
      children: [
        // Ringkasan Valuasi Inventaris & Kesehatan Stok
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: MetricTile(
                  tema: t,
                  label: isAdmin ? 'Nilai Aset (HPP)' : 'Total SKU Aktif',
                  value: isAdmin
                      ? formatRupiah(totalAsetModal)
                      : '${widget.daftarProduk.length} SKU',
                  valueColor: t.primaryColor,
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  tema: t,
                  label: isAdmin ? 'Potensi Laba Stok' : 'Stok Kritis',
                  value: isAdmin
                      ? formatRupiah(estimasiLaba)
                      : '$jumlahMenipis Menipis • $jumlahHabis Habis',
                  valueColor: isAdmin ? t.successColor : t.warningColor,
                  icon: Icons.trending_up_rounded,
                ),
              ),
            ],
          ),
        ),
        if (isAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: t.primaryColor.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.primaryColor.withAlpha(45)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Potensi Omzet Jual: ${formatRupiah(potensiOmzet)}',
                    style: gayaAngka(
                      TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: t.primaryColor,
                      ),
                    ),
                  ),
                  Text(
                    '${widget.daftarProduk.length} SKU • $jumlahHabis Habis',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: jumlahHabis > 0 ? t.dangerColor : t.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Bar Pencarian + Sortir + Tambah SKU
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cariCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Cari nama produk, kategori, atau SKU...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, size: 19),
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
              PopupMenuButton<String>(
                tooltip: 'Urutkan Katalog',
                initialValue: _urutkanKatalog,
                onSelected: (v) => setState(() => _urutkanKatalog = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'Nama A-Z', child: Text('Urut: Nama A–Z')),
                  PopupMenuItem(
                    value: 'Stok Terendah',
                    child: Text('Urut: Stok Terendah'),
                  ),
                  PopupMenuItem(
                    value: 'Margin Tertinggi',
                    child: Text('Urut: Margin Tertinggi'),
                  ),
                  PopupMenuItem(
                    value: 'Aset Tertinggi',
                    child: Text('Urut: Nilai Aset Tertinggi'),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: dekorasiKartu(t),
                  child: const Icon(Icons.sort_rounded, size: 19),
                ),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: t.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(t.radius),
                  ),
                ),
                onPressed: () => _bukaFormProduk(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('SKU Baru', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),

        // Filter Status Stok & Kategori Horizontal
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              for (final st in ['Semua', 'Menipis', 'Habis', 'Grosir']) ...[
                ChoiceChip(
                  label: Text(
                    st == 'Menipis'
                        ? 'Menipis ($jumlahMenipis)'
                        : (st == 'Habis' ? 'Habis ($jumlahHabis)' : st),
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: _statusStokFilter == st,
                  onSelected: (_) => setState(() => _statusStokFilter = st),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
              ],
              const VerticalDivider(width: 12),
              for (final kat in kKategoriProduk) ...[
                ChoiceChip(
                  label: Text(kat, style: const TextStyle(fontSize: 11)),
                  selected: _kategoriFilter == kat,
                  onSelected: (_) => setState(() => _kategoriFilter = kat),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Daftar Master Produk
        Expanded(
          child: listProduk.isEmpty
              ? Center(
                  child: Text(
                    'Tidak ada SKU yang cocok dengan filter.',
                    style: TextStyle(color: t.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  itemCount: listProduk.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final p = listProduk[idx];
                    final habis = p.stok <= 0;
                    final menipis = !habis && p.stok <= p.minStokAlert;
                    final profitUnit = p.hargaJual - p.hargaModal;
                    final marginPct = p.hargaJual > 0
                        ? ((profitUnit / p.hargaJual) * 100).round()
                        : 0;
                    final nilaiAsetSku = p.hargaModal * p.stok;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: dekorasiKartu(
                        t,
                        borderOverride: habis
                            ? t.dangerColor
                            : (menipis ? t.warningColor : t.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        StatusBadge(
                                          label: p.kategori.toUpperCase(),
                                          color: warnaKategori(p.kategori),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'SKU ${p.kodeSku}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: t.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      p.nama,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: habis
                                      ? t.dangerColor
                                      : (menipis
                                          ? t.warningColor
                                          : t.successColor),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  habis
                                      ? 'HABIS (0)'
                                      : 'Stok: ${p.stok} ${p.satuan}',
                                  style: gayaAngka(
                                    const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Baris Harga Jual, HPP Modal, & Margin
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Jual: ${formatRupiah(p.hargaJual)}',
                                style: gayaAngka(
                                  TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: t.primaryColor,
                                  ),
                                ),
                              ),
                              if (isAdmin) ...[
                                Text(
                                  'HPP: ${formatRupiah(p.hargaModal)}',
                                  style: gayaAngka(
                                    TextStyle(
                                      fontSize: 12,
                                      color: t.textSecondary,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Margin: ${formatRupiah(profitUnit)} ($marginPct%)',
                                  style: gayaAngka(
                                    TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: profitUnit >= 0
                                          ? t.successColor
                                          : t.dangerColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (p.hargaGrosir > 0 && p.minQtyGrosir > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Harga Grosir ≥${p.minQtyGrosir} ${p.satuan}: ${formatRupiah(p.hargaGrosir)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                          ],
                          const Divider(height: 14),
                          Row(
                            children: [
                              if (isAdmin)
                                Expanded(
                                  child: Text(
                                    'Aset SKU: ${formatRupiah(nilaiAsetSku)}',
                                    style: gayaAngka(
                                      TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: t.textSecondary,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                const Spacer(),
                              TextButton.icon(
                                onPressed: () => _dialogMutasiStok(
                                  produkAwal: p,
                                  defaultMasuk: true,
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: const Size(0, 30),
                                ),
                                icon: Icon(
                                  Icons.add_box_outlined,
                                  size: 16,
                                  color: t.successColor,
                                ),
                                label: Text(
                                  'Restok',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: t.successColor,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Koreksi / Barang Rusak',
                                onPressed: () => _dialogMutasiStok(
                                  produkAwal: p,
                                  defaultMasuk: false,
                                ),
                                icon: Icon(
                                  Icons.indeterminate_check_box_outlined,
                                  size: 19,
                                  color: t.warningColor,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                tooltip: 'Edit Master Produk',
                                onPressed: () => _bukaFormProduk(editProduk: p),
                                icon: const Icon(Icons.edit_outlined, size: 19),
                                visualDensity: VisualDensity.compact,
                              ),
                              if (isAdmin)
                                IconButton(
                                  tooltip: 'Hapus Produk',
                                  onPressed: () => widget.onHapusProduk(p.id),
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 19,
                                    color: t.dangerColor,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
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

  Widget _buildTabKartuStokKomersial(AppThemeConfig t) {
    final q = _cariLogCtrl.text.trim().toLowerCase();
    final logTersaring = widget.daftarLogStok.where((log) {
      final cocokTipe = _tipeLogFilter == 'Semua' ||
          log.tipe.toLowerCase() == _tipeLogFilter.toLowerCase();
      final cocokCari = q.isEmpty ||
          log.namaProduk.toLowerCase().contains(q) ||
          log.keterangan.toLowerCase().contains(q) ||
          log.olehStaff.toLowerCase().contains(q);
      return cocokTipe && cocokCari;
    }).toList();

    int totalMasuk = 0;
    int totalKeluar = 0;
    for (final l in logTersaring) {
      if (l.perubahan > 0) {
        totalMasuk += l.perubahan;
      } else {
        totalKeluar += l.perubahan.abs();
      }
    }
    final netMutasi = totalMasuk - totalKeluar;

    return Column(
      children: [
        // Ringkasan Arus Barang Masuk vs Keluar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: MetricTile(
                  tema: t,
                  label: 'Total Masuk (+)',
                  value: '+$totalMasuk Unit',
                  valueColor: t.successColor,
                  icon: Icons.south_west_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  tema: t,
                  label: 'Total Keluar (-)',
                  value: '-$totalKeluar Unit',
                  valueColor: t.dangerColor,
                  icon: Icons.north_east_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  tema: t,
                  label: 'Net Mutasi',
                  value: '${netMutasi >= 0 ? '+' : ''}$netMutasi',
                  valueColor: netMutasi >= 0 ? t.primaryColor : t.warningColor,
                  icon: Icons.swap_vert_rounded,
                ),
              ),
            ],
          ),
        ),

        // Search Log + Tombol Catat Mutasi Manual
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cariLogCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Cari produk, faktur, atau operator...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, size: 19),
                    suffixIcon: _cariLogCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 17),
                            onPressed: () {
                              _cariLogCtrl.clear();
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
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: t.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(t.radius),
                  ),
                ),
                onPressed: () => _dialogMutasiStok(defaultMasuk: true),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 17),
                label: const Text('Mutasi', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),

        // Filter Jenis Mutasi
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              for (final tipe in ['Semua', 'Masuk', 'Keluar', 'Opname', 'Void']) ...[
                ChoiceChip(
                  label: Text(tipe, style: const TextStyle(fontSize: 11)),
                  selected: _tipeLogFilter == tipe,
                  onSelected: (_) => setState(() => _tipeLogFilter = tipe),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Daftar Audit Kartu Stok
        Expanded(
          child: logTersaring.isEmpty
              ? Center(
                  child: Text(
                    'Belum ada riwayat mutasi stok untuk filter ini.',
                    style: TextStyle(color: t.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  itemCount: logTersaring.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final log = logTersaring[idx];
                    final positif = log.perubahan > 0;
                    final stokAwal = log.stokAkhir - log.perubahan;
                    Color badgeColor = positif ? t.successColor : t.warningColor;
                    if (log.tipe.toLowerCase() == 'opname') {
                      badgeColor = const Color(0xFF1565C0);
                    } else if (log.tipe.toLowerCase() == 'void') {
                      badgeColor = t.dangerColor;
                    }

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: dekorasiKartu(t),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    StatusBadge(
                                      label: log.tipe.toUpperCase(),
                                      color: badgeColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        log.namaProduk,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  log.keterangan,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: t.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${formatTanggalWaktu(log.tanggal)} • Oleh: ${log.olehStaff}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: t.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${positif ? '+' : ''}${log.perubahan}',
                                style: gayaAngka(
                                  TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: positif
                                        ? t.successColor
                                        : t.dangerColor,
                                  ),
                                ),
                              ),
                              Text(
                                '$stokAwal → ${log.stokAkhir}',
                                style: gayaAngka(
                                  TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: t.textSecondary,
                                  ),
                                ),
                              ),
                            ],
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

  Widget _buildTabLabelHarga(AppThemeConfig t) {
    final q = _cariLabelCtrl.text.trim().toLowerCase();
    final listFiltered = widget.daftarProduk.where((p) {
      if (q.isEmpty) return true;
      return p.nama.toLowerCase().contains(q) ||
          p.kodeSku.toLowerCase().contains(q) ||
          p.kategori.toLowerCase().contains(q);
    }).toList();

    final totalStiker = _qtyLabel.values.fold<int>(0, (a, b) => a + b);
    final totalSkuDipilih = _qtyLabel.values.where((v) => v > 0).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: MetricTile(
                  tema: t,
                  label: 'Produk Dipilih',
                  value: '$totalSkuDipilih SKU',
                  valueColor: t.primaryColor,
                  icon: Icons.sell_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricTile(
                  tema: t,
                  label: 'Total Label Cetak',
                  value: '$totalStiker Label',
                  valueColor: totalStiker > 0 ? t.successColor : t.textSecondary,
                  icon: Icons.print_outlined,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cariLabelCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Cari produk / SKU untuk cetak label...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: t.surfaceColor,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(t.radius),
                      borderSide: BorderSide(color: t.borderColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    if (totalSkuDipilih == widget.daftarProduk.length &&
                        widget.daftarProduk.isNotEmpty) {
                      _qtyLabel.clear();
                    } else {
                      for (final p in widget.daftarProduk) {
                        _qtyLabel[p.id] = (_qtyLabel[p.id] ?? 0) > 0
                            ? _qtyLabel[p.id]!
                            : 1;
                      }
                    }
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                ),
                child: Text(
                  totalSkuDipilih == widget.daftarProduk.length &&
                          widget.daftarProduk.isNotEmpty
                      ? 'Reset'
                      : 'Pilih Semua',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
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
                child: Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _tampilkanGrosirDiLabel,
                        activeColor: t.primaryColor,
                        onChanged: (v) => setState(
                          () => _tampilkanGrosirDiLabel = v ?? true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Cantumkan info harga grosir pada label rak',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: totalStiker > 0 ? _cetakPdfLabelHarga : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0E5A3E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                ),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: Text(
                  'Cetak PDF ($totalStiker)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: listFiltered.isEmpty
              ? Center(
                  child: Text(
                    'Produk tidak ditemukan.',
                    style: TextStyle(color: t.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  itemCount: listFiltered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final p = listFiltered[idx];
                    final qty = _qtyLabel[p.id] ?? 0;
                    final dipilih = qty > 0;

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: dekorasiKartu(
                        t,
                        borderOverride:
                            dipilih ? const Color(0xFF0E5A3E) : t.borderColor,
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: dipilih,
                            activeColor: const Color(0xFF0E5A3E),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _qtyLabel[p.id] = 1;
                                } else {
                                  _qtyLabel.remove(p.id);
                                }
                              });
                            },
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.nama,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      formatRupiah(p.hargaJual),
                                      style: gayaAngka(
                                        const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0E5A3E),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '• SKU ${p.kodeSku}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: t.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_tampilkanGrosirDiLabel &&
                                    p.hargaGrosir > 0 &&
                                    p.minQtyGrosir > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Grosir ≥${p.minQtyGrosir}: ${formatRupiah(p.hargaGrosir)}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1565C0),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: qty > 0
                                    ? () {
                                        setState(() {
                                          if (qty <= 1) {
                                            _qtyLabel.remove(p.id);
                                          } else {
                                            _qtyLabel[p.id] = qty - 1;
                                          }
                                        });
                                      }
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                              ),
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '$qty',
                                  textAlign: TextAlign.center,
                                  style: gayaAngka(
                                    const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  setState(() {
                                    _qtyLabel[p.id] = qty + 1;
                                  });
                                },
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  size: 20,
                                  color: Color(0xFF0E5A3E),
                                ),
                              ),
                            ],
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

  @override
  Widget build(BuildContext context) {
    final t = widget.tema;
    final isAdmin = widget.currentStaff.isStoreSystem;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Katalog', style: TextStyle(fontSize: 11)),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Stock Opname', style: TextStyle(fontSize: 11)),
              ),
              ButtonSegment(
                value: 2,
                label: Text('Kartu Stok', style: TextStyle(fontSize: 11)),
              ),
              ButtonSegment(
                value: 3,
                label: Text('Label Harga', style: TextStyle(fontSize: 11)),
              ),
            ],
            selected: {_subTab},
            onSelectionChanged: (v) => setState(() => _subTab = v.first),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _subTab,
            children: [
              _buildTabKatalogKomersial(t, isAdmin),
              StockOpnameView(
                tema: t,
                toko: widget.toko,
                currentStaff: widget.currentStaff,
                daftarStaff: widget.daftarStaff,
                daftarProduk: widget.daftarProduk,
                onMutasiStok: widget.onMutasiStok,
              ),
              _buildTabKartuStokKomersial(t),
              _buildTabLabelHarga(t),
            ],
          ),
        ),
      ],
    );
  }
}
