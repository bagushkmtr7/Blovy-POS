import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../widgets/pos_components.dart';

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
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  int _subTab = 0; // 0: Promo & Voucher, 1: Member & Loyalty, 2: Buku Kasbon
  final TextEditingController _cariCtrl = TextEditingController();

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
    _cariCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tema;
    final promoAktif = widget.daftarPromo.where((p) => p.aktif).length;
    final totalPoin = widget.daftarMember.fold<int>(0, (s, m) => s + m.poin);
    final kasbonList = widget.daftarTransaksi
        .where((trx) => !trx.statusLunas && trx.sisaPiutang > 0)
        .toList();
    final totalPiutang = kasbonList.fold<int>(0, (s, trx) => s + trx.sisaPiutang);
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
                            color: t.accentColor,
                            boxShadow: [
                              BoxShadow(
                                color: t.accentColor.withAlpha(((1 - v) * 140).round()),
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
                        'PROMO, LOYALTY & RECEIVABLES HUB',
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
                      child: _CrmKpiBox(
                        tema: t,
                        label: 'PROMO AKTIF',
                        value: '$promoAktif/${widget.daftarPromo.length}',
                        color: t.successColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CrmKpiBox(
                        tema: t,
                        label: 'MEMBER & POIN',
                        value: '${widget.daftarMember.length} • $totalPoin pt',
                        color: t.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CrmKpiBox(
                        tema: t,
                        label: 'PIUTANG KASBON',
                        value: formatRupiah(totalPiutang),
                        color: totalPiutang > 0 ? t.warningColor : t.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Voucher & Promo')),
              ButtonSegment(value: 1, label: Text('Member CRM')),
              ButtonSegment(value: 2, label: Text('Buku Kasbon')),
            ],
            selected: {_subTab},
            onSelectionChanged: (v) => setState(() {
              _subTab = v.first;
              _cariCtrl.clear();
            }),
          ),
        ),
        Expanded(
          child: _subTab == 0
              ? _buildPromoList(t)
              : (_subTab == 1 ? _buildMemberList(t) : _buildKasbonList(t, kasbonList)),
        ),
      ],
    );
  }

  Widget _buildPromoList(AppThemeConfig t) {
    final q = _cariCtrl.text.trim().toLowerCase();
    final list = widget.daftarPromo.where((p) {
      if (q.isEmpty) return true;
      return p.kode.toLowerCase().contains(q) || p.nama.toLowerCase().contains(q);
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
                    hintText: 'Cari kode voucher atau nama promo...',
                    prefixIcon: const Icon(Icons.local_offer_outlined, size: 18),
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
                onPressed: () => widget.onBukaFormPromo(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Promo', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text('Belum ada promo / voucher.', style: TextStyle(color: t.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (ctx, i) {
                    final prm = list[i];
                    final diskonLabel = prm.isPersen
                        ? 'Diskon ${prm.nilai}%'
                        : 'Potongan ${formatRupiah(prm.nilai)}';
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: dekorasiKartu(t),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (prm.aktif ? t.successColor : t.textSecondary).withAlpha(22),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              Icons.confirmation_number_rounded,
                              color: prm.aktif ? t.successColor : t.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    StatusBadge(
                                      label: prm.kode.toUpperCase(),
                                      color: t.primaryColor,
                                    ),
                                    const SizedBox(width: 6),
                                    StatusBadge(
                                      label: prm.aktif ? 'AKTIF' : 'NONAKTIF',
                                      color: prm.aktif ? t.successColor : t.textSecondary,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  prm.nama,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  '$diskonLabel • Min. belanja ${formatRupiah(prm.minBelanja)}',
                                  style: TextStyle(fontSize: 11, color: t.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: prm.aktif,
                            onChanged: (val) => widget.onSimpanPromo(prm.copyWith(aktif: val), false),
                          ),
                          IconButton(
                            onPressed: () => widget.onBukaFormPromo(editPromo: prm),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                          ),
                          IconButton(
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

  Widget _buildMemberList(AppThemeConfig t) {
    final q = _cariCtrl.text.trim().toLowerCase();
    final list = widget.daftarMember.where((m) {
      if (q.isEmpty) return true;
      return m.nama.toLowerCase().contains(q) || m.telepon.toLowerCase().contains(q);
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
                    hintText: 'Cari nama atau nomor HP member...',
                    prefixIcon: const Icon(Icons.person_search_rounded, size: 18),
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
                onPressed: () => widget.onBukaFormMember(),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Member', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text('Belum ada data member.', style: TextStyle(color: t.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (ctx, i) {
                    final m = list[i];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: dekorasiKartu(t),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: t.primaryColor.withAlpha(24),
                            child: Text(
                              m.nama.isNotEmpty ? m.nama[0].toUpperCase() : 'M',
                              style: TextStyle(fontWeight: FontWeight.w900, color: t.primaryColor),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.nama,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  '${m.telepon.isEmpty ? "-" : m.telepon} • ${m.jumlahKunjungan} kunjungan',
                                  style: TextStyle(fontSize: 11, color: t.textSecondary),
                                ),
                                Text(
                                  'Akumulasi Belanja: ${formatRupiah(m.totalBelanja)}',
                                  style: gayaAngka(
                                    TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: t.primaryColor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(label: '${m.poin} Poin', color: t.successColor),
                          IconButton(
                            onPressed: () => widget.onBukaFormMember(editMember: m),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                          ),
                          IconButton(
                            onPressed: () => widget.onHapusMember(m.id),
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

  Widget _buildKasbonList(AppThemeConfig t, List<TransaksiPos> kasbonList) {
    if (kasbonList.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada piutang kasbon aktif. Seluruh transaksi lunas!',
          style: TextStyle(color: t.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      itemCount: kasbonList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (ctx, i) {
        final trx = kasbonList[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: dekorasiKartu(t, borderOverride: t.warningColor.withAlpha(120)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${trx.namaPelanggan} • ${trx.nomorStruk}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${formatTanggalWaktu(trx.tanggal)} • Total ${formatRupiah(trx.totalBelanja)}',
                      style: TextStyle(fontSize: 11, color: t.textSecondary),
                    ),
                    Text(
                      'Sisa Piutang: ${formatRupiah(trx.sisaPiutang)}',
                      style: gayaAngka(
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: t.dangerColor),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: t.successColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => widget.onBayarKasbon(trx),
                child: const Text('Bayar Kasbon', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CrmKpiBox extends StatelessWidget {
  final AppThemeConfig tema;
  final String label;
  final String value;
  final Color color;

  const _CrmKpiBox({
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
