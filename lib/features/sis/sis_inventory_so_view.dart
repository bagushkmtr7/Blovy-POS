import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../widgets/pos_components.dart';

String _ringkasRp(int n) {
  final neg = n < 0 ? '-' : '';
  final absN = n.abs();
  if (absN >= 1000000000) {
    return '${neg}Rp ${(absN / 1000000000).toStringAsFixed(2)}M';
  }
  if (absN >= 1000000) {
    return '${neg}Rp ${(absN / 1000000).toStringAsFixed(2)}jt';
  }
  if (absN >= 1000) {
    return '${neg}Rp ${(absN / 1000).round()}rb';
  }
  return '${neg}Rp $absN';
}

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
    with TickerProviderStateMixin {
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

  void _commitStockOpname(Produk prd) {
    final fisik = int.tryParse((_soControllers[prd.id]?.text ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? prd.stok;
    final selisih = fisik - prd.stok;
    if (selisih == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${prd.nama}: fisik sesuai sistem (${prd.stok} ${prd.satuan}).')),
      );
      return;
    }
    widget.onMutasiStok(
      produk: prd,
      tipe: 'Opname',
      perubahan: selisih,
      keterangan: 'SO: Sistem ${prd.stok} -> Fisik $fisik (${selisih > 0 ? "+$selisih" : "$selisih"})',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tema;
    final totalSku = widget.daftarProduk.length;
    final hpp = widget.daftarProduk.fold<int>(0, (s, p) => s + (p.hargaModal * p.stok));
    final jual = widget.daftarProduk.fold<int>(0, (s, p) => s + (p.hargaJual * p.stok));
    final kritis = widget.daftarProduk.where((p) => p.stok <= p.minStokAlert).length;
    final jamStr =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  t.primaryColor.withAlpha(34),
                  t.surfaceColor,
                  t.accentColor.withAlpha(24),
                ],
              ),
              border: Border.all(color: t.primaryColor.withAlpha(75)),
            ),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _waveCtrl,
                  builder: (_, __) => ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    child: LinearProgressIndicator(
                      value: _waveCtrl.value,
                      minHeight: 3,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation(t.primaryColor),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseCtrl,
                            builder: (_, __) {
                              final v = _pulseCtrl.value;
                              return Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: t.successColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: t.successColor.withAlpha(((1 - v) * 180).round()),
                                      blurRadius: 6 + 6 * v,
                                      spreadRadius: 1 + 2 * v,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'INVENTORY & SO LIVE',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.7,
                                color: t.primaryColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: t.inputColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              jamStr,
                              style: gayaAngka(const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _GlowMetricTile(
                              tema: t,
                              title: 'SKU AKTIF',
                              value: '$totalSku',
                              accent: t.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: _GlowMetricTile(
                              tema: t,
                              title: 'KRITIS',
                              value: '$kritis',
                              accent: kritis > 0 ? t.dangerColor : t.successColor,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            flex: 2,
                            child: _GlowMetricTile(
                              tema: t,
                              title: 'HPP / POTENSI JUAL',
                              value: '${_ringkasRp(hpp)} • ${_ringkasRp(jual)}',
                              accent: t.accentColor,
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
        ),

        // Custom Pill Tabs (no checkmark!)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              for (final item in const [
                (0, 'Katalog'),
                (1, 'Stock Opname'),
                (2, 'Log Mutasi'),
              ]) ...[
                if (item.$1 > 0) const SizedBox(width: 7),
                Expanded(
                  child: _PillTabItem(
                    label: item.$2,
                    selected: _modeSub == item.$1,
                    color: t.primaryColor,
                    onTap: () => setState(() => _modeSub = item.$1),
                  ),
                ),
              ],
            ],
          ),
        ),

        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: _modeSub == 0
                ? _buildKatalog(t)
                : (_modeSub == 1 ? _buildSo(t) : _buildLog(t)),
          ),
        ),
      ],
    );
  }

  Widget _buildKatalog(AppThemeConfig t) {
    final q = _cariCtrl.text.trim().toLowerCase();
    final list = widget.daftarProduk.where((p) {
      if (_filterStok == 'Kritis' && p.stok > p.minStokAlert) return false;
      if (_filterStok == 'Habis' && p.stok > 0) return false;
      if (_filterStok == 'Grosir' && !(p.hargaGrosir > 0 && p.minQtyGrosir > 0)) return false;
      if (q.isEmpty) return true;
      return p.nama.toLowerCase().contains(q) ||
          p.kodeSku.toLowerCase().contains(q) ||
          p.kategori.toLowerCase().contains(q);
    }).toList();

    return Column(
      key: const ValueKey('inv_katalog'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cariCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Cari nama, SKU, kategori...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: t.surfaceColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: t.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final f in ['Semua', 'Kritis', 'Habis', 'Grosir'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _PillTabItem(
                    label: f,
                    selected: _filterStok == f,
                    color: t.primaryColor,
                    compact: true,
                    onTap: () => setState(() => _filterStok = f),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text('Tidak ada SKU cocok.', style: TextStyle(color: t.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (ctx, i) {
                    final prd = filteredItem(list, i);
                    final isHabis = prd.stok <= 0;
                    final isKritis = prd.stok <= prd.minStokAlert;
                    final cap = (prd.minStokAlert * 4).clamp(20, 100);
                    final ratio = (prd.stok / cap).clamp(0.0, 1.0);
                    final clr = isHabis ? t.dangerColor : (isKritis ? t.warningColor : t.successColor);

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.surfaceColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: isKritis ? clr.withAlpha(140) : t.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                        StatusBadge(label: prd.kategori, color: t.primaryColor),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            prd.kodeSku,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 10.5, color: t.textSecondary),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      prd.nama,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formatRupiah(prd.hargaJual),
                                    style: gayaAngka(
                                      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: t.primaryColor),
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
                                  borderRadius: BorderRadius.circular(8),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: ratio),
                                    duration: const Duration(milliseconds: 500),
                                    builder: (_, val, __) => LinearProgressIndicator(
                                      value: val,
                                      minHeight: 7,
                                      backgroundColor: t.inputColor,
                                      valueColor: AlwaysStoppedAnimation(clr),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${prd.stok} ${prd.satuan}',
                                style: gayaAngka(
                                  TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: clr),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _PillTabItem(
                                label: '+ Restok',
                                selected: false,
                                color: t.successColor,
                                compact: true,
                                onTap: () => _dialogMutasiCepat(prd, 'Masuk'),
                              ),
                              const SizedBox(width: 6),
                              _PillTabItem(
                                label: '- Keluar',
                                selected: false,
                                color: t.dangerColor,
                                compact: true,
                                onTap: () => _dialogMutasiCepat(prd, 'Keluar'),
                              ),
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

  Produk filteredItem(List<Produk> list, int i) => list[i];

  Widget _buildSo(AppThemeConfig t) {
    _syncSoControllers();
    return ListView.separated(
      key: const ValueKey('inv_so'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: widget.daftarProduk.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (ctx, i) {
        final prd = widget.daftarProduk[i];
        final ctrl = _soControllers[prd.id]!;
        final fisik = int.tryParse(ctrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? prd.stok;
        final selisih = fisik - prd.stok;
        final clr = selisih == 0 ? t.successColor : (selisih > 0 ? t.primaryColor : t.dangerColor);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.surfaceColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: t.borderColor),
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
                        Text(prd.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                        Text('Sistem: ${prd.stok} ${prd.satuan} • HPP ${formatRupiah(prd.hargaModal)}', style: TextStyle(fontSize: 11, color: t.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 82,
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
                    child: Text(
                      selisih == 0
                          ? 'Selisih: 0 ${prd.satuan} (Klop)'
                          : 'Selisih: ${selisih > 0 ? "+$selisih" : "$selisih"} ${prd.satuan} (${_ringkasRp(selisih * prd.hargaModal)})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: gayaAngka(TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: clr)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PillTabItem(
                    label: 'Catat SO',
                    selected: selisih != 0,
                    color: t.primaryColor,
                    compact: true,
                    onTap: () => _commitStockOpname(prd),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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
