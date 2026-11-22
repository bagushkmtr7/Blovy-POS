import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../widgets/pos_components.dart';
import '../../widgets/struk_sheet.dart';

class PelangganTab extends StatefulWidget {
  final AppThemeConfig tema;
  final PengaturanToko toko;
  final AkunStaff currentStaff;
  final List<AkunStaff> daftarStaff;
  final List<TransaksiPos> daftarTransaksi;
  final List<MemberPelanggan> daftarMember;
  final void Function(TransaksiPos trx, int nominalBayar) onBayarKasbon;
  final void Function(MemberPelanggan member, bool isBaru) onSimpanMember;
  final void Function(String memberId) onHapusMember;

  const PelangganTab({
    super.key,
    required this.tema,
    required this.toko,
    required this.currentStaff,
    required this.daftarStaff,
    required this.daftarTransaksi,
    required this.daftarMember,
    required this.onBayarKasbon,
    required this.onSimpanMember,
    required this.onHapusMember,
  });

  @override
  State<PelangganTab> createState() => _PelangganTabState();
}

class _PelangganTabState extends State<PelangganTab> {
  int _subTab = 0; // 0: Kasbon, 1: Member & Poin

  void _dialogCicilKasbon(TransaksiPos trx) {
    final t = widget.tema;
    final bayarCtrl = TextEditingController(text: trx.sisaPiutang.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surfaceColor,
        title: Text(
          'Pelunasan Kasbon: ${trx.namaPelanggan}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'No Struk: ${trx.nomorStruk}\nSisa Hutang: ${formatRupiah(trx.sisaPiutang)}',
              style: gayaAngka(TextStyle(fontSize: 12, color: t.textSecondary)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bayarCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nominal Pembayaran',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: t.successColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final nom =
                  int.tryParse(bayarCtrl.text.replaceAll('.', '')) ?? 0;
              if (nom > 0) {
                Navigator.pop(ctx);
                widget.onBayarKasbon(trx, nom);
              }
            },
            child: const Text('Terima Pembayaran'),
          ),
        ],
      ),
    );
  }

  void _dialogFormMember({MemberPelanggan? editMember}) {
    final t = widget.tema;
    final isBaru = editMember == null;
    final namaCtrl = TextEditingController(text: editMember?.nama ?? '');
    final telpCtrl = TextEditingController(text: editMember?.telepon ?? '');
    final poinCtrl = TextEditingController(
      text: editMember != null ? editMember.poin.toString() : '0',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surfaceColor,
        title: Text(
          isBaru ? 'Daftar Member Baru' : 'Edit Data Member',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: namaCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Pelanggan',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: telpCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'No. HP / WhatsApp',
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.currentStaff.isStoreSystem) ...[
              const SizedBox(height: 10),
              TextField(
                controller: poinCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Saldo Poin Member',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: t.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final nama = namaCtrl.text.trim();
              if (nama.isEmpty) return;
              final mbr = MemberPelanggan(
                id: editMember?.id ??
                    'mbr_${DateTime.now().millisecondsSinceEpoch}',
                nama: nama,
                telepon: telpCtrl.text.trim(),
                poin: int.tryParse(poinCtrl.text) ?? (editMember?.poin ?? 0),
                totalBelanja: editMember?.totalBelanja ?? 0,
                jumlahKunjungan: editMember?.jumlahKunjungan ?? 0,
              );
              Navigator.pop(ctx);
              widget.onSimpanMember(mbr, isBaru);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tema;
    final daftarKasbon =
        widget.daftarTransaksi.where((trx) => !trx.statusLunas).toList();
    final totalPiutang =
        daftarKasbon.fold<int>(0, (s, trx) => s + trx.sisaPiutang);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(
                value: 0,
                label: Text('Kasbon (${daftarKasbon.length})'),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Member (${widget.daftarMember.length})'),
              ),
            ],
            selected: {_subTab},
            onSelectionChanged: (v) => setState(() => _subTab = v.first),
          ),
        ),
        if (_subTab == 0) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: MetricTile(
              tema: t,
              label: 'Total Piutang Kasbon Belum Lunas',
              value: formatRupiah(totalPiutang),
              sublabel: '${daftarKasbon.length} transaksi aktif',
              valueColor:
                  totalPiutang > 0 ? t.warningColor : t.successColor,
              icon: Icons.account_balance_wallet_outlined,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: daftarKasbon.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada tagihan kasbon yang belum lunas.',
                      style: TextStyle(color: t.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                    itemCount: daftarKasbon.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final trx = daftarKasbon[idx];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: dekorasiKartu(t),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  trx.namaPelanggan,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                StatusBadge(
                                  label:
                                      'SISA ${formatRupiah(trx.sisaPiutang)}',
                                  color: t.warningColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${trx.nomorStruk} • ${formatTanggalWaktu(trx.tanggal)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: t.textSecondary,
                              ),
                            ),
                            Text(
                              'Total: ${formatRupiah(trx.totalBelanja)} • DP: ${formatRupiah(trx.bayar)}',
                              style: gayaAngka(
                                TextStyle(
                                  fontSize: 12,
                                  color: t.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () => tampilkanStrukDigital(
                                    context: context,
                                    tema: t,
                                    transaksi: trx,
                                    toko: widget.toko,
                                    currentStaff: widget.currentStaff,
                                    daftarStaff: widget.daftarStaff,
                                  ),
                                  child: const Text('Detail Struk'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: t.successColor,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => _dialogCicilKasbon(trx),
                                  child: const Text('Cicil / Lunasi'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '1 Poin tiap belanja ${formatRupiah(widget.toko.nominalPerPoin)}',
                  style: TextStyle(fontSize: 12, color: t.textSecondary),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _dialogFormMember(),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
                  label: const Text('Member'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
              itemCount: widget.daftarMember.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final m = widget.daftarMember[idx];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: dekorasiKartu(t),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.nama,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${m.telepon.isEmpty ? 'Tanpa No. HP' : m.telepon} • ${m.jumlahKunjungan}x transaksi',
                              style: TextStyle(
                                fontSize: 11,
                                color: t.textSecondary,
                              ),
                            ),
                            Text(
                              'Total Belanja: ${formatRupiah(m.totalBelanja)}',
                              style: gayaAngka(
                                TextStyle(
                                  fontSize: 11,
                                  color: t.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(
                        label: '${m.poin} PTS',
                        color: t.primaryColor,
                      ),
                      IconButton(
                        onPressed: () => _dialogFormMember(editMember: m),
                        icon: const Icon(Icons.edit_outlined, size: 19),
                      ),
                      if (widget.currentStaff.isStoreSystem)
                        IconButton(
                          onPressed: () => widget.onHapusMember(m.id),
                          icon: Icon(
                            Icons.delete_outline,
                            size: 19,
                            color: t.dangerColor,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
