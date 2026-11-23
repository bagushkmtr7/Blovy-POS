import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../widgets/pos_components.dart';

class ExecutiveDashboardView extends StatefulWidget {
  final AppThemeConfig tema;
  final PengaturanToko toko;
  final List<Produk> daftarProduk;
  final List<TransaksiPos> daftarTransaksi;
  final List<PengeluaranToko> daftarPengeluaran;
  final List<ShiftKasir> daftarShift;
  final List<MemberPelanggan> daftarMember;
  final String periodeTerpilih;
  final ValueChanged<String> onUbahPeriode;
  final void Function({
    required Produk produk,
    required String tipe,
    required int perubahan,
    required String keterangan,
  }) onMutasiStok;
  final VoidCallback? onBukaTabDeadStock;

  const ExecutiveDashboardView({
    super.key,
    required this.tema,
    required this.toko,
    required this.daftarProduk,
    required this.daftarTransaksi,
    required this.daftarPengeluaran,
    required this.daftarShift,
    required this.daftarMember,
    required this.periodeTerpilih,
    required this.onUbahPeriode,
    required this.onMutasiStok,
    this.onBukaTabDeadStock,
  });

  @override
  State<ExecutiveDashboardView> createState() => _ExecutiveDashboardViewState();
}

class _ExecutiveDashboardViewState extends State<ExecutiveDashboardView>
    with TickerProviderStateMixin {
  static const String _keyTargetHarian = 'sis_target_harian_v1';
  static const List<String> _opsiPeriode = [
    'Hari Ini',
    'Kemarin',
    '7 Hari',
    '30 Hari',
    'Semua',
  ];

  late AnimationController _pulseCtrl;
  late AnimationController _waveCtrl;
  late AnimationController _chartEntryCtrl;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  int _targetHarian = 3000000;
  int? _jamTersentuh;
  int _modeLeaderboard = 0; // 0 = Top Omzet/Qty, 1 = Top Margin

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _chartEntryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..forward();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _muatTarget();
  }

  @override
  void didUpdateWidget(covariant ExecutiveDashboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.periodeTerpilih != widget.periodeTerpilih ||
        oldWidget.daftarTransaksi.length != widget.daftarTransaksi.length) {
      _jamTersentuh = null;
      _chartEntryCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _chartEntryCtrl.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _muatTarget() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_keyTargetHarian);
    if (saved != null && saved > 0 && mounted) {
      setState(() => _targetHarian = saved);
    }
  }

  Future<void> _simpanTarget(int baru) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTargetHarian, baru);
    if (mounted) setState(() => _targetHarian = baru);
  }

  bool _masukPeriode(DateTime tgl, String periode) {
    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    if (periode == 'Hari Ini') {
      return !tgl.isBefore(startToday);
    }
    if (periode == 'Kemarin') {
      final startYesterday = startToday.subtract(const Duration(days: 1));
      return !tgl.isBefore(startYesterday) && tgl.isBefore(startToday);
    }
    if (periode == '7 Hari') {
      return !tgl.isBefore(startToday.subtract(const Duration(days: 6)));
    }
    if (periode == '30 Hari') {
      return !tgl.isBefore(startToday.subtract(const Duration(days: 29)));
    }
    return true;
  }

  bool _masukPeriodePembanding(DateTime tgl, String periode) {
    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    if (periode == 'Hari Ini') {
      final startYesterday = startToday.subtract(const Duration(days: 1));
      return !tgl.isBefore(startYesterday) && tgl.isBefore(startToday);
    }
    if (periode == 'Kemarin') {
      final start2Days = startToday.subtract(const Duration(days: 2));
      final startYesterday = startToday.subtract(const Duration(days: 1));
      return !tgl.isBefore(start2Days) && tgl.isBefore(startYesterday);
    }
    if (periode == '7 Hari') {
      final s1 = startToday.subtract(const Duration(days: 13));
      final e1 = startToday.subtract(const Duration(days: 6));
      return !tgl.isBefore(s1) && tgl.isBefore(e1);
    }
    if (periode == '30 Hari') {
      final s1 = startToday.subtract(const Duration(days: 59));
      final e1 = startToday.subtract(const Duration(days: 29));
      return !tgl.isBefore(s1) && tgl.isBefore(e1);
    }
    return false;
  }

  int _multiplierTarget() {
    switch (widget.periodeTerpilih) {
      case '7 Hari':
        return 7;
      case '30 Hari':
        return 30;
      case 'Semua':
        return 30;
      default:
        return 1;
    }
  }

  void _dialogEditTarget() {
    final t = widget.tema;
    final ctrl = TextEditingController(text: _targetHarian.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Atur Target Omzet Harian',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Target harian digunakan untuk menghitung persentase pencapaian & proyeksi run-rate toko.',
              style: TextStyle(fontSize: 11.5, color: t.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: gayaAngka(const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              decoration: InputDecoration(
                labelText: 'Target Harian (Rp)',
                prefixText: 'Rp ',
                filled: true,
                fillColor: t.inputColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in [1500000, 3000000, 5000000, 10000000, 15000000])
                  ActionChip(
                    label: Text(formatRupiah(p), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    onPressed: () => ctrl.text = p.toString(),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: t.primaryColor, foregroundColor: Colors.white),
            onPressed: () {
              final val = int.tryParse(ctrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              if (val > 0) _simpanTarget(val);
              Navigator.pop(ctx);
            },
            child: const Text('Simpan Target', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _dialogQuickRestok(Produk prd) {
    final t = widget.tema;
    final qtyCtrl = TextEditingController(text: '24');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.add_box_rounded, color: t.primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Restok Cepat • ${prd.nama}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Stok saat ini: ${prd.stok} ${prd.satuan} (Min. Alert: ${prd.minStokAlert})',
              style: TextStyle(fontSize: 12, color: t.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: gayaAngka(const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              decoration: InputDecoration(
                labelText: 'Jumlah Tambah Stok (${prd.satuan})',
                filled: true,
                fillColor: t.inputColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final q in [12, 24, 50, 100])
                  ActionChip(
                    label: Text('+$q', style: const TextStyle(fontWeight: FontWeight.w800)),
                    onPressed: () => qtyCtrl.text = q.toString(),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: t.successColor, foregroundColor: Colors.white),
            onPressed: () {
              final tambah = int.tryParse(qtyCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              if (tambah > 0) {
                widget.onMutasiStok(
                  produk: prd,
                  tipe: 'Masuk',
                  perubahan: tambah,
                  keterangan: 'Quick Restock via Executive Dashboard SIS',
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Stok ${prd.nama} +$tambah ${prd.satuan} berhasil disinkronkan!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.check_rounded, size: 17),
            label: const Text('Simpan & Sinkron', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tema;
    final trxList = widget.daftarTransaksi
        .where((e) => _masukPeriode(e.tanggal, widget.periodeTerpilih))
        .toList();
    final trxPrev = widget.daftarTransaksi
        .where((e) => _masukPeriodePembanding(e.tanggal, widget.periodeTerpilih))
        .toList();
    final expList = widget.daftarPengeluaran
        .where((e) => _masukPeriode(e.tanggal, widget.periodeTerpilih))
        .toList();

    // Kalkulasi KPI Utama
    final netSales = trxList.fold<int>(0, (s, e) => s + e.totalBelanja);
    final prevNetSales = trxPrev.fold<int>(0, (s, e) => s + e.totalBelanja);
    final grossProfit = trxList.fold<int>(0, (s, e) => s + e.estimasiLabaKotor);
    final totalBiaya = expList.fold<int>(0, (s, e) => s + e.nominal);
    final netProfit = grossProfit - totalBiaya;
    final grossMarginPct = netSales > 0 ? (grossProfit / netSales) * 100 : 0.0;
    final totalDiskon = trxList.fold<int>(0, (s, e) => s + e.diskon);
    final totalPiutang = trxList.fold<int>(0, (s, e) => s + e.sisaPiutang);
    final totalQty = trxList.fold<int>(
      0,
      (s, e) => s + e.items.fold<int>(0, (si, it) => si + it.qty),
    );
    final atv = trxList.isEmpty ? 0 : (netSales ~/ trxList.length);
    final upt = trxList.isEmpty ? 0.0 : (totalQty / trxList.length);

    final growthPct = prevNetSales > 0
        ? ((netSales - prevNetSales) / prevNetSales) * 100
        : (netSales > 0 ? 100.0 : 0.0);

    final targetPeriode = _targetHarian * _multiplierTarget();
    final pencapaianTarget =
        targetPeriode > 0 ? (netSales / targetPeriode).clamp(0.0, 1.5) : 0.0;

    // Proyeksi Run-Rate Hari Ini (jam operasional 07:00 - 22:00 = 15 jam)
    final jamBerjalan = (_now.hour - 7).clamp(1, 15);
    final proyeksiEod = widget.periodeTerpilih == 'Hari Ini' && netSales > 0
        ? ((netSales / jamBerjalan) * 15).round()
        : netSales;

    // Data Grafik Per Jam (24 Jam)
    final hourlySales = List<int>.filled(24, 0);
    final hourlyProfit = List<int>.filled(24, 0);
    final hourlyCount = List<int>.filled(24, 0);
    for (final trx in trxList) {
      final h = trx.tanggal.hour.clamp(0, 23);
      hourlySales[h] += trx.totalBelanja;
      hourlyProfit[h] += trx.estimasiLabaKotor;
      hourlyCount[h] += 1;
    }
    int peakHour = 0;
    for (int i = 1; i < 24; i++) {
      if (hourlySales[i] > hourlySales[peakHour]) peakHour = i;
    }

    // Komposisi Metode Pembayaran
    final Map<String, int> payMix = {};
    for (final trx in trxList) {
      final m = trx.metodeBayar.isEmpty ? 'Tunai' : trx.metodeBayar;
      payMix[m] = (payMix[m] ?? 0) + trx.totalBelanja;
    }
    final payEntries = payMix.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Peta Kategori Produk
    final Map<String, String> mapKategoriProduk = {
      for (final p in widget.daftarProduk) p.id: p.kategori,
    };
    final Map<String, int> catSales = {};
    final Map<String, _ProductAgg> prodAgg = {};

    for (final trx in trxList) {
      for (final it in trx.items) {
        final kat = mapKategoriProduk[it.produkId] ?? 'Umum';
        catSales[kat] = (catSales[kat] ?? 0) + it.subtotal;

        final prev = prodAgg[it.namaProduk];
        final labaItem = it.subtotal - it.totalModal;
        if (prev == null) {
          prodAgg[it.namaProduk] = _ProductAgg(
            nama: it.namaProduk,
            qty: it.qty,
            omzet: it.subtotal,
            laba: labaItem,
          );
        } else {
          prodAgg[it.namaProduk] = _ProductAgg(
            nama: it.namaProduk,
            qty: prev.qty + it.qty,
            omzet: prev.omzet + it.subtotal,
            laba: prev.laba + labaItem,
          );
        }
      }
    }
    final catEntries = catSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topProducts = prodAgg.values.toList()
      ..sort((a, b) => _modeLeaderboard == 0
          ? b.omzet.compareTo(a.omzet)
          : b.laba.compareTo(a.laba));

    // Performa Kasir
    final Map<String, _CashierAgg> cashierMap = {};
    for (final trx in trxList) {
      final k = trx.namaKasir.isEmpty ? 'Kasir' : trx.namaKasir;
      final prev = cashierMap[k];
      if (prev == null) {
        cashierMap[k] = _CashierAgg(nama: k, struk: 1, omzet: trx.totalBelanja);
      } else {
        cashierMap[k] = _CashierAgg(
          nama: k,
          struk: prev.struk + 1,
          omzet: prev.omzet + trx.totalBelanja,
        );
      }
    }
    final cashierList = cashierMap.values.toList()
      ..sort((a, b) => b.omzet.compareTo(a.omzet));

    // Alert Stok Menipis / Habis
    final stokAlertList = widget.daftarProduk
        .where((p) => p.stok <= p.minStokAlert)
        .toList()
      ..sort((a, b) => a.stok.compareTo(b.stok));

    // 6 Transaksi Terbaru
    final recentTrx = [...widget.daftarTransaksi]
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
    final feedTrx = recentTrx.take(6).toList();

    final jamStr =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. LIVE TELEMETRY HEADER BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: dekorasiKartu(t),
            child: Row(
              children: [
                _LiveRadarDot(animation: _pulseCtrl, color: t.successColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'EXECUTIVE CONTROL TOWER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: t.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: t.successColor.withAlpha(24),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              'LIVE STREAM',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                color: t.successColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        feedTrx.isNotEmpty
                            ? 'Struk terakhir: ${feedTrx.first.nomorStruk} (${formatRupiah(feedTrx.first.totalBelanja)}) • ${feedTrx.first.namaKasir}'
                            : 'Menunggu transaksi masuk dari terminal BLOVY POS...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: t.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: t.inputColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: t.borderColor),
                  ),
                  child: Text(
                    jamStr,
                    style: gayaAngka(
                      TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: t.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 2. FILTER PERIODE DINAMIS
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _opsiPeriode.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (ctx, i) {
                final p = _opsiPeriode[i];
                final selected = p == widget.periodeTerpilih;
                return TactilePress(
                  onTap: () => widget.onUbahPeriode(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected ? t.primaryColor : t.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? t.primaryColor : t.borderColor,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: t.primaryColor.withAlpha(65),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Text(
                      p,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : t.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // 3. HERO EXECUTIVE REVENUE DECK (Animated Wave + Target Gauge)
          ClipRRect(
            borderRadius: BorderRadius.circular(t.radius + 6),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    t.primaryColor,
                    Color.lerp(t.primaryColor, const Color(0xFF0F172A), 0.45)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: t.primaryColor.withAlpha(75),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _waveCtrl,
                      builder: (_, __) => CustomPaint(
                        painter: _FluidWavePainter(progress: _waveCtrl.value),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
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
                                      Text(
                                        'NET SALES • ${widget.periodeTerpilih.toUpperCase()}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.7,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (widget.periodeTerpilih != 'Semua')
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: growthPct >= 0
                                                ? Colors.greenAccent.withAlpha(45)
                                                : Colors.redAccent.withAlpha(55),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${growthPct >= 0 ? "▲" : "▼"} ${growthPct.abs().toStringAsFixed(1)}%',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                              color: growthPct >= 0
                                                  ? Colors.greenAccent
                                                  : Colors.amberAccent,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  _AnimatedRupiahText(
                                    value: netSales,
                                    style: gayaAngka(
                                      const TextStyle(
                                        color: Colors.white,
                                        fontSize: 27,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Proyeksi EOD: ${formatRupiah(proyeksiEod)} • ${trxList.length} Struk',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Animated Target Circular Gauge
                            GestureDetector(
                              onTap: _dialogEditTarget,
                              child: SizedBox(
                                width: 82,
                                height: 82,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: pencapaianTarget.clamp(0.0, 1.0)),
                                  duration: const Duration(milliseconds: 900),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, val, _) {
                                    final pctText =
                                        '${(pencapaianTarget * 100).clamp(0, 999).toStringAsFixed(0)}%';
                                    return CustomPaint(
                                      painter: _CircularGaugePainter(
                                        progress: val,
                                        trackColor: Colors.white24,
                                        progressColor: pencapaianTarget >= 1.0
                                            ? Colors.greenAccent
                                            : Colors.amberAccent,
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              pctText,
                                              style: gayaAngka(
                                                const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                            const Text(
                                              'TARGET',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(45),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.flag_rounded, color: Colors.amberAccent, size: 15),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Target ${widget.periodeTerpilih}: ${formatRupiah(targetPeriode)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: _dialogEditTarget,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Text(
                                    'Ubah Target ✎',
                                    style: TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 4. GRID 6 KPI RETAIL ENTERPRISE
          LayoutBuilder(
            builder: (ctx, box) {
              final isWide = box.maxWidth >= 720;
              final crossCount = isWide ? 3 : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossCount,
                mainAxisSpacing: 9,
                crossAxisSpacing: 9,
                childAspectRatio: isWide ? 2.25 : 1.78,
                children: [
                  _KpiEnterpriseTile(
                    tema: t,
                    judul: 'GROSS PROFIT',
                    nilai: grossProfit,
                    isRupiah: true,
                    sub: 'Margin ${grossMarginPct.toStringAsFixed(1)}%',
                    icon: Icons.trending_up_rounded,
                    accent: t.successColor,
                  ),
                  _KpiEnterpriseTile(
                    tema: t,
                    judul: 'NET OPERATING PROFIT',
                    nilai: netProfit,
                    isRupiah: true,
                    sub: 'Biaya Ops ${formatRupiah(totalBiaya)}',
                    icon: Icons.account_balance_wallet_rounded,
                    accent: netProfit >= 0 ? t.primaryColor : t.dangerColor,
                  ),
                  _KpiEnterpriseTile(
                    tema: t,
                    judul: 'BASKET SIZE (ATV)',
                    nilai: atv,
                    isRupiah: true,
                    sub: 'Rata-rata per struk',
                    icon: Icons.shopping_bag_rounded,
                    accent: t.accentColor,
                  ),
                  _KpiEnterpriseTile(
                    tema: t,
                    judul: 'VOLUME & UPT',
                    nilai: totalQty,
                    isRupiah: false,
                    suffixText: ' pcs',
                    sub: '${upt.toStringAsFixed(1)} item / transaksi',
                    icon: Icons.inventory_2_rounded,
                    accent: Colors.indigo,
                  ),
                  _KpiEnterpriseTile(
                    tema: t,
                    judul: 'TOTAL PROMO & DISKON',
                    nilai: totalDiskon,
                    isRupiah: true,
                    sub: 'Potongan kampanye POS',
                    icon: Icons.local_offer_rounded,
                    accent: Colors.deepOrange,
                  ),
                  _KpiEnterpriseTile(
                    tema: t,
                    judul: 'PIUTANG / KASBON',
                    nilai: totalPiutang,
                    isRupiah: true,
                    sub: '${widget.daftarMember.length} Member terdaftar',
                    icon: Icons.receipt_long_rounded,
                    accent: totalPiutang > 0 ? t.warningColor : t.textSecondary,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // 5. GRAFIK 1: INTERACTIVE HOURLY SALES & PROFIT AREA CHART
          Container(
            padding: const EdgeInsets.all(14),
            decoration: dekorasiKartu(t),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.show_chart_rounded, color: t.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kurva Penjualan & Laba Per Jam',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Geser jari pada grafik untuk inspeksi trafik jam sibuk',
                            style: TextStyle(fontSize: 10.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    if (hourlySales[peakHour] > 0)
                      StatusBadge(
                        label: 'PEAK ${peakHour.toString().padLeft(2, '0')}:00',
                        color: t.primaryColor,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // Tooltip Info Jam Tersentuh
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: t.inputColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: t.borderColor),
                  ),
                  child: Builder(
                    builder: (_) {
                      final h = _jamTersentuh ?? peakHour;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pukul ${h.toString().padLeft(2, '0')}:00 - ${h.toString().padLeft(2, '0')}:59',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Omzet ${formatRupiah(hourlySales[h])} • Laba ${formatRupiah(hourlyProfit[h])} (${hourlyCount[h]} trx)',
                            style: gayaAngka(
                              TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: t.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 185,
                  child: LayoutBuilder(
                    builder: (ctx, box) {
                      void updateTouch(Offset localPos) {
                        final idx = ((localPos.dx / box.maxWidth) * 23)
                            .round()
                            .clamp(0, 23);
                        if (_jamTersentuh != idx) {
                          setState(() => _jamTersentuh = idx);
                        }
                      }

                      return GestureDetector(
                        onTapDown: (d) => updateTouch(d.localPosition),
                        onHorizontalDragUpdate: (d) => updateTouch(d.localPosition),
                        child: AnimatedBuilder(
                          animation: _chartEntryCtrl,
                          builder: (_, __) => CustomPaint(
                            size: Size(box.maxWidth, 185),
                            painter: _HourlyBezierChartPainter(
                              sales: hourlySales,
                              profits: hourlyProfit,
                              progress: CurvedAnimation(
                                parent: _chartEntryCtrl,
                                curve: Curves.easeOutCubic,
                              ).value,
                              primaryColor: t.primaryColor,
                              profitColor: t.successColor,
                              gridColor: t.borderColor,
                              textColor: t.textSecondary,
                              selectedHour: _jamTersentuh ?? peakHour,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendDot(color: t.primaryColor, label: 'Omzet Penjualan'),
                    const SizedBox(width: 16),
                    _LegendDot(color: t.successColor, label: 'Gross Profit'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 6. GRAFIK 2 & 3: PAYMENT MIX DONUT + CATEGORY PERFORMANCE
          LayoutBuilder(
            builder: (ctx, box) {
              final isWide = box.maxWidth >= 720;
              final paymentCard = _buildPaymentDonutCard(t, payEntries, netSales);
              final categoryCard = _buildCategoryMixCard(t, catEntries, netSales);
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: paymentCard),
                    const SizedBox(width: 12),
                    Expanded(child: categoryCard),
                  ],
                );
              }
              return Column(
                children: [
                  paymentCard,
                  const SizedBox(height: 12),
                  categoryCard,
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // 7. STORE HEALTH RADAR & ONE-TAP QUICK RESTOCK
          Container(
            padding: const EdgeInsets.all(14),
            decoration: dekorasiKartu(
              t,
              borderOverride: stokAlertList.isNotEmpty
                  ? t.warningColor.withAlpha(130)
                  : t.borderColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.health_and_safety_rounded,
                      color: stokAlertList.isNotEmpty ? t.warningColor : t.successColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Store Health Radar & Restok Cepat',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (widget.onBukaTabDeadStock != null)
                      TextButton(
                        onPressed: widget.onBukaTabDeadStock,
                        child: const Text(
                          'Analisis Dead Stock →',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (stokAlertList.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: t.successColor.withAlpha(18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.verified_rounded, color: t.successColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Seluruh stok SKU berada di atas batas minimum aman.',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: t.successColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      for (final prd in stokAlertList.take(5))
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: prd.stok == 0
                                ? t.dangerColor.withAlpha(18)
                                : t.warningColor.withAlpha(16),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: prd.stok == 0
                                  ? t.dangerColor.withAlpha(90)
                                  : t.warningColor.withAlpha(80),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      prd.nama,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      'SKU ${prd.kodeSku} • Sisa ${prd.stok} ${prd.satuan} (Min ${prd.minStokAlert})',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: prd.stok == 0 ? t.dangerColor : t.warningColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: t.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: const Size(0, 32),
                                ),
                                onPressed: () => _dialogQuickRestok(prd),
                                icon: const Icon(Icons.add_rounded, size: 15),
                                label: const Text(
                                  'Restok',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 8. TOP 5 PRODUK LEADERBOARD & CASHIER SCORECARD
          Container(
            padding: const EdgeInsets.all(14),
            decoration: dekorasiKartu(t),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events_rounded, color: Colors.amber.shade700, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Top 5 Produk Unggulan',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                    SegmentedButton<int>(
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        textStyle: WidgetStateProperty.all(
                          const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Omzet')),
                        ButtonSegment(value: 1, label: Text('Laba')),
                      ],
                      selected: {_modeLeaderboard},
                      onSelectionChanged: (v) => setState(() => _modeLeaderboard = v.first),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (topProducts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'Belum ada penjualan pada periode ${widget.periodeTerpilih}.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: t.textSecondary),
                    ),
                  )
                else
                  Column(
                    children: [
                      for (int i = 0; i < math.min(5, topProducts.length); i++)
                        Builder(
                          builder: (_) {
                            final item = topProducts[i];
                            final maxVal = _modeLeaderboard == 0
                                ? topProducts.first.omzet
                                : topProducts.first.laba;
                            final curVal = _modeLeaderboard == 0 ? item.omzet : item.laba;
                            final ratio = maxVal > 0 ? (curVal / maxVal).clamp(0.05, 1.0) : 0.0;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: i == 0
                                              ? Colors.amber
                                              : (i == 1
                                                  ? Colors.blueGrey.shade300
                                                  : t.inputColor),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${i + 1}',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w900,
                                            color: i <= 1 ? Colors.black : t.textPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item.nama,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${item.qty} pcs • ${formatRupiah(curVal)}',
                                        style: gayaAngka(
                                          TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w900,
                                            color: t.primaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0, end: ratio),
                                      duration: Duration(milliseconds: 650 + (i * 100)),
                                      curve: Curves.easeOutCubic,
                                      builder: (_, val, __) => LinearProgressIndicator(
                                        value: val,
                                        minHeight: 6,
                                        backgroundColor: t.inputColor,
                                        valueColor: AlwaysStoppedAnimation(
                                          _modeLeaderboard == 0 ? t.primaryColor : t.successColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 9. CASHIER PERFORMANCE SCORECARD
          if (cashierList.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: dekorasiKartu(t),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.badge_rounded, color: t.accentColor, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Cashier & Kassa Scorecard',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (int i = 0; i < cashierList.length; i++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                      decoration: BoxDecoration(
                        color: t.inputColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: t.borderColor),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: t.primaryColor.withAlpha(26),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: t.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cashierList[i].nama,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '${cashierList[i].struk} Struk • ATV ${formatRupiah(cashierList[i].omzet ~/ cashierList[i].struk)}',
                                  style: TextStyle(fontSize: 10.5, color: t.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatRupiah(cashierList[i].omzet),
                            style: gayaAngka(
                              TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: t.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 10. LIVE STRUK FEED (REAL-TIME DARI BLOVY POS)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: dekorasiKartu(t),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_rounded, color: t.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Live Struk Feed (Real-Time POS)',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      'Ketuk untuk cetak/inspeksi',
                      style: TextStyle(fontSize: 10.5, color: t.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (feedTrx.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'Belum ada transaksi terekam.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: t.textSecondary),
                    ),
                  )
                else
                  Column(
                    children: [
                      for (final trx in feedTrx)
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => Container(
                              margin: const EdgeInsets.only(top: 60),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: t.surfaceColor,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              child: SafeArea(
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              widget.toko.namaToko,
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
                                      Text(
                                        'Struk ${trx.nomorStruk} • ${formatTanggalWaktu(trx.tanggal)}',
                                        style: TextStyle(fontSize: 11.5, color: t.textSecondary),
                                      ),
                                      Text(
                                        'Kasir: ${trx.namaKasir} • Bayar: ${trx.metodeBayar}',
                                        style: TextStyle(fontSize: 11.5, color: t.textSecondary),
                                      ),
                                      const Divider(height: 18),
                                      for (final it in trx.items)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${it.qty}x ${it.namaProduk}',
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                formatRupiah(it.subtotal),
                                                style: gayaAngka(
                                                  const TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      const Divider(height: 18),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'TOTAL BELANJA',
                                            style: TextStyle(fontWeight: FontWeight.w900),
                                          ),
                                          Text(
                                            formatRupiah(trx.totalBelanja),
                                            style: gayaAngka(
                                              TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                color: t.primaryColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                            decoration: BoxDecoration(
                              color: t.inputColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: t.borderColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: t.primaryColor.withAlpha(22),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.point_of_sale_rounded,
                                    size: 16,
                                    color: t.primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${trx.nomorStruk} • ${trx.namaKasir}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        '${formatTanggalWaktu(trx.tanggal)} • ${trx.metodeBayar} • ${trx.items.length} item',
                                        style: TextStyle(fontSize: 10.5, color: t.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      formatRupiah(trx.totalBelanja),
                                      style: gayaAngka(
                                        TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w900,
                                          color: t.successColor,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Lihat Struk ›',
                                      style: TextStyle(fontSize: 10, color: t.primaryColor),
                                    ),
                                  ],
                                ),
                              ],
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
    );
  }

  Widget _buildPaymentDonutCard(
    AppThemeConfig t,
    List<MapEntry<String, int>> entries,
    int totalOmzet,
  ) {
    final palette = [
      t.primaryColor,
      t.successColor,
      Colors.amber.shade700,
      Colors.purple,
      Colors.deepOrange,
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: dekorasiKartu(t),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.donut_large_rounded, color: t.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Komposisi Metode Bayar',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty || totalOmzet <= 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Belum ada data pembayaran.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: t.textSecondary),
              ),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 112,
                  height: 112,
                  child: AnimatedBuilder(
                    animation: _chartEntryCtrl,
                    builder: (_, __) => CustomPaint(
                      painter: _DonutChartPainter(
                        values: entries.map((e) => e.value.toDouble()).toList(),
                        colors: List.generate(
                          entries.length,
                          (i) => palette[i % palette.length],
                        ),
                        progress: CurvedAnimation(
                          parent: _chartEntryCtrl,
                          curve: Curves.easeOutCubic,
                        ).value,
                      ),
                      child: Center(
                        child: Text(
                          '${entries.length}\nMetode',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      for (int i = 0; i < entries.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: palette[i % palette.length],
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  entries[i].key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '${((entries[i].value / totalOmzet) * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: t.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                formatRupiah(entries[i].value),
                                style: gayaAngka(
                                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryMixCard(
    AppThemeConfig t,
    List<MapEntry<String, int>> entries,
    int totalOmzet,
  ) {
    final palette = [
      Colors.indigo,
      t.accentColor,
      t.successColor,
      Colors.deepOrange,
      Colors.teal,
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: dekorasiKartu(t),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.category_rounded, color: t.accentColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Kontribusi Per Kategori',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty || totalOmzet <= 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Belum ada kontribusi kategori.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: t.textSecondary),
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < math.min(5, entries.length); i++)
                  Builder(
                    builder: (_) {
                      final pct = (entries[i].value / totalOmzet).clamp(0.0, 1.0);
                      final c = palette[i % palette.length];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entries[i].key,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(pct * 100).toStringAsFixed(1)}% • ${formatRupiah(entries[i].value)}',
                                  style: gayaAngka(
                                    TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: c,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: pct),
                                duration: Duration(milliseconds: 700 + (i * 90)),
                                curve: Curves.easeOutCubic,
                                builder: (_, v, __) => LinearProgressIndicator(
                                  value: v,
                                  minHeight: 6,
                                  backgroundColor: t.inputColor,
                                  valueColor: AlwaysStoppedAnimation(c),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ProductAgg {
  final String nama;
  final int qty;
  final int omzet;
  final int laba;

  const _ProductAgg({
    required this.nama,
    required this.qty,
    required this.omzet,
    required this.laba,
  });
}

class _CashierAgg {
  final String nama;
  final int struk;
  final int omzet;

  const _CashierAgg({
    required this.nama,
    required this.struk,
    required this.omzet,
  });
}

class _LiveRadarDot extends StatelessWidget {
  final Animation<double> animation;
  final Color color;

  const _LiveRadarDot({required this.animation, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final v = animation.value;
        return SizedBox(
          width: 22,
          height: 22,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 8 + (14 * v),
                height: 8 + (14 * v),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withAlpha(((1 - v) * 110).round()),
                ),
              ),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedRupiahText extends StatelessWidget {
  final int value;
  final TextStyle style;

  const _AnimatedRupiahText({required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeOutCubic,
      builder: (_, val, __) => Text(
        formatRupiah(val.round()),
        style: style,
      ),
    );
  }
}

class _KpiEnterpriseTile extends StatelessWidget {
  final AppThemeConfig tema;
  final String judul;
  final int nilai;
  final bool isRupiah;
  final String suffixText;
  final String sub;
  final IconData icon;
  final Color accent;

  const _KpiEnterpriseTile({
    required this.tema,
    required this.judul,
    required this.nilai,
    required this.isRupiah,
    this.suffixText = '',
    required this.sub,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: dekorasiKartu(tema),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: accent.withAlpha(24),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 15, color: accent),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  judul,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: tema.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: nilai.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, val, __) {
              final text = isRupiah
                  ? formatRupiah(val.round())
                  : '${val.round()}$suffixText';
              return Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: gayaAngka(
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              );
            },
          ),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: tema.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _FluidWavePainter extends CustomPainter {
  final double progress;
  const _FluidWavePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = Colors.white.withAlpha(14);
    final paint2 = Paint()..color = Colors.white.withAlpha(10);

    final path1 = Path()..moveTo(0, size.height);
    final path2 = Path()..moveTo(0, size.height);

    for (double x = 0; x <= size.width; x += 6) {
      final y1 = size.height * 0.65 +
          math.sin((x / size.width * 2 * math.pi) + (progress * 2 * math.pi)) * 12;
      final y2 = size.height * 0.75 +
          math.cos((x / size.width * 2 * math.pi) - (progress * 2 * math.pi)) * 10;
      path1.lineTo(x, y1);
      path2.lineTo(x, y2);
    }

    path1
      ..lineTo(size.width, size.height)
      ..close();
    path2
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path1, paint1);
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant _FluidWavePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _CircularGaugePainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  const _CircularGaugePainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 5;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;

    final progPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularGaugePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _HourlyBezierChartPainter extends CustomPainter {
  final List<int> sales;
  final List<int> profits;
  final double progress;
  final Color primaryColor;
  final Color profitColor;
  final Color gridColor;
  final Color textColor;
  final int selectedHour;

  const _HourlyBezierChartPainter({
    required this.sales,
    required this.profits,
    required this.progress,
    required this.primaryColor,
    required this.profitColor,
    required this.gridColor,
    required this.textColor,
    required this.selectedHour,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const bottomPad = 20.0;
    const topPad = 10.0;
    final chartH = size.height - bottomPad - topPad;

    final maxVal = math.max(
      1,
      sales.reduce((a, b) => a > b ? a : b),
    );

    // Grid horizontal
    final gridPaint = Paint()
      ..color = gridColor.withAlpha(110)
      ..strokeWidth = 1;
    for (int g = 0; g <= 3; g++) {
      final y = topPad + (chartH * g / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    List<Offset> buildPoints(List<int> data) {
      return List.generate(24, (i) {
        final x = (size.width / 23) * i;
        final ratio = (data[i] / maxVal) * progress;
        final y = topPad + chartH - (ratio * chartH);
        return Offset(x, y);
      });
    }

    Path buildSmoothPath(List<Offset> pts) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 0; i < pts.length - 1; i++) {
        final p0 = pts[i];
        final p1 = pts[i + 1];
        final midX = (p0.dx + p1.dx) / 2;
        path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      }
      return path;
    }

    final salesPts = buildPoints(sales);
    final profitPts = buildPoints(profits);

    final salesPath = buildSmoothPath(salesPts);
    final areaPath = Path.from(salesPath)
      ..lineTo(size.width, topPad + chartH)
      ..lineTo(0, topPad + chartH)
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withAlpha(85),
          primaryColor.withAlpha(5),
        ],
      ).createShader(Rect.fromLTWH(0, topPad, size.width, chartH));

    canvas.drawPath(areaPath, areaPaint);

    canvas.drawPath(
      salesPath,
      Paint()
        ..color = primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6,
    );

    canvas.drawPath(
      buildSmoothPath(profitPts),
      Paint()
        ..color = profitColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Crosshair vertikal jam terpilih
    final selPt = salesPts[selectedHour.clamp(0, 23)];
    canvas.drawLine(
      Offset(selPt.dx, topPad),
      Offset(selPt.dx, topPad + chartH),
      Paint()
        ..color = primaryColor.withAlpha(140)
        ..strokeWidth = 1.4,
    );
    canvas.drawCircle(selPt, 5, Paint()..color = Colors.white);
    canvas.drawCircle(selPt, 3.5, Paint()..color = primaryColor);

    // Label Jam Bawah (00, 06, 12, 18, 23)
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final h in [0, 6, 12, 18, 23]) {
      tp.text = TextSpan(
        text: '${h.toString().padLeft(2, '0')}:00',
        style: TextStyle(fontSize: 9.5, color: textColor, fontWeight: FontWeight.w700),
      );
      tp.layout();
      final dx = ((size.width / 23) * h - tp.width / 2)
          .clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(dx, topPad + chartH + 5));
    }
  }

  @override
  bool shouldRepaint(covariant _HourlyBezierChartPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.selectedHour != selectedHour ||
      oldDelegate.sales != sales;
}

class _DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final double progress;

  const _DonutChartPainter({
    required this.values,
    required this.colors,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 8;
    double startAngle = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * 2 * math.pi * progress;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.values != values;
}
