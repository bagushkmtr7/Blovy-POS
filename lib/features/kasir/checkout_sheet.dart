import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../widgets/pos_components.dart';

void tampilkanModalCheckout({
  required BuildContext context,
  required AppThemeConfig tema,
  required PengaturanToko toko,
  required List<Produk> daftarProduk,
  required List<MemberPelanggan> daftarMember,
  required List<PromoVoucher> daftarPromo,
  required Map<String, int> keranjang,
  required void Function(String produkId, int delta) onUbahQty,
  required VoidCallback onKosongkan,
  required void Function(String labelPelanggan) onTahanKeranjang,
  required void Function({
    required int diskon,
    required String kodePromo,
    required int pajak,
    required int serviceCharge,
    required int bayar,
    required String metodeBayar,
    required bool statusLunas,
    required String memberId,
    required String namaPelanggan,
    required int poinDipakai,
    required int poinDidapat,
    required String catatan,
  }) onSelesaikan,
}) {
  final bayarCtrl = TextEditingController();
  final diskonManualCtrl = TextEditingController(text: '0');
  final pelangganCtrl = TextEditingController(text: 'Pelanggan Umum');
  final catatanCtrl = TextEditingController();

  String metode = 'Tunai';
  bool diskonPersen = false;
  MemberPelanggan? memberDipilih;
  PromoVoucher? promoDipilih;
  bool tukarPoin = false;

  List<ItemKeranjang> bangunItems() {
    final hasil = <ItemKeranjang>[];
    for (final entry in keranjang.entries) {
      final idx = daftarProduk.indexWhere((p) => p.id == entry.key);
      if (idx != -1 && entry.value > 0) {
        hasil.add(ItemKeranjang(produk: daftarProduk[idx], qty: entry.value));
      }
    }
    return hasil;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: tema.surfaceColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(tema.radius + 6)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModal) {
        final items = bangunItems();
        final subtotal = items.fold<int>(0, (sum, e) => sum + e.subtotal);

        final diskonPromo =
            promoDipilih != null ? promoDipilih!.hitungDiskon(subtotal) : 0;
        final rawManual =
            int.tryParse(diskonManualCtrl.text.replaceAll('.', '')) ?? 0;
        final diskonManual = diskonPersen
            ? ((subtotal * rawManual.clamp(0, 100)) / 100).round()
            : rawManual.clamp(0, subtotal);

        final totalDiskon = (diskonPromo + diskonManual).clamp(0, subtotal);
        final sisaSetelahDiskon = (subtotal - totalDiskon).clamp(0, subtotal);

        int poinDipakai = 0;
        int potonganPoin = 0;
        if (tukarPoin &&
            memberDipilih != null &&
            memberDipilih!.poin > 0 &&
            toko.nilaiTukarPoin > 0) {
          final maksPoinTagihan = sisaSetelahDiskon ~/ toko.nilaiTukarPoin;
          poinDipakai = memberDipilih!.poin.clamp(0, maksPoinTagihan);
          potonganPoin = poinDipakai * toko.nilaiTukarPoin;
        }

        final dasarTagihan =
            (sisaSetelahDiskon - potonganPoin).clamp(0, sisaSetelahDiskon);
        final nominalService = toko.persenService > 0
            ? ((dasarTagihan * toko.persenService) / 100).round()
            : 0;
        final nominalPajak = toko.persenPajak > 0
            ? (((dasarTagihan + nominalService) * toko.persenPajak) / 100)
                .round()
            : 0;
        final totalAkhir = dasarTagihan + nominalService + nominalPajak;

        final poinDidapat =
            (memberDipilih != null && toko.nominalPerPoin > 0)
                ? (totalAkhir ~/ toko.nominalPerPoin)
                : 0;

        if ((metode == 'QRIS' || metode == 'Transfer / Debit') &&
            bayarCtrl.text.isEmpty) {
          bayarCtrl.text = totalAkhir.toString();
        }

        final nominalBayar =
            int.tryParse(bayarCtrl.text.replaceAll('.', '')) ?? 0;
        final isKasbon = metode == 'Kasbon';
        final selisih = nominalBayar - totalAkhir;
        final validBayar = items.isNotEmpty &&
            (isKasbon
                ? (nominalBayar >= 0 && nominalBayar < totalAkhir)
                : nominalBayar >= totalAkhir);

        final promoAktifList = daftarPromo.where((p) => p.aktif).toList();

        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withAlpha(100),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Ringkasan & Pembayaran',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Parkir Antrean (Hold)',
                      onPressed: items.isEmpty
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              onTahanKeranjang(pelangganCtrl.text.trim());
                            },
                      icon: Icon(
                        Icons.pause_circle_outline_rounded,
                        color: tema.accentColor,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kosongkan Keranjang',
                      onPressed: () {
                        onKosongkan();
                        Navigator.pop(ctx);
                      },
                      icon: Icon(
                        Icons.delete_sweep_rounded,
                        color: tema.dangerColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...items.map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: tema.inputColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tema.borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      item.produk.nama,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (item.dapatGrosir) ...[
                                    const SizedBox(width: 6),
                                    StatusBadge(
                                      label: 'GROSIR',
                                      color: tema.primaryColor,
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '${formatRupiah(item.hargaSatuanAktif)}/${item.produk.satuan} • ${formatRupiah(item.subtotal)}',
                                style: gayaAngka(
                                  TextStyle(
                                    fontSize: 11,
                                    color: tema.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            onUbahQty(item.produk.id, -1);
                            setModal(() {});
                          },
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          visualDensity: VisualDensity.compact,
                        ),
                        Text(
                          '${item.qty}',
                          style: gayaAngka(
                            const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: item.qty >= item.produk.stok
                              ? null
                              : () {
                                  onUbahQty(item.produk.id, 1);
                                  setModal(() {});
                                },
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (memberDipilih != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: tema.primaryColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tema.primaryColor.withAlpha(90)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.card_membership_rounded,
                          color: tema.primaryColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${memberDipilih!.nama} (${memberDipilih!.telepon})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Saldo Poin: ${memberDipilih!.poin} pts',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: tema.successColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Lepas Member',
                          onPressed: () {
                            setModal(() {
                              memberDipilih = null;
                              tukarPoin = false;
                              hpMemberCtrl.clear();
                              pelangganCtrl.text = 'Pelanggan Umum';
                            });
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: hpMemberCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Nomor HP Member (08xx)',
                            hintText: 'Ketik no. HP member...',
                            prefixIcon: const Icon(Icons.phone_android_rounded),
                            filled: true,
                            fillColor: tema.inputColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: tema.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                        ),
                        onPressed: () {
                          final q = hpMemberCtrl.text
                              .replaceAll(RegExp(r'[^0-9]'), '');
                          if (q.isEmpty) return;
                          final cocok = daftarMember.where((m) {
                            final hp =
                                m.telepon.replaceAll(RegExp(r'[^0-9]'), '');
                            return hp == q ||
                                (q.length >= 4 && hp.endsWith(q));
                          });
                          if (cocok.isNotEmpty) {
                            final m = cocok.first;
                            setModal(() {
                              memberDipilih = m;
                              tukarPoin = false;
                              pelangganCtrl.text = m.nama;
                              hpMemberCtrl.text = m.telepon;
                            });
                          } else {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Nomor HP tidak terdaftar. Daftar member baru hanya di menu SIS.',
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text('Cek HP'),
                      ),
                    ],
                  ),
                if (memberDipilih != null && memberDipilih!.poin > 0) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    tileColor: tema.inputColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    title: Text(
                      'Tukar ${memberDipilih!.poin} Poin Member',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '1 poin = ${formatRupiah(toko.nilaiTukarPoin)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    value: tukarPoin,
                    onChanged: (v) => setModal(() => tukarPoin = v),
                  ),
                ],
                const SizedBox(height: 10),
                if (promoAktifList.isNotEmpty) ...[
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: promoAktifList.map((prm) {
                        final terpilih = promoDipilih?.id == prm.id;
                        final memenuhi = subtotal >= prm.minBelanja;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            selected: terpilih,
                            label: Text(
                              '${prm.kode} (${prm.isPersen ? '${prm.nilai}%' : formatRupiah(prm.nilai)})',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onSelected: !memenuhi
                                ? null
                                : (val) => setModal(
                                      () => promoDipilih = val ? prm : null,
                                    ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: diskonManualCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setModal(() {}),
                        decoration: InputDecoration(
                          labelText: diskonPersen
                              ? 'Diskon Tambahan (%)'
                              : 'Diskon Tambahan (Rp)',
                          filled: true,
                          fillColor: tema.inputColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      onPressed: () => setModal(() {
                        diskonPersen = !diskonPersen;
                        diskonManualCtrl.text = '0';
                      }),
                      icon: Icon(
                        diskonPersen ? Icons.percent_rounded : Icons.money_off,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: kMetodePembayaran.map((m) {
                    final aktif = metode == m;
                    return ChoiceChip(
                      label: Text(m),
                      selected: aktif,
                      selectedColor:
                          m == 'Kasbon' ? tema.warningColor : tema.primaryColor,
                      labelStyle: TextStyle(
                        color: aktif ? Colors.white : null,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      onSelected: (_) {
                        setModal(() {
                          metode = m;
                          if (m == 'QRIS' || m == 'Transfer / Debit') {
                            bayarCtrl.text = totalAkhir.toString();
                          } else if (m == 'Kasbon') {
                            bayarCtrl.text = '0';
                          } else {
                            bayarCtrl.clear();
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bayarCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setModal(() {}),
                  style: gayaAngka(
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  decoration: InputDecoration(
                    labelText: isKasbon
                        ? 'Uang Muka / DP Kasbon'
                        : 'Nominal Diterima',
                    prefixText: 'Rp ',
                    filled: true,
                    fillColor: tema.inputColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                if (metode == 'Tunai') ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      ActionChip(
                        label: const Text('Uang Pas'),
                        onPressed: () {
                          bayarCtrl.text = totalAkhir.toString();
                          setModal(() {});
                        },
                      ),
                      ActionChip(
                        label: const Text('Rp 20.000'),
                        onPressed: () {
                          bayarCtrl.text = '20000';
                          setModal(() {});
                        },
                      ),
                      ActionChip(
                        label: const Text('Rp 50.000'),
                        onPressed: () {
                          bayarCtrl.text = '50000';
                          setModal(() {});
                        },
                      ),
                      ActionChip(
                        label: const Text('Rp 100.000'),
                        onPressed: () {
                          bayarCtrl.text = '100000';
                          setModal(() {});
                        },
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tema.inputColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tema.borderColor),
                  ),
                  child: Column(
                    children: [
                      _BarisRingkasan('Subtotal', formatRupiah(subtotal)),
                      if (totalDiskon > 0)
                        _BarisRingkasan(
                          'Total Diskon',
                          '-${formatRupiah(totalDiskon)}',
                          warna: tema.dangerColor,
                        ),
                      if (potonganPoin > 0)
                        _BarisRingkasan(
                          'Potongan Poin ($poinDipakai pts)',
                          '-${formatRupiah(potonganPoin)}',
                          warna: tema.accentColor,
                        ),
                      if (nominalService > 0)
                        _BarisRingkasan(
                          'Service (${toko.persenService}%)',
                          '+${formatRupiah(nominalService)}',
                        ),
                      if (nominalPajak > 0)
                        _BarisRingkasan(
                          'PPN (${toko.persenPajak}%)',
                          '+${formatRupiah(nominalPajak)}',
                        ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL TAGIHAN',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            formatRupiah(totalAkhir),
                            style: gayaAngka(
                              const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isKasbon
                                ? 'Sisa Piutang Kasbon'
                                : (selisih >= 0 ? 'Kembalian' : 'Kurang Bayar'),
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            formatRupiah(selisih.abs()),
                            style: gayaAngka(
                              TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isKasbon
                                    ? tema.warningColor
                                    : (selisih >= 0
                                        ? tema.successColor
                                        : tema.dangerColor),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        isKasbon ? tema.warningColor : tema.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: !validBayar
                      ? null
                      : () {
                          final namaPlg = pelangganCtrl.text.trim();
                          if (isKasbon &&
                              (namaPlg.isEmpty ||
                                  namaPlg == 'Pelanggan Umum')) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Wajib isi nama pelanggan untuk transaksi Kasbon.',
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          onSelesaikan(
                            diskon: totalDiskon,
                            kodePromo: promoDipilih?.kode ?? '',
                            pajak: nominalPajak,
                            serviceCharge: nominalService,
                            bayar: nominalBayar,
                            metodeBayar: metode,
                            statusLunas: !isKasbon,
                            memberId: memberDipilih?.id ?? '',
                            namaPelanggan:
                                namaPlg.isEmpty ? 'Pelanggan Umum' : namaPlg,
                            poinDipakai: poinDipakai,
                            poinDidapat: poinDidapat,
                            catatan: catatanCtrl.text.trim(),
                          );
                        },
                  icon: Icon(
                    isKasbon
                        ? Icons.receipt_long_rounded
                        : Icons.check_circle_rounded,
                  ),
                  label: Text(
                    isKasbon ? 'Simpan Piutang Kasbon' : 'Bayar & Cetak Struk',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _BarisRingkasan extends StatelessWidget {
  final String label;
  final String nilai;
  final Color? warna;

  const _BarisRingkasan(this.label, this.nilai, {this.warna});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            nilai,
            style: gayaAngka(
              TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: warna,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
