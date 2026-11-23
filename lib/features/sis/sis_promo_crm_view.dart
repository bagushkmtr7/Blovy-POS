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

class SisPromoCrmView extends StatefulWidget {
  final AppThemeConfig tema;
  final List<PromoVoucher> daftarPromo;
  final List<MemberPelanggan> daftarMember;
  final List<TransaksiPos> daftarTransaksi;
  final void Function({PromoVoucher? editPromo}) onBukaFormPromo;
  final void Function(PromoVoucher promo, bool isBaru) onSimpanPromo;
  final void Function(String id) onHapusPromo;
  final void Function({MemberPelanggan? editMember}) onBukaFormMember;
  final void Function(String id) onHapusMember;
  final void Function(TransaksiPos trx) onBayarKasbon;

  const SisPromoCrmView({
    super.key,
    required this.tema,
    required this.daftarPromo,
    required this.daftarMember,
    required this.daftarTransaksi,
    required this.onBukaFormPromo,
    required this.onSimpanPromo,
    required this.onHapusPromo,
    required this.onBukaFormMember,
    required this.onHapusMember,
    required this.onBayarKasbon,
  });

  @override
  State<SisPromoCrmView> createState() => _SisPromoCrmViewState();
}

class _SisPromoCrmViewState extends State<SisPromoCrmView>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _barCtrl;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  int _subTab = 0;
  final TextEditingController _cariCtrl = TextEditingController();

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
    _cariCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tema;
    final aktif = widget.daftarPromo.where((p) => p.aktif).length;
    final poin = widget.daftarMember.fold<int>(0, (s, m) => s + m.poin);
    final kasbon = widget.daftarTransaksi.where((trx) => !trx.statusLunas && trx.sisaPiutang > 0).toList();
    final piutang = kasbon.fold<int>(0, (s, trx) => s + trx.sisaPiutang);
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
                colors: [t.accentColor.withAlpha(32), t.surfaceColor, t.primaryColor.withAlpha(24)],
              ),
              border: Border.all(color: t.accentColor.withAlpha(75)),
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
                      valueColor: AlwaysStoppedAnimation(t.accentColor),
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
                                  color: t.accentColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: t.accentColor.withAlpha(((1 - v) * 180).round()),
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
                              'PROMO & CRM LIVE',
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
                          Expanded(child: _CrmTile(tema: t, title: 'PROMO AKTIF', value: '$aktif/${widget.daftarPromo.length}', accent: t.successColor)),
                          const SizedBox(width: 7),
                          Expanded(child: _CrmTile(tema: t, title: 'MEMBER / POIN', value: '${widget.daftarMember.length} • ${poin}pt', accent: t.primaryColor)),
                          const SizedBox(width: 7),
                          Expanded(child: _CrmTile(tema: t, title: 'KASBON', value: _ringkasRp(piutang), accent: piutang > 0 ? t.warningColor : t.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              for (final item in const [(0, 'Promo'), (1, 'Member'), (2, 'Kasbon')]) ...[
                if (item.$1 > 0) const SizedBox(width: 7),
                Expanded(
                  child: _CrmPill(
                    label: item.$2,
                    selected: _subTab == item.$1,
                    color: t.primaryColor,
                    onTap: () => setState(() {
                      _subTab = item.$1;
                      _cariCtrl.clear();
                    }),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: _subTab == 0
                ? _buildPromo(t)
                : (_subTab == 1 ? _buildMember(t) : _buildKasbon(t, kasbon)),
          ),
        ),
      ],
    );
  }

  Widget _buildPromo(AppThemeConfig t) {
    final q = _cariCtrl.text.trim().toLowerCase();
    final list = widget.daftarPromo.where((p) => q.isEmpty || p.kode.toLowerCase().contains(q) || p.nama.toLowerCase().contains(q)).toList();
    return Column(
      key: const ValueKey('crm_promo'),
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
                    hintText: 'Cari kode atau promo...',
                    prefixIcon: const Icon(Icons.local_offer_outlined, size: 18),
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
                onPressed: () => widget.onBukaFormPromo(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Promo', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text('Belum ada promo.', style: TextStyle(color: t.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (ctx, i) {
                    final prm = list[i];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.surfaceColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: prm.aktif ? t.successColor.withAlpha(110) : t.borderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    StatusBadge(label: prm.kode.toUpperCase(), color: t.primaryColor),
                                    const SizedBox(width: 6),
                                    StatusBadge(label: prm.aktif ? 'AKTIF' : 'OFF', color: prm.aktif ? t.successColor : t.textSecondary),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(prm.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                                Text(
                                  '${prm.isPersen ? "Diskon ${prm.nilai}%" : "Potongan ${formatRupiah(prm.nilai)}"} • Min ${formatRupiah(prm.minBelanja)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: t.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: prm.aktif,
                            onChanged: (v) => widget.onSimpanPromo(prm.copyWith(aktif: v), false),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => widget.onBukaFormPromo(editPromo: prm),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => widget.onHapusPromo(prm.id),
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

  Widget _buildMember(AppThemeConfig t) {
    final q = _cariCtrl.text.trim().toLowerCase();
    final list = widget.daftarMember.where((m) => q.isEmpty || m.nama.toLowerCase().contains(q) || m.telepon.toLowerCase().contains(q)).toList();
    return Column(
      key: const ValueKey('crm_member'),
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
                    hintText: 'Cari nama atau HP member...',
                    prefixIcon: const Icon(Icons.person_search_rounded, size: 18),
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
                onPressed: () => widget.onBukaFormMember(),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Member', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text('Belum ada member.', style: TextStyle(color: t.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (ctx, i) {
                    final m = list[i];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.surfaceColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: t.borderColor),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: t.primaryColor.withAlpha(24),
                            child: Text(m.nama.isNotEmpty ? m.nama[0].toUpperCase() : 'M', style: TextStyle(fontWeight: FontWeight.w900, color: t.primaryColor)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                                Text('${m.telepon.isEmpty ? "-" : m.telepon} • ${m.jumlahKunjungan}x', style: TextStyle(fontSize: 11, color: t.textSecondary)),
                                Text('Belanja ${formatRupiah(m.totalBelanja)}', style: gayaAngka(TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: t.primaryColor))),
                              ],
                            ),
                          ),
                          StatusBadge(label: '${m.poin} pt', color: t.successColor),
                          IconButton(visualDensity: VisualDensity.compact, onPressed: () => widget.onBukaFormMember(editMember: m), icon: const Icon(Icons.edit_outlined, size: 18)),
                          IconButton(visualDensity: VisualDensity.compact, onPressed: () => widget.onHapusMember(m.id), icon: Icon(Icons.delete_outline_rounded, size: 18, color: t.dangerColor)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildKasbon(AppThemeConfig t, List<TransaksiPos> kasbonList) {
    if (kasbonList.isEmpty) {
      return Center(
        key: const ValueKey('crm_kasbon_empty'),
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: t.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.borderColor),
          ),
          child: Text('Tidak ada piutang kasbon aktif. Semua lunas!', style: TextStyle(color: t.textSecondary)),
        ),
      );
    }
    return ListView.separated(
      key: const ValueKey('crm_kasbon'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: kasbonList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (ctx, i) {
        final trx = kasbonList[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.surfaceColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: t.warningColor.withAlpha(130)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${trx.namaPelanggan} • ${trx.nomorStruk}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                    Text('Sisa ${formatRupiah(trx.sisaPiutang)}', style: gayaAngka(TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: t.dangerColor))),
                  ],
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: t.successColor, foregroundColor: Colors.white),
                onPressed: () => widget.onBayarKasbon(trx),
                child: const Text('Lunasi', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CrmPill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _CrmPill({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
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
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: selected ? Colors.white : t.colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class _CrmTile extends StatelessWidget {
  final AppThemeConfig tema;
  final String title;
  final String value;
  final Color accent;

  const _CrmTile({required this.tema, required this.title, required this.value, required this.accent});

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
