import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../widgets/pos_components.dart';

class SisInventorySoView extends StatefulWidget {
  final AppThemeConfig tema;
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

  const SisInventorySoView({
    super.key,
    required this.tema,
    required this.daftarProduk,
    required this.daftarLogStok,
    required this.onSimpanProduk,
    required this.onHapusProduk,
    required this.onMutasiStok,
  });

  @override
  State<SisInventorySoView> createState() => _SisInventorySoViewState();
}

class _SisInventorySoViewState extends State<SisInventorySoView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  int _modeSub = 0; // 0: Katalog & Mutasi, 1: Stock Opname (SO), 2: Log Mutasi
  String _filterStok = 'Semua'; // Semua, Kritis, Habis, Grosir
  final TextEditingController _cariCtrl = TextEditingController();
  final Map<String, TextEditingController> _soControllers = {};

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isBaru ? 'Tambah Produk / SKU Baru' : 'Edit SKU • ${editProduk.nama}',
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: skuCtrl,
                decoration: InputDecoration(
                  labelText: 'Kode SKU / Barcode',
                  filled: true,
                  fillColor: t.inputColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                        labelText: 'Harga Modal (HPP)',
                        filled: true,
                        fillColor: t.inputColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                        labelText: 'Stok Awal',
                        filled: true,
                        fillColor: t.inputColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Min Alert',
                        filled: true,
                        fillColor: t.inputColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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

              final prd = Produk(
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
              );
              widget.onSimpanProduk(prd, isBaru);
              Navigator.pop(ctx);
            },
            child: const Text('Simpan SKU', style: TextStyle(fontWeight: FontWeight.w800)),
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
      text: tipe == 'Masuk'
          ? 'Penerimaan Barang / Restok Gudang'
          : 'Penyesuaian Stok Keluar / Rusak',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: t.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Mutasi Stok • ${prd.nama}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Stok saat ini: ${prd.stok} ${prd.satuan} • SKU ${prd.kodeSku}',
                  style: TextStyle(fontSize: 11.5, color: t.textSecondary),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Masuk', label: Text('Stok Masuk (+)')),
                    ButtonSegment(value: 'Keluar', label: Text('Stok Keluar (-)')),
                  ],
                  selected: {tipe},
                  onSelectionChanged: (v) => setDlg(() => tipe = v.first),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ketCtrl,
                  decoration: InputDecoration(
                    labelText: 'Keterangan / No. Surat Jalan',
                    filled: true,
                    fillColor: t.inputColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: tipe == 'Masuk' ? t.successColor : t.dangerColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final rawQty = int.tryParse(qtyCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                if (rawQty > 0) {
                  final delta = tipe == 'Masuk' ? rawQty : -rawQty;
                  widget.onMutasiStok(
                    produk: prd,
                    tipe: tipe,
                    perubahan: delta,
                    keterangan: ketCtrl.text.trim().isEmpty ? 'Mutasi $tipe' : ketCtrl.text.trim(),
                  );
                }
                Navigator.pop(ctx);
              },
              child: const Text('Simpan Mutasi', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  void _commitStockOpname(Produk prd) {
    final ctrl = _soControllers[prd.id];
    final fisik = int.tryParse((ctrl?.text ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? prd.stok;
    final selisih = fisik - prd.stok;
    if (selisih == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stok fisik ${prd.nama} sudah sesuai sistem (${prd.stok} ${prd.satuan}).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    widget.onMutasiStok(
      produk: prd,
      tipe: 'Opname',
      perubahan: selisih,
      keterangan: 'Stock Opname SIS: Sistem ${prd.stok} -> Fisik $fisik (${selisih > 0 ? "+$selisih" : "$selisih"})',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('SO ${prd.nama} tersimpan! Selisih ${selisih > 0 ? "+$selisih" : "$selisih"} ${prd.satuan}.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tema;
    final totalSku = widget.daftarProduk.length;
    final totalValuasiHpp = widget.daftarProduk.fold<int>(
      0,
      (s, p) => s + (p.hargaModal * p.stok),
    );
    final totalPotensiJual = widget.daftarProduk.fold<int>(
      0,
      (s, p) => s + (p.hargaJual * p.stok),
    );
    final jmlKritis = widget.daftarProduk
        .where((p) => p.stok <= p.minStokAlert)
        .length;

    final jamStr =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}';

    return Column(
      children: [
        // Live Inventory Telemetry Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: dekorasiKartu(t),
            child: Column(
              children: [
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) {
                        final v = _pulseCtrl.value;
                        return Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: t.primaryColor,
                            boxShadow: [
                              BoxShadow(
                                color: t.primaryColor.withAlpha(((1 - v) * 140).round()),
                                blurRadius: 4 + (8 * v),
                                spreadRadius: 1 + (3 * v),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'INVENTORY & STOCK OPNAME ENGINE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: t.primaryColor,
                        ),
                      ),
                    ),
                    Text(
                      jamStr,
                      style: gayaAngka(const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStatBox(
                        tema: t,
                        label: 'TOTAL SKU',
                        value: '$totalSku',
                        color: t.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStatBox(
                        tema: t,
                        label: 'STOK KRITIS',
                        value: '$jmlKritis',
                        color: jmlKritis > 0 ? t.dangerColor : t.successColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _MiniStatBox(
                        tema: t,
                        label: 'VALUASI HPP / JUAL',
                        value: '${formatRupiah(totalValuasiHpp)} • ${formatRupiah(totalPotensiJual)}',
                        color: t.accentColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Switcher Mode Inventory & SO
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Katalog & Stok')),
              ButtonSegment(value: 1, label: Text('Stock Opname')),
              ButtonSegment(value: 2, label: Text('Log Mutasi')),
            ],
            selected: {_modeSub},
            onSelectionChanged: (v) => setState(() => _modeSub = v.first),
          ),
        ),

        Expanded(
          child: _modeSub == 0
              ? _buildKatalogModern(t)
              : (_modeSub == 1 ? _buildStockOpnameMode(t) : _buildLogMutasiMode(t)),
        ),
      ],
    );
  }

  Widget _buildKatalogModern(AppThemeConfig t) {
    final q = _cariCtrl.text.trim().toLowerCase();
    final filtered = widget.daftarProduk.where((p) {
      if (_filterStok == 'Kritis' && p.stok > p.minStokAlert) return false;
      if (_filterStok == 'Habis' && p.stok > 0) return false;
      if (_filterStok == 'Grosir' && !(p.hargaGrosir > 0 && p.minQtyGrosir > 0)) {
        return false;
      }
      if (q.isEmpty) return true;
      return p.nama.toLowerCase().contains(q) ||
          p.kodeSku.toLowerCase().contains(q) ||
          p.kategori.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cariCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Cari nama barang, SKU / barcode, kategori...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 19),
                    isDense: true,
                    filled: true,
                    fillColor: t.surfaceColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: t.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                ),
                onPressed: () => _bukaFormProduk(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('SKU', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              for (final f in ['Semua', 'Kritis', 'Habis', 'Grosir'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(f, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    selected: _filterStok == f,
                    onSelected: (_) => setState(() => _filterStok = f),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'Tidak ada SKU yang cocok dengan filter.',
                    style: TextStyle(color: t.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (ctx, i) {
                    final prd = filtered[i];
                    final isHabis = prd.stok <= 0;
                    final isKritis = prd.stok <= prd.minStokAlert;
                    final targetCap = (prd.minStokAlert * 4).clamp(20, 100);
                    final ratio = (prd.stok / targetCap).clamp(0.0, 1.0);
                    final statusColor = isHabis
                        ? t.dangerColor
                        : (isKritis ? t.warningColor : t.successColor);

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: dekorasiKartu(
                        t,
                        borderOverride: isKritis ? statusColor.withAlpha(120) : t.borderColor,
                      ),
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
                                        StatusBadge(label: prd.kategori, color: t.primaryColor),
                                        const SizedBox(width: 6),
                                        Text(
                                          'SKU ${prd.kodeSku}',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: t.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      prd.nama,
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formatRupiah(prd.hargaJual),
                                    style: gayaAngka(
                                      TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        color: t.primaryColor,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'HPP ${formatRupiah(prd.hargaModal)}',
                                    style: TextStyle(fontSize: 10.5, color: t.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: ratio),
                                    duration: const Duration(milliseconds: 550),
                                    builder: (_, val, __) => LinearProgressIndicator(
                                      value: val,
                                      minHeight: 6,
                                      backgroundColor: t.inputColor,
                                      valueColor: AlwaysStoppedAnimation(statusColor),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Stok: ${prd.stok} ${prd.satuan}',
                                style: gayaAngka(
                                  TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _dialogMutasiCepat(prd, 'Masuk'),
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
                                label: const Text('Restok', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                              ),
                              const SizedBox(width: 6),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _dialogMutasiCepat(prd, 'Keluar'),
                                icon: const Icon(Icons.remove_circle_outline_rounded, size: 15),
                                label: const Text('Keluar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _bukaFormProduk(editProduk: prd),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => widget.onHapusProduk(prd.id),
                                icon: Icon(Icons.delete_outline_rounded, size: 18, color: t.dangerColor),
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

  Widget _buildStockOpnameMode(AppThemeConfig t) {
    _syncSoControllers();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      itemCount: widget.daftarProduk.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (ctx, i) {
        final prd = widget.daftarProduk[i];
        final ctrl = _soControllers[prd.id]!;
        final fisik = int.tryParse(ctrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? prd.stok;
        final selisih = fisik - prd.stok;
        final nilaiSelisih = selisih * prd.hargaModal;

        return Container(
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
                        Text(
                          prd.nama,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Stok Sistem: ${prd.stok} ${prd.satuan} • HPP ${formatRupiah(prd.hargaModal)}',
                          style: TextStyle(fontSize: 11, color: t.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 88,
                    child: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (_) => setState(() {}),
                      style: gayaAngka(const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                      decoration: InputDecoration(
                        labelText: 'Fisik',
                        isDense: true,
                        filled: true,
                        fillColor: t.inputColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selisih == 0
                          ? 'Selisih: 0 ${prd.satuan} (Balanced)'
                          : 'Selisih: ${selisih > 0 ? "+$selisih" : "$selisih"} ${prd.satuan} (${formatRupiah(nilaiSelisih)})',
                      style: gayaAngka(
                        TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: selisih == 0
                              ? t.successColor
                              : (selisih > 0 ? t.primaryColor : t.dangerColor),
                        ),
                      ),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: selisih == 0 ? t.inputColor : t.primaryColor,
                      foregroundColor: selisih == 0 ? t.textSecondary : Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _commitStockOpname(prd),
                    child: const Text('Catat SO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogMutasiMode(AppThemeConfig t) {
    final logs = [...widget.daftarLogStok]
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
    if (logs.isEmpty) {
      return Center(
        child: Text(
          'Belum ada riwayat mutasi stok terekam.',
          style: TextStyle(color: t.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final lg = logs[i];
        final isPlus = lg.perubahan >= 0;
        final badgeColor = lg.tipe == 'Opname'
            ? Colors.indigo
            : (isPlus ? t.successColor : t.dangerColor);
        return Container(
          padding: const EdgeInsets.all(11),
          decoration: dekorasiKartu(t),
          child: Row(
            children: [
              StatusBadge(label: lg.tipe, color: badgeColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lg.namaProduk,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${lg.keterangan} • ${lg.olehStaff}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: t.textSecondary),
                    ),
                    Text(
                      formatTanggalWaktu(lg.tanggal),
                      style: TextStyle(fontSize: 10, color: t.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isPlus ? '+${lg.perubahan}' : '${lg.perubahan}',
                    style: gayaAngka(
                      TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: badgeColor,
                      ),
                    ),
                  ),
                  Text(
                    'Akhir: ${lg.stokAkhir}',
                    style: TextStyle(fontSize: 10.5, color: t.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniStatBox extends StatelessWidget {
  final AppThemeConfig tema;
  final String label;
  final String value;
  final Color color;

  const _MiniStatBox({
    required this.tema,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: tema.inputColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tema.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: tema.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: gayaAngka(TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: color)),
          ),
        ],
      ),
    );
  }
}
