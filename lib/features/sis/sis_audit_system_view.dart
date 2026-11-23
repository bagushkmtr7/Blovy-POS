import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/clerek_model.dart';
import '../../models/pos_models.dart';
import '../../widgets/pos_components.dart';

class SisAuditSystemView extends StatefulWidget {
  final AppThemeConfig tema;
  final PengaturanToko toko;
  final AkunStaff currentStaff;
  final List<AkunStaff> daftarStaff;
  final List<ShiftKasir> daftarShift;
  final List<TransaksiPos> daftarTransaksi;
  final Map<String, LaporanClerekShift> mapClerekZReport;
  final void Function(TransaksiPos trx) onLihatStruk;
  final void Function(TransaksiPos trx) onVoidTransaksi;
  final void Function(ShiftKasir shift, LaporanClerekShift draftOrZ) onBukaClerekBlind;
  final void Function(LaporanClerekShift z) onLihatZReport;
  final void Function(LaporanClerekShift z) onUnduhPdfClerek;
  final void Function({AkunStaff? editStaff}) onBukaFormStaff;
  final void Function(String id) onHapusStaff;
  final void Function(PengaturanToko toko) onSimpanToko;
  final void Function(String temaId) onGantiTema;
  final void Function(String jsonStr) onRestoreJson;
  final String Function() onExportJson;

  const SisAuditSystemView({
    super.key,
    required this.tema,
    required this.toko,
    required this.currentStaff,
    required this.daftarStaff,
    required this.daftarShift,
    required this.daftarTransaksi,
    required this.mapClerekZReport,
    required this.onLihatStruk,
    required this.onVoidTransaksi,
    required this.onBukaClerekBlind,
    required this.onLihatZReport,
    required this.onUnduhPdfClerek,
    required this.onBukaFormStaff,
    required this.onHapusStaff,
    required this.onSimpanToko,
    required this.onGantiTema,
    required this.onRestoreJson,
    required this.onExportJson,
  });

  @override
  State<SisAuditSystemView> createState() => _SisAuditSystemViewState();
}

class _SisAuditSystemViewState extends State<SisAuditSystemView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  int _subTab = 0; // 0: Audit Struk, 1: Shift & Clerek, 2: SDM & PIN, 3: Sistem
  final TextEditingController _cariStrukCtrl = TextEditingController();

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
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _clockTimer?.cancel();
    _cariStrukCtrl.dispose();
    super.dispose();
  }

  void _dialogEditToko() {
    final t = widget.tema;
    final namaCtrl = TextEditingController(text: widget.toko.namaToko);
    final alamatCtrl = TextEditingController(text: widget.toko.alamatToko);
    final telpCtrl = TextEditingController(text: widget.toko.teleponToko);
    final pajakCtrl = TextEditingController(text: widget.toko.persenPajak.toString());
    final catatanCtrl = TextEditingController(text: widget.toko.catatanStruk);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Pengaturan Profil Toko', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: namaCtrl,
                decoration: InputDecoration(
                  labelText: 'Nama Toko / Outlet',
                  filled: true,
                  fillColor: t.inputColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: alamatCtrl,
                decoration: InputDecoration(
                  labelText: 'Alamat Toko',
                  filled: true,
                  fillColor: t.inputColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: telpCtrl,
                decoration: InputDecoration(
                  labelText: 'Telepon / WhatsApp',
                  filled: true,
                  fillColor: t.inputColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pajakCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Pajak / PPN (%)',
                  filled: true,
                  fillColor: t.inputColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: catatanCtrl,
                decoration: InputDecoration(
                  labelText: 'Catatan Footer Struk',
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
            style: FilledButton.styleFrom(backgroundColor: t.primaryColor, foregroundColor: Colors.white),
            onPressed: () {
              final pjk = int.tryParse(pajakCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              widget.onSimpanToko(
                widget.toko.copyWith(
                  namaToko: namaCtrl.text.trim().isEmpty ? widget.toko.namaToko : namaCtrl.text.trim(),
                  alamatToko: alamatCtrl.text.trim(),
                  teleponToko: telpCtrl.text.trim(),
                  persenPajak: pjk.clamp(0, 100),
                  catatanStruk: catatanCtrl.text.trim(),
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Simpan Profil', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _dialogBackupRestore() {
    final t = widget.tema;
    final jsonCtrl = TextEditingController(text: widget.onExportJson());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Backup & Restore JSON Database', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Salin JSON di bawah untuk backup atau tempel JSON backup lalu tekan Restore.',
                style: TextStyle(fontSize: 11, color: t.textSecondary),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: jsonCtrl,
                maxLines: 7,
                style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: t.inputColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          OutlinedButton(
            onPressed: () {
              widget.onRestoreJson(jsonCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Restore Data'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tema;
    final pendingClerek = widget.daftarShift
        .where((s) => !s.aktif && widget.mapClerekZReport[s.id] == null)
        .length;
    final jamStr =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}';

    return Column(
      children: [
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
                            color: t.successColor,
                            boxShadow: [
                              BoxShadow(
                                color: t.successColor.withAlpha(((1 - v) * 140).round()),
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
                        'AUDIT TRAIL, CLEREK & SYSTEM CONTROL',
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
                      child: _AuditKpiChip(
                        tema: t,
                        label: 'TOTAL STRUK',
                        value: '${widget.daftarTransaksi.length}',
                        color: t.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _AuditKpiChip(
                        tema: t,
                        label: 'CLEREK PENDING',
                        value: '$pendingClerek Shift',
                        color: pendingClerek > 0 ? t.warningColor : t.successColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _AuditKpiChip(
                        tema: t,
                        label: 'SDM AKTIF',
                        value: '${widget.daftarStaff.where((s) => s.aktif).length} Akun',
                        color: t.accentColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              for (final entry in const [
                (0, 'Audit Struk'),
                (1, 'Shift & Clerek'),
                (2, 'SDM & PIN'),
                (3, 'Sistem & Backup'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(entry.$2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    selected: _subTab == entry.$1,
                    onSelected: (_) => setState(() => _subTab = entry.$1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _subTab == 0
              ? _buildAuditStruk(t)
              : (_subTab == 1
                  ? _buildAuditShift(t)
                  : (_subTab == 2 ? _buildSdmTab(t) : _buildSistemTab(t))),
        ),
      ],
    );
  }

  Widget _buildAuditStruk(AppThemeConfig t) {
    final q = _cariStrukCtrl.text.trim().toLowerCase();
    final sorted = [...widget.daftarTransaksi]
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
    final list = sorted.where((trx) {
      if (q.isEmpty) return true;
      return trx.nomorStruk.toLowerCase().contains(q) ||
          trx.namaKasir.toLowerCase().contains(q) ||
          trx.namaPelanggan.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: TextField(
            controller: _cariStrukCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Cari nomor struk, kasir, atau pelanggan...',
              prefixIcon: const Icon(Icons.manage_search_rounded, size: 19),
              isDense: true,
              filled: true,
              fillColor: t.surfaceColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text('Belum ada transaksi untuk diaudit.', style: TextStyle(color: t.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final trx = list[i];
                    return Container(
                      padding: const EdgeInsets.all(11),
                      decoration: dekorasiKartu(t),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      trx.nomorStruk,
                                      style: gayaAngka(
                                        const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    StatusBadge(
                                      label: trx.statusLunas ? trx.metodeBayar : 'KASBON',
                                      color: trx.statusLunas ? t.successColor : t.warningColor,
                                    ),
                                  ],
                                ),
                                Text(
                                  '${formatTanggalWaktu(trx.tanggal)} • ${trx.namaKasir}',
                                  style: TextStyle(fontSize: 10.5, color: t.textSecondary),
                                ),
                                Text(
                                  formatRupiah(trx.totalBelanja),
                                  style: gayaAngka(
                                    TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: t.primaryColor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Lihat Struk',
                            onPressed: () => widget.onLihatStruk(trx),
                            icon: const Icon(Icons.receipt_long_rounded),
                          ),
                          IconButton(
                            tooltip: 'Void Transaksi',
                            onPressed: () => widget.onVoidTransaksi(trx),
                            icon: Icon(Icons.block_rounded, color: t.dangerColor),
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

  Widget _buildAuditShift(AppThemeConfig t) {
    final shifts = [...widget.daftarShift]
      ..sort((a, b) => b.waktuBuka.compareTo(a.waktuBuka));
    if (shifts.isEmpty) {
      return Center(child: Text('Belum ada data shift kasir.', style: TextStyle(color: t.textSecondary)));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      itemCount: shifts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (ctx, i) {
        final sh = shifts[i];
        final zReport = widget.mapClerekZReport[sh.id];
        final selisih = sh.kasAktualTutup -
            (sh.modalAwal + sh.penjualanTunai - sh.pengeluaranKas);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: dekorasiKartu(t),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sh.namaStaff,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                  ),
                  StatusBadge(
                    label: sh.aktif
                        ? 'SHIFT AKTIF'
                        : (zReport != null ? 'Z-REPORT LOCKED' : 'PERLU CLEREK'),
                    color: sh.aktif
                        ? t.successColor
                        : (zReport != null ? t.primaryColor : t.warningColor),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Buka: ${formatTanggalWaktu(sh.waktuBuka)} • Modal: ${formatRupiah(sh.modalAwal)}',
                style: TextStyle(fontSize: 11, color: t.textSecondary),
              ),
              Text(
                'Tunai: ${formatRupiah(sh.penjualanTunai)} • Non-Tunai: ${formatRupiah(sh.penjualanNonTunai)} • Selisih: ${formatRupiah(selisih)}',
                style: gayaAngka(const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (!sh.aktif && zReport == null)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: t.primaryColor,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => widget.onBukaClerekBlind(
                        sh,
                        LaporanClerekShift(
                          shiftId: sh.id,
                          nomorClerek: 'CLK-${sh.id.substring(sh.id.length > 6 ? sh.id.length - 6 : 0).toUpperCase()}',
                          namaKasir: sh.namaStaff,
                          namaOtorisasiTutup: widget.currentStaff.nama,
                          waktuBuka: sh.waktuBuka,
                          waktuClerek: DateTime.now(),
                          modalAwalSistem: sh.modalAwal,
                          penjualanTunaiSistem: sh.penjualanTunai,
                          penjualanNonTunaiSistem: sh.penjualanNonTunai,
                          pengeluaranLaciSistem: sh.pengeluaranKas,
                          kasbonBaruSistem: 0,
                          jumlahStrukSukses: 0,
                          totalItemTerjual: 0,
                        ),
                      ),
                      icon: const Icon(Icons.fact_check_rounded, size: 15),
                      label: const Text('Input Clerek', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  if (zReport != null) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => widget.onLihatZReport(zReport),
                      icon: const Icon(Icons.visibility_rounded, size: 15),
                      label: const Text('Z-Report', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => widget.onUnduhPdfClerek(zReport),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                      label: const Text('PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSdmTab(AppThemeConfig t) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Daftar Akun SDM & PIN Akses',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: t.primaryColor,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => widget.onBukaFormStaff(),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Tambah SDM', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
            itemCount: widget.daftarStaff.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final st = widget.daftarStaff[i];
              return Container(
                padding: const EdgeInsets.all(11),
                decoration: dekorasiKartu(t),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${st.nama} (NIK ${st.id})',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Role: ${st.isStoreSystem ? "Store System / Manager" : "Kasir POS"} • PIN: ${st.pin}',
                            style: TextStyle(fontSize: 11, color: t.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(
                      label: st.aktif ? 'AKTIF' : 'NONAKTIF',
                      color: st.aktif ? t.successColor : t.dangerColor,
                    ),
                    IconButton(
                      onPressed: () => widget.onBukaFormStaff(editStaff: st),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                    if (st.id != widget.currentStaff.id)
                      IconButton(
                        onPressed: () => widget.onHapusStaff(st.id),
                        icon: Icon(Icons.delete_outline_rounded, size: 18, color: t.dangerColor),
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

  Widget _buildSistemTab(AppThemeConfig t) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: dekorasiKartu(t),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Identitas Toko & Pajak', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(widget.toko.namaToko, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              Text(widget.toko.alamatToko, style: TextStyle(fontSize: 11, color: t.textSecondary)),
              Text('Pajak PPN: ${widget.toko.persenPajak}%', style: TextStyle(fontSize: 11, color: t.textSecondary)),
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: t.primaryColor, foregroundColor: Colors.white),
                onPressed: _dialogEditToko,
                icon: const Icon(Icons.edit_location_alt_rounded, size: 17),
                label: const Text('Ubah Profil & Pajak Toko', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: dekorasiKartu(t),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Tema Visual Aplikasi', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tm in [widget.tema])
                    ChoiceChip(
                      label: Text(tm.nama, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                      selected: tm.id == t.id,
                      onSelected: (_) => widget.onGantiTema(tm.id),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: dekorasiKartu(t),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Backup, Restore & Sesi', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _dialogBackupRestore,
                icon: const Icon(Icons.backup_rounded, size: 17),
                label: const Text('Backup / Restore JSON', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuditKpiChip extends StatelessWidget {
  final AppThemeConfig tema;
  final String label;
  final String value;
  final Color color;

  const _AuditKpiChip({
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
