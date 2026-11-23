import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/clerek_model.dart';
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
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _barCtrl;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  int _subTab = 0;
  final TextEditingController _cariStrukCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _barCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _barCtrl.dispose();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Profil Toko & Pajak', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: namaCtrl, decoration: const InputDecoration(labelText: 'Nama Toko')),
              const SizedBox(height: 8),
              TextField(controller: alamatCtrl, decoration: const InputDecoration(labelText: 'Alamat')),
              const SizedBox(height: 8),
              TextField(controller: telpCtrl, decoration: const InputDecoration(labelText: 'Telepon')),
              const SizedBox(height: 8),
              TextField(controller: pajakCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PPN (%)')),
              const SizedBox(height: 8),
              TextField(controller: catatanCtrl, decoration: const InputDecoration(labelText: 'Footer Struk')),
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
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w800)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Backup & Restore JSON', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        content: TextField(
          controller: jsonCtrl,
          maxLines: 7,
          style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace'),
          decoration: InputDecoration(filled: true, fillColor: t.inputColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: t.primaryColor, foregroundColor: Colors.white),
            onPressed: () {
              widget.onRestoreJson(jsonCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tema;
    final pendingClerek = widget.daftarShift.where((s) => !s.aktif && widget.mapClerekZReport[s.id] == null).length;
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
                colors: [t.primaryColor.withAlpha(32), t.surfaceColor, t.successColor.withAlpha(24)],
              ),
              border: Border.all(color: t.primaryColor.withAlpha(75)),
            ),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _barCtrl,
                  builder: (_, __) => ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    child: LinearProgressIndicator(
                      value: _barCtrl.value,
                      minHeight: 3,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation(t.successColor),
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
                              'AUDIT & SYSTEM CONTROL',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 0.7, color: t.primaryColor),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: t.inputColor, borderRadius: BorderRadius.circular(20)),
                            child: Text(jamStr, style: gayaAngka(const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _AuditTile(tema: t, title: 'STRUK', value: '${widget.daftarTransaksi.length}', accent: t.primaryColor)),
                          const SizedBox(width: 7),
                          Expanded(child: _AuditTile(tema: t, title: 'CLEREK', value: '$pendingClerek Pending', accent: pendingClerek > 0 ? t.warningColor : t.successColor)),
                          const SizedBox(width: 7),
                          Expanded(child: _AuditTile(tema: t, title: 'SDM', value: '${widget.daftarStaff.where((s) => s.aktif).length} Aktif', accent: t.accentColor)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final item in const [
                (0, 'Audit Struk'),
                (1, 'Clerek Shift'),
                (2, 'SDM & PIN'),
                (3, 'Sistem'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _AuditPill(
                    label: item.$2,
                    selected: _subTab == item.$1,
                    color: t.primaryColor,
                    onTap: () => setState(() => _subTab = item.$1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: _subTab == 0
                ? _buildStruk(t)
                : (_subTab == 1 ? _buildShift(t) : (_subTab == 2 ? _buildSdm(t) : _buildSistem(t))),
          ),
        ),
      ],
    );
  }

  Widget _buildStruk(AppThemeConfig t) {
    final q = _cariStrukCtrl.text.trim().toLowerCase();
    final sorted = [...widget.daftarTransaksi]..sort((a, b) => b.tanggal.compareTo(a.tanggal));
    final list = sorted.where((trx) {
      if (q.isEmpty) return true;
      return trx.nomorStruk.toLowerCase().contains(q) ||
          trx.namaKasir.toLowerCase().contains(q) ||
          trx.namaPelanggan.toLowerCase().contains(q);
    }).toList();

    return Column(
      key: const ValueKey('aud_struk'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: TextField(
            controller: _cariStrukCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Cari no. struk, kasir, pelanggan...',
              prefixIcon: const Icon(Icons.manage_search_rounded, size: 18),
              isDense: true,
              filled: true,
              fillColor: t.surfaceColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final trx = list[i];
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
                          Row(
                            children: [
                              Text(trx.nomorStruk, style: gayaAngka(const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900))),
                              const SizedBox(width: 6),
                              StatusBadge(label: trx.statusLunas ? trx.metodeBayar : 'KASBON', color: trx.statusLunas ? t.successColor : t.warningColor),
                            ],
                          ),
                          Text('${formatTanggalWaktu(trx.tanggal)} • ${trx.namaKasir}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: t.textSecondary)),
                          Text(formatRupiah(trx.totalBelanja), style: gayaAngka(TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: t.primaryColor))),
                        ],
                      ),
                    ),
                    IconButton(visualDensity: VisualDensity.compact, onPressed: () => widget.onLihatStruk(trx), icon: const Icon(Icons.receipt_long_rounded)),
                    IconButton(visualDensity: VisualDensity.compact, onPressed: () => widget.onVoidTransaksi(trx), icon: Icon(Icons.block_rounded, color: t.dangerColor)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShift(AppThemeConfig t) {
    final shifts = [...widget.daftarShift]..sort((a, b) => b.waktuBuka.compareTo(a.waktuBuka));
    return ListView.separated(
      key: const ValueKey('aud_shift'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: shifts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (ctx, i) {
        final sh = shifts[i];
        final z = widget.mapClerekZReport[sh.id];
        final selisih = sh.kasAktualTutup - (sh.modalAwal + sh.penjualanTunai - sh.pengeluaranKas);
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
                  Expanded(child: Text(sh.namaStaff, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900))),
                  StatusBadge(
                    label: sh.aktif ? 'AKTIF' : (z != null ? 'LOCKED' : 'PENDING'),
                    color: sh.aktif ? t.successColor : (z != null ? t.primaryColor : t.warningColor),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Buka: ${formatTanggalWaktu(sh.waktuBuka)} • Modal ${_ringkasRp(sh.modalAwal)}', style: TextStyle(fontSize: 11, color: t.textSecondary)),
              Text('Tunai ${_ringkasRp(sh.penjualanTunai)} • Non-Tunai ${_ringkasRp(sh.penjualanNonTunai)} • Selisih ${_ringkasRp(selisih)}', style: gayaAngka(const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (!sh.aktif && z == null)
                    _AuditPill(
                      label: 'Input Clerek',
                      selected: true,
                      color: t.primaryColor,
                      onTap: () => widget.onBukaClerekBlind(
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
                    ),
                  if (z != null) ...[
                    _AuditPill(label: 'Z-Report', selected: false, color: t.primaryColor, onTap: () => widget.onLihatZReport(z)),
                    _AuditPill(label: 'PDF', selected: false, color: t.accentColor, onTap: () => widget.onUnduhPdfClerek(z)),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSdm(AppThemeConfig t) {
    return Column(
      key: const ValueKey('aud_sdm'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(
            children: [
              const Expanded(child: Text('Akun & PIN SDM', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900))),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: t.primaryColor, foregroundColor: Colors.white),
                onPressed: () => widget.onBukaFormStaff(),
                icon: const Icon(Icons.person_add_rounded, size: 17),
                label: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            itemCount: widget.daftarStaff.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final st = widget.daftarStaff[i];
              return Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: t.surfaceColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.borderColor)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${st.nama} (${st.id})', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
                          Text('${st.isStoreSystem ? "Store System" : "Kasir"} • PIN ${st.pin}', style: TextStyle(fontSize: 11, color: t.textSecondary)),
                        ],
                      ),
                    ),
                    StatusBadge(label: st.aktif ? 'AKTIF' : 'OFF', color: st.aktif ? t.successColor : t.dangerColor),
                    IconButton(visualDensity: VisualDensity.compact, onPressed: () => widget.onBukaFormStaff(editStaff: st), icon: const Icon(Icons.edit_outlined, size: 18)),
                    if (st.id != widget.currentStaff.id)
                      IconButton(visualDensity: VisualDensity.compact, onPressed: () => widget.onHapusStaff(st.id), icon: Icon(Icons.delete_outline_rounded, size: 18, color: t.dangerColor)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSistem(AppThemeConfig t) {
    return ListView(
      key: const ValueKey('aud_sys'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: t.surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.toko.namaToko, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(widget.toko.alamatToko, style: TextStyle(fontSize: 11.5, color: t.textSecondary)),
              Text('Pajak PPN: ${widget.toko.persenPajak}%', style: TextStyle(fontSize: 11.5, color: t.textSecondary)),
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: t.primaryColor, foregroundColor: Colors.white),
                onPressed: _dialogEditToko,
                icon: const Icon(Icons.storefront_rounded, size: 17),
                label: const Text('Edit Profil Toko', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: t.surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Backup & Restore Data', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _dialogBackupRestore,
                icon: const Icon(Icons.data_object_rounded, size: 17),
                label: const Text('Export / Restore JSON', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuditPill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _AuditPill({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: selected ? Colors.white : t.colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  final AppThemeConfig tema;
  final String title;
  final String value;
  final Color accent;

  const _AuditTile({required this.tema, required this.title, required this.value, required this.accent});

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
          Text(title, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: tema.textSecondary)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: gayaAngka(TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: accent))),
        ],
      ),
    );
  }
}
