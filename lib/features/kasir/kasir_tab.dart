import '../../widgets/clerek_blind_dialog.dart';
import '../../models/clerek_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../widgets/pos_components.dart';

class KasirTab extends StatefulWidget {
  final AppThemeConfig tema;
  final PengaturanToko toko;
  final AkunStaff currentStaff;
  final ShiftKasir? shiftAktif;
  final List<Produk> daftarProduk;
  final List<MemberPelanggan> daftarMember;
  final List<PromoVoucher> daftarPromo;
  final List<KeranjangTertahan> daftarHold;
  final Map<String, int> keranjang;
  final void Function(String produkId, int delta) onUbahQty;
  final VoidCallback onKosongkanKeranjang;
  final void Function(String labelPelanggan) onTahanKeranjang;
  final void Function(KeranjangTertahan hold) onPulihkanHold;
  final void Function(String holdId) onHapusHold;
  final void Function({
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
  }) onSelesaikanTransaksi;
  final void Function(int kasAktual) onTutupShift;
  final void Function(int modalAwal) onBukaShift;
  final VoidCallback onKunciLayar;
  final TransaksiPos? strukTerakhir;
  final VoidCallback? onCetakUlangStrukTerakhir;

  const KasirTab({
    super.key,
    required this.tema,
    required this.toko,
    required this.currentStaff,
    required this.shiftAktif,
    required this.daftarProduk,
    required this.daftarMember,
    required this.daftarPromo,
    required this.daftarHold,
    required this.keranjang,
    required this.onUbahQty,
    required this.onKosongkanKeranjang,
    required this.onTahanKeranjang,
    required this.onPulihkanHold,
    required this.onHapusHold,
    required this.onSelesaikanTransaksi,
    required this.onTutupShift,
    required this.onBukaShift,
    required this.onKunciLayar,
    this.strukTerakhir,
    this.onCetakUlangStrukTerakhir,
  });

  @override
  State<KasirTab> createState() => _KasirTabState();
}

class _KasirTabState extends State<KasirTab> {
  final TextEditingController _cariCtrl = TextEditingController();
  final TextEditingController _bayarCtrl = TextEditingController();
  final TextEditingController _diskonCtrl = TextEditingController(text: '0');
  final TextEditingController _pelangganCtrl =
      TextEditingController(text: 'Pelanggan Umum');

  String _kategoriAktif = 'Semua';
  bool _isGridView = true;
  bool _laciTerbuka = false;
  bool _opsiTambahanTerbuka = false;

  String _metodeBayar = 'Tunai';
  bool _diskonPersen = false;
  MemberPelanggan? _memberDipilih;
  final TextEditingController _hpMemberCtrl = TextEditingController();
  PromoVoucher? _promoDipilih;
  bool _tukarPoin = false;

  @override
  void dispose() {
    _cariCtrl.dispose();
    _bayarCtrl.dispose();
    _diskonCtrl.dispose();
    _pelangganCtrl.dispose();
    _hpMemberCtrl.dispose();
    super.dispose();
  }

  void _resetFormPembayaran() {
    setState(() {
      _metodeBayar = 'Tunai';
      _bayarCtrl.clear();
      _diskonCtrl.text = '0';
      _diskonPersen = false;
      _memberDipilih = null;
      _promoDipilih = null;
      _tukarPoin = false;
      _pelangganCtrl.text = 'Pelanggan Umum';
      _laciTerbuka = false;
      _opsiTambahanTerbuka = false;
    });
  }

  void _prosesScanAtauEnterSku(String input) {
    final kode = input.trim().toLowerCase();
    if (kode.isEmpty) return;
    final idx = widget.daftarProduk.indexWhere(
      (p) => p.kodeSku.toLowerCase() == kode || p.nama.toLowerCase() == kode,
    );
    if (idx != -1) {
      final prod = widget.daftarProduk[idx];
      final qtyAda = widget.keranjang[prod.id] ?? 0;
      if (prod.stok > qtyAda) {
        HapticFeedback.mediumImpact();
        widget.onUbahQty(prod.id, 1);
        _cariCtrl.clear();
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stok ${prod.nama} tidak mencukupi.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<int> _buatPecahanCepat(int total) {
    if (total <= 0) return [];
    final hasil = <int>{};
    final bulat5k = ((total + 4999) ~/ 5000) * 5000;
    final bulat10k = ((total + 9999) ~/ 10000) * 10000;
    final bulat50k = ((total + 49999) ~/ 50000) * 50000;
    final bulat100k = ((total + 99999) ~/ 100000) * 100000;

    for (final p in [bulat5k, bulat10k, 20000, 50000, bulat50k, 100000, bulat100k]) {
      if (p > total && hasil.length < 3) {
        hasil.add(p);
      }
    }
    final sorted = hasil.toList()..sort();
    return sorted.take(3).toList();
  }

  void _dialogInputQty(ItemKeranjang item) {
    final t = widget.tema;
    String inputAngka = item.qty.toString();
    bool timpaAwal = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final nilai = int.tryParse(inputAngka) ?? 0;
          final melebihiStok = nilai > item.produk.stok;

          void tekan(String digit) {
            HapticFeedback.selectionClick();
            setDlg(() {
              if (timpaAwal) {
                inputAngka = digit;
                timpaAwal = false;
              } else if (inputAngka.length < 4) {
                inputAngka = inputAngka == '0' ? digit : '$inputAngka$digit';
              }
            });
          }

          return AlertDialog(
            backgroundColor: t.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(t.radius + 2),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.produk.nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Stok tersedia: ${item.produk.stok} ${item.produk.satuan}',
                  style: TextStyle(fontSize: 11, color: t.textSecondary),
                ),
              ],
            ),
            content: SizedBox(
              width: 260,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: t.inputColor,
                      borderRadius: BorderRadius.circular(t.radius),
                      border: Border.all(
                        color: melebihiStok ? t.dangerColor : t.primaryColor,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Jumlah (${item.produk.satuan})',
                          style: TextStyle(
                            fontSize: 11,
                            color: t.textSecondary,
                          ),
                        ),
                        Text(
                          inputAngka.isEmpty ? '0' : inputAngka,
                          style: gayaAngka(
                            TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: melebihiStok
                                  ? t.dangerColor
                                  : t.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (melebihiStok)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Maksimal ${item.produk.stok} ${item.produk.satuan}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: t.dangerColor,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1.7,
                    children: [
                      for (final d in [
                        '1',
                        '2',
                        '3',
                        '4',
                        '5',
                        '6',
                        '7',
                        '8',
                        '9'
                      ])
                        _TombolKeypadQty(
                          tema: t,
                          label: d,
                          onTap: () => tekan(d),
                        ),
                      _TombolKeypadQty(
                        tema: t,
                        label: 'C',
                        isSecondary: true,
                        onTap: () => setDlg(() {
                          inputAngka = '0';
                          timpaAwal = true;
                        }),
                      ),
                      _TombolKeypadQty(
                        tema: t,
                        label: '0',
                        onTap: () => tekan('0'),
                      ),
                      _TombolKeypadQty(
                        tema: t,
                        icon: Icons.backspace_outlined,
                        isSecondary: true,
                        onTap: () => setDlg(() {
                          timpaAwal = false;
                          if (inputAngka.length <= 1) {
                            inputAngka = '0';
                          } else {
                            inputAngka =
                                inputAngka.substring(0, inputAngka.length - 1);
                          }
                        }),
                      ),
                    ],
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
                  backgroundColor: t.primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: melebihiStok
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        final delta = nilai - item.qty;
                        if (delta != 0) {
                          widget.onUbahQty(item.produk.id, delta);
                        }
                      },
                child: const Text('Terapkan'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _dialogTahanDariPanel() {
    final t = widget.tema;
    final labelCtrl = TextEditingController(
      text: _pelangganCtrl.text == 'Pelanggan Umum' ? '' : _pelangganCtrl.text,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surfaceColor,
        title: const Text(
          'Parkir Antrean (Hold)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: labelCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nama / Nomor Meja / Keterangan',
            hintText: 'Contoh: Ibu Rina / Meja 3',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: t.accentColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onTahanKeranjang(labelCtrl.text.trim());
              _resetFormPembayaran();
            },
            child: const Text('Parkir Keranjang'),
          ),
        ],
      ),
    );
  }

  void _tampilkanAntreanHold() {
    final t = widget.tema;
    showModalBottomSheet(
      context: context,
      backgroundColor: t.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.radius + 4)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Antrean Keranjang Tertahan (Hold)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (widget.daftarHold.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Text(
                  'Belum ada keranjang yang diparkir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.textSecondary),
                ),
              )
            else
              ...widget.daftarHold.map(
                (h) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: dekorasiKartu(t),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${h.totalQty} item • ${formatTanggalWaktu(h.waktu)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: t.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          widget.onHapusHold(h.id);
                          Navigator.pop(ctx);
                        },
                        icon: Icon(
                          Icons.delete_outline,
                          color: t.dangerColor,
                          size: 20,
                        ),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: t.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(t.radius),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          widget.onPulihkanHold(h);
                        },
                        child: const Text('Lanjutkan'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _tampilkanDialogShift() async {
    final shift = widget.shiftAktif;
    if (shift == null) return;

    final namaOtorisasi = await tampilkanDialogTutupShiftKasir(
      context: context,
      tema: widget.tema,
      shift: shift,
      daftarStaff: const [],
    );

    if (namaOtorisasi == null || !mounted) return;

    final waktuTutup = DateTime.now();
    final draftClerek = buatDraftClerekDariShift(
      shift: shift,
      namaOtorisasiTutup: namaOtorisasi,
      daftarTransaksi: const [],
      daftarPengeluaran: const [],
      waktuTutup: waktuTutup,
    );
    await ClerekStorageService.simpan(draftClerek);
    widget.onTutupShift(0);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Clerek ${draftClerek.nomorClerek} berhasil. Input setoran fisik dilakukan di menu SIS.',
        ),
      ),
    );
  }

  List<ItemKeranjang> _bangunDaftarKeranjang() {
    final hasil = <ItemKeranjang>[];
    for (final entry in widget.keranjang.entries) {
      final idx = widget.daftarProduk.indexWhere((p) => p.id == entry.key);
      if (idx != -1 && entry.value > 0) {
        hasil.add(
          ItemKeranjang(produk: widget.daftarProduk[idx], qty: entry.value),
        );
      }
    }
    return hasil;
  }

  void _eksekusiPembayaran({
    required int totalDiskon,
    required int nominalPajak,
    required int nominalService,
    required int nominalBayar,
    required int poinDipakai,
    required int poinDidapat,
  }) {
    if (widget.shiftAktif == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Buka Shift Kasir terlebih dahulu sebelum transaksi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _tampilkanDialogShift();
      return;
    }

    final isKasbon = _metodeBayar == 'Kasbon';
    final namaPlg = _pelangganCtrl.text.trim();
    if (isKasbon && (namaPlg.isEmpty || namaPlg == 'Pelanggan Umum')) {
      setState(() {
        _opsiTambahanTerbuka = true;
        _laciTerbuka = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi nama pelanggan dulu untuk transaksi Kasbon.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    widget.onSelesaikanTransaksi(
      diskon: totalDiskon,
      kodePromo: _promoDipilih?.kode ?? '',
      pajak: nominalPajak,
      serviceCharge: nominalService,
      bayar: nominalBayar,
      metodeBayar: _metodeBayar,
      statusLunas: !isKasbon,
      memberId: _memberDipilih?.id ?? '',
      namaPelanggan: namaPlg.isEmpty ? 'Pelanggan Umum' : namaPlg,
      poinDipakai: poinDipakai,
      poinDidapat: poinDidapat,
      catatan: '',
    );
    _resetFormPembayaran();
  }


  String _normalisasiHp(String raw) =>
      raw.replaceAll(RegExp(r'[^0-9]'), '');

  void _cariMemberDenganHp(String inputHp) {
    final bersih = _normalisasiHp(inputHp);
    if (bersih.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan nomor HP member terlebih dahulu.'),
        ),
      );
      return;
    }

    final exact = widget.daftarMember.where(
      (m) => _normalisasiHp(m.telepon) == bersih,
    );
    final partial = widget.daftarMember.where(
      (m) =>
          bersih.length >= 4 &&
          _normalisasiHp(m.telepon).endsWith(bersih),
    );

    final ditemukan = exact.isNotEmpty
        ? exact.first
        : (partial.length == 1 ? partial.first : null);

    if (ditemukan != null) {
      setState(() {
        _memberDipilih = ditemukan;
        _tukarPoin = false;
        _pelangganCtrl.text = ditemukan.nama;
        _hpMemberCtrl.text = ditemukan.telepon;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Member terhubung: ${ditemukan.nama} (${ditemukan.poin} poin)',
          ),
        ),
      );
      return;
    }

    // Jika lebih dari 1 kecocokan sebagian atau belum terdaftar, buka modal pencarian HP
    _bukaModalCariMemberHp(initialQuery: inputHp.trim());
  }

  void _bukaModalCariMemberHp({String initialQuery = ''}) {
    final t = widget.tema;
    final searchCtrl = TextEditingController(text: initialQuery);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final q = searchCtrl.text.trim().toLowerCase();
          final qDigits = _normalisasiHp(q);
          final hasil = widget.daftarMember.where((m) {
            if (q.isEmpty) return true;
            return m.nama.toLowerCase().contains(q) ||
                (qDigits.isNotEmpty &&
                    _normalisasiHp(m.telepon).contains(qDigits));
          }).toList();

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.65,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.card_membership_rounded,
                          color: t.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Cari Member via Nomor HP',
                            style: TextStyle(
                              fontSize: 15,
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
                    const SizedBox(height: 6),
                    TextField(
                      controller: searchCtrl,
                      keyboardType: TextInputType.phone,
                      autofocus: true,
                      onChanged: (_) => setModal(() {}),
                      decoration: InputDecoration(
                        hintText: 'Ketik nomor HP (08xx) atau nama member...',
                        prefixIcon: const Icon(Icons.phone_android_rounded, size: 19),
                        suffixIcon: searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  searchCtrl.clear();
                                  setModal(() {});
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: t.inputColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Pendaftaran member baru dilakukan oleh Admin di menu SIS → Promo & CRM → Member.',
                        style: TextStyle(
                          fontSize: 11,
                          color: t.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: hasil.isEmpty
                          ? Center(
                              child: Text(
                                'Nomor HP / member tidak ditemukan.\nDaftarkan member baru melalui menu SIS.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: t.textSecondary,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: hasil.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (_, idx) {
                                final m = hasil[idx];
                                return ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(color: t.borderColor),
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        t.primaryColor.withAlpha(24),
                                    child: Icon(
                                      Icons.person_rounded,
                                      color: t.primaryColor,
                                    ),
                                  ),
                                  title: Text(
                                    m.nama,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'HP: ${m.telepon.isEmpty ? "-" : m.telepon}',
                                    style: gayaAngka(
                                      const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  trailing: StatusBadge(
                                    label: '${m.poin} PTS',
                                    color: t.successColor,
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    setState(() {
                                      _memberDipilih = m;
                                      _tukarPoin = false;
                                      _pelangganCtrl.text = m.nama;
                                      _hpMemberCtrl.text = m.telepon;
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tema;
    final query = _cariCtrl.text.trim().toLowerCase();

    final produkTersaring = widget.daftarProduk.where((p) {
      final cocokKategori =
          _kategoriAktif == 'Semua' || p.kategori == _kategoriAktif;
      final cocokCari = query.isEmpty ||
          p.nama.toLowerCase().contains(query) ||
          p.kodeSku.toLowerCase().contains(query);
      return cocokKategori && cocokCari;
    }).toList();

    final itemsKeranjang = _bangunDaftarKeranjang();
    final totalItem = itemsKeranjang.fold<int>(0, (s, e) => s + e.qty);
    final subtotal = itemsKeranjang.fold<int>(0, (s, e) => s + e.subtotal);

    // Kalkulasi Diskon, Poin, Pajak, Service secara Live
    final diskonPromo =
        _promoDipilih != null ? _promoDipilih!.hitungDiskon(subtotal) : 0;
    final rawManual =
        int.tryParse(_diskonCtrl.text.replaceAll('.', '')) ?? 0;
    final diskonManual = _diskonPersen
        ? ((subtotal * rawManual.clamp(0, 100)) / 100).round()
        : rawManual.clamp(0, subtotal);
    final totalDiskon = (diskonPromo + diskonManual).clamp(0, subtotal);
    final sisaSetelahDiskon = (subtotal - totalDiskon).clamp(0, subtotal);

    int poinDipakai = 0;
    int potonganPoin = 0;
    if (_tukarPoin &&
        _memberDipilih != null &&
        _memberDipilih!.poin > 0 &&
        widget.toko.nilaiTukarPoin > 0) {
      final maksPoin = sisaSetelahDiskon ~/ widget.toko.nilaiTukarPoin;
      poinDipakai = _memberDipilih!.poin.clamp(0, maksPoin);
      potonganPoin = poinDipakai * widget.toko.nilaiTukarPoin;
    }

    final dasarTagihan =
        (sisaSetelahDiskon - potonganPoin).clamp(0, sisaSetelahDiskon);
    final nominalService = widget.toko.persenService > 0
        ? ((dasarTagihan * widget.toko.persenService) / 100).round()
        : 0;
    final nominalPajak = widget.toko.persenPajak > 0
        ? (((dasarTagihan + nominalService) * widget.toko.persenPajak) / 100)
            .round()
        : 0;
    final totalAkhir = dasarTagihan + nominalService + nominalPajak;

    final poinDidapat =
        (_memberDipilih != null && widget.toko.nominalPerPoin > 0)
            ? (totalAkhir ~/ widget.toko.nominalPerPoin)
            : 0;

    final isNonTunaiOtomatis =
        _metodeBayar == 'QRIS' || _metodeBayar == 'Transfer / Debit';
    final isKasbon = _metodeBayar == 'Kasbon';
    final nominalBayar = isNonTunaiOtomatis
        ? totalAkhir
        : (int.tryParse(_bayarCtrl.text.replaceAll('.', '')) ?? 0);
    final selisih = nominalBayar - totalAkhir;
    final validBayar = itemsKeranjang.isNotEmpty &&
        (isKasbon
            ? (nominalBayar >= 0 && nominalBayar < totalAkhir)
            : nominalBayar >= totalAkhir);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSplitScreen = constraints.maxWidth >= 720;
        final jumlahKolomGrid = isSplitScreen
            ? (constraints.maxWidth >= 1080 ? 3 : 2)
            : 2;

        final areaKatalog = Column(
          children: [
            // Bar Status Shift & Operator
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: dekorasiKartu(t),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.shiftAktif != null
                          ? t.successColor
                          : t.warningColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.shiftAktif != null
                          ? 'SHIFT AKTIF • Kasir: ${widget.currentStaff.nama}'
                          : 'SHIFT BELUM DIBUKA • ${widget.currentStaff.nama}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: gayaAngka(
                        const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _tampilkanDialogShift,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 26),
                    ),
                    child: Text(
                      widget.shiftAktif != null ? 'Tutup Shift' : 'Buka Shift',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: widget.shiftAktif != null
                            ? t.dangerColor
                            : t.primaryColor,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ganti Operator / Kunci Layar',
                    onPressed: widget.onKunciLayar,
                    icon: const Icon(Icons.switch_account_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // Bar Scan Barcode + Toggle Grid/List + Antrean Hold
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cariCtrl,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _prosesScanAtauEnterSku,
                      decoration: InputDecoration(
                        hintText: 'Scan Barcode / cari nama produk...',
                        hintStyle: const TextStyle(fontSize: 12),
                        prefixIcon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 18,
                        ),
                        suffixIcon: _cariCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 17),
                                onPressed: () {
                                  _cariCtrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: t.surfaceColor,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(t.radius),
                          borderSide: BorderSide(color: t.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(t.radius),
                          borderSide: BorderSide(color: t.borderColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => setState(() => _isGridView = !_isGridView),
                    borderRadius: BorderRadius.circular(t.radius),
                    child: Container(
                      height: 38,
                      width: 38,
                      decoration: dekorasiKartu(t),
                      child: Icon(
                        _isGridView
                            ? Icons.view_list_rounded
                            : Icons.grid_view_rounded,
                        size: 19,
                        color: t.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Badge(
                    isLabelVisible: widget.daftarHold.isNotEmpty,
                    label: Text('${widget.daftarHold.length}'),
                    child: InkWell(
                      onTap: _tampilkanAntreanHold,
                      borderRadius: BorderRadius.circular(t.radius),
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: dekorasiKartu(t),
                        child: Icon(
                          Icons.pause_presentation_rounded,
                          size: 18,
                          color: t.accentColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Cetak Ulang Struk Terakhir',
                    child: InkWell(
                      onTap: widget.strukTerakhir == null
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Belum ada transaksi pada shift ini.',
                                  ),
                                ),
                              );
                            }
                          : widget.onCetakUlangStrukTerakhir,
                      borderRadius: BorderRadius.circular(t.radius),
                      child: Container(
                        height: 38,
                        width: 38,
                        decoration: dekorasiKartu(t),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          size: 19,
                          color: widget.strukTerakhir != null
                              ? t.primaryColor
                              : t.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tab Kategori Datar
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: kKategoriProduk.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (ctx, idx) {
                  final kat = kKategoriProduk[idx];
                  final aktif = _kategoriAktif == kat;
                  const warnaKat = Color(0xFF0E5A3E);
                  return GestureDetector(
                    onTap: () => setState(() => _kategoriAktif = kat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: aktif ? warnaKat : t.surfaceColor,
                        borderRadius: BorderRadius.circular(t.radius - 2),
                        border: Border.all(
                          color: aktif ? warnaKat : t.borderColor,
                        ),
                      ),
                      child: Text(
                        kat,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: aktif ? Colors.white : t.textPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Katalog Produk (Mode Grid atau Daftar Padat)
            Expanded(
              child: produkTersaring.isEmpty
                  ? Center(
                      child: Text(
                        'Produk tidak ditemukan.',
                        style: TextStyle(color: t.textSecondary),
                      ),
                    )
                  : (_isGridView
                      ? _buildGridProduk(
                          t,
                          produkTersaring,
                          jumlahKolomGrid,
                          isSplitScreen,
                        )
                      : _buildListPadatProduk(
                          t,
                          produkTersaring,
                          isSplitScreen,
                        )),
            ),
          ],
        );

        final panelRegisterUtuh = _buildPanelRegister(
          t: t,
          isSplitScreen: isSplitScreen,
          itemsKeranjang: itemsKeranjang,
          totalItem: totalItem,
          subtotal: subtotal,
          totalDiskon: totalDiskon,
          potonganPoin: potonganPoin,
          poinDipakai: poinDipakai,
          poinDidapat: poinDidapat,
          nominalService: nominalService,
          nominalPajak: nominalPajak,
          totalAkhir: totalAkhir,
          nominalBayar: nominalBayar,
          selisih: selisih,
          validBayar: validBayar,
          isNonTunaiOtomatis: isNonTunaiOtomatis,
          isKasbon: isKasbon,
        );

        // MODE SPLIT-SCREEN (Web / Layar Lebar >= 720px)
        if (isSplitScreen) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 60, child: areaKatalog),
              Container(width: 1, color: t.borderColor),
              Expanded(flex: 40, child: panelRegisterUtuh),
            ],
          );
        }

        // MODE HP PORTRAIT (< 720px) dengan Laci Tarik Bawah
        return Stack(
          children: [
            Positioned.fill(child: areaKatalog),
            if (_laciTerbuka && totalItem > 0)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _laciTerbuka = false),
                  child: Container(color: Colors.black.withAlpha(110)),
                ),
              ),
            if (totalItem > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  height: _laciTerbuka
                      ? constraints.maxHeight * 0.88
                      : 74,
                  decoration: BoxDecoration(
                    color: t.surfaceColor,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(_laciTerbuka ? 14 : 0),
                    ),
                    border: Border(top: BorderSide(color: t.borderColor)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(35),
                        blurRadius: 12,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: _laciTerbuka
                      ? panelRegisterUtuh
                      : _buildBarLaciTertutup(
                          t: t,
                          totalItem: totalItem,
                          totalAkhir: totalAkhir,
                          totalDiskon: totalDiskon,
                          nominalPajak: nominalPajak,
                          nominalService: nominalService,
                          poinDipakai: poinDipakai,
                          poinDidapat: poinDidapat,
                        ),
                ),
              ),
          ],
        );
      },
    );
  }


  String _ikonKategoriCepat(String kategori, String namaProduk) {
    final k = kategori.toLowerCase();
    final n = namaProduk.toLowerCase();
    if (n.contains('mie') || n.contains('mi ')) return '🍜';
    if (n.contains('kopi') || n.contains('teh')) return '☕';
    if (n.contains('air') || n.contains('mineral') || k.contains('minum')) return '💧';
    if (n.contains('beras') || n.contains('telur') || k.contains('sembako')) return '🍚';
    if (n.contains('minyak')) return '🫗';
    if (n.contains('roti') || k.contains('snack')) return '🍪';
    if (n.contains('sabun') || n.contains('sampo') || k.contains('perawatan') || k.contains('kebersihan')) return '🧼';
    if (k.contains('makan')) return '🍱';
    return '📦';
  }

  Widget _buildGridProduk(
    AppThemeConfig t,
    List<Produk> produkTersaring,
    int jumlahKolom,
    bool isSplitScreen,
  ) {
    const warnaHijauRetail = Color(0xFF0E5A3E);
    const warnaBiruGrosir = Color(0xFF1565C0);

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        12,
        2,
        12,
        isSplitScreen ? 20 : 90,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: jumlahKolom,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: isSplitScreen ? 0.96 : 0.92,
      ),
      itemCount: produkTersaring.length,
      itemBuilder: (ctx, idx) {
        final produk = produkTersaring[idx];
        final qtyDiKeranjang = widget.keranjang[produk.id] ?? 0;
        final habis = produk.stok <= 0;
        final menipis = produk.stok > 0 && produk.stok < 5;
        final grosirAktif = produk.isGrosirAktif(qtyDiKeranjang);
        final warnaStok = habis || menipis ? t.dangerColor : warnaHijauRetail;

        return TactilePress(
          onTap: habis
              ? null
              : () {
                  if (qtyDiKeranjang < produk.stok) {
                    HapticFeedback.lightImpact();
                    widget.onUbahQty(produk.id, 1);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Stok ${produk.nama} hanya tersisa ${produk.stok}.',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
          child: Opacity(
            opacity: habis ? 0.55 : 1.0,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: qtyDiKeranjang > 0
                      ? warnaHijauRetail
                      : const Color(0xFFE5E7EB),
                  width: qtyDiKeranjang > 0 ? 1.8 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Baris Atas: Qty di keranjang (jika ada) & Badge Stok Hijau/Merah
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (qtyDiKeranjang > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: warnaHijauRetail,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${qtyDiKeranjang}x',
                            style: gayaAngka(
                              const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: warnaStok,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          habis ? 'Habis' : 'Stok: ${produk.stok}',
                          style: gayaAngka(
                            const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Area Visual Produk Tengah
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _ikonKategoriCepat(produk.kategori, produk.nama),
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                  ),

                  // Nama Produk (Tebal & Jelas)
                  Text(
                    produk.nama,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                      height: 1.18,
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Harga Jual Utama (Hijau Tua Besar)
                  Text(
                    formatRupiah(
                      grosirAktif ? produk.hargaGrosir : produk.hargaJual,
                    ),
                    style: gayaAngka(
                      const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: warnaHijauRetail,
                      ),
                    ),
                  ),

                  // Pill Grosir Biru Padat (jika ada harga grosir)
                  if (produk.hargaGrosir > 0 && produk.minQtyGrosir > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: warnaBiruGrosir,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        'Grosir ≥${produk.minQtyGrosir}: ${formatRupiah(produk.hargaGrosir)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: gayaAngka(
                          const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Peringatan Stok Hampir Habis (< 5)
                  if (menipis) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 12,
                          color: t.dangerColor,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            'Stok hampir habis',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: t.dangerColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildListPadatProduk(
    AppThemeConfig t,
    List<Produk> produkTersaring,
    bool isSplitScreen,
  ) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        12,
        2,
        12,
        isSplitScreen ? 20 : 90,
      ),
      itemCount: produkTersaring.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (ctx, idx) {
        final produk = produkTersaring[idx];
        final qtyDiKeranjang = widget.keranjang[produk.id] ?? 0;
        final habis = produk.stok <= 0;
        final aksenKat = warnaKategori(produk.kategori);

        return TactilePress(
          onTap: habis
              ? null
              : () {
                  if (qtyDiKeranjang < produk.stok) {
                    HapticFeedback.lightImpact();
                    widget.onUbahQty(produk.id, 1);
                  }
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: dekorasiKartu(
              t,
              borderOverride:
                  qtyDiKeranjang > 0 ? t.primaryColor : t.borderColor,
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: aksenKat.withAlpha(28),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    inisialProduk(produk.nama),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: aksenKat,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        produk.nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${produk.kodeSku} • Stok: ${produk.stok} ${produk.satuan}${produk.hargaGrosir > 0 ? ' • Grosir ≥${produk.minQtyGrosir}' : ''}',
                        style: gayaAngka(
                          TextStyle(
                            fontSize: 10.5,
                            color: habis ? t.dangerColor : t.textSecondary,
                          ),
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
                      formatRupiah(
                        produk.hargaUntukQty(
                          qtyDiKeranjang > 0 ? qtyDiKeranjang : 1,
                        ),
                      ),
                      style: gayaAngka(
                        TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: habis ? t.textSecondary : t.primaryColor,
                        ),
                      ),
                    ),
                    if (qtyDiKeranjang > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: t.primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${qtyDiKeranjang}x di keranjang',
                          style: gayaAngka(
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBarLaciTertutup({
    required AppThemeConfig t,
    required int totalItem,
    required int totalAkhir,
    required int totalDiskon,
    required int nominalPajak,
    required int nominalService,
    required int poinDipakai,
    required int poinDidapat,
  }) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -150) {
          setState(() => _laciTerbuka = true);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _laciTerbuka = true),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$totalItem ITEM',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: t.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_up_rounded,
                          size: 16,
                          color: t.primaryColor,
                        ),
                      ],
                    ),
                    Text(
                      formatRupiah(totalAkhir),
                      style: gayaAngka(
                        const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radius),
                ),
              ),
              onPressed: () {
                setState(() {
                  _metodeBayar = 'Tunai';
                  _bayarCtrl.text = totalAkhir.toString();
                });
                _eksekusiPembayaran(
                  totalDiskon: totalDiskon,
                  nominalPajak: nominalPajak,
                  nominalService: nominalService,
                  nominalBayar: totalAkhir,
                  poinDipakai: poinDipakai,
                  poinDidapat: poinDidapat,
                );
              },
              child: const Text(
                'Bayar Pas',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: t.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radius),
                ),
              ),
              onPressed: () => setState(() => _laciTerbuka = true),
              child: const Text(
                'Rincian ▲',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelRegister({
    required AppThemeConfig t,
    required bool isSplitScreen,
    required List<ItemKeranjang> itemsKeranjang,
    required int totalItem,
    required int subtotal,
    required int totalDiskon,
    required int potonganPoin,
    required int poinDipakai,
    required int poinDidapat,
    required int nominalService,
    required int nominalPajak,
    required int totalAkhir,
    required int nominalBayar,
    required int selisih,
    required bool validBayar,
    required bool isNonTunaiOtomatis,
    required bool isKasbon,
  }) {
    final pecahanCepat = _buatPecahanCepat(totalAkhir);
    final promoAktifList = widget.daftarPromo.where((p) => p.aktif).toList();

    return Container(
      color: t.surfaceColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Register (bisa geser ke bawah di HP untuk menutup laci)
          GestureDetector(
            onVerticalDragEnd: isSplitScreen
                ? null
                : (details) {
                    if ((details.primaryVelocity ?? 0) > 150) {
                      setState(() => _laciTerbuka = false);
                    }
                  },
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ORDER & PEMBAYARAN',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                        Text(
                          '$totalItem item • Ketuk angka qty untuk numpad',
                          style: TextStyle(fontSize: 10, color: t.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Member, Promo & Diskon',
                    onPressed: () => setState(
                      () => _opsiTambahanTerbuka = !_opsiTambahanTerbuka,
                    ),
                    icon: Icon(
                      Icons.tune_rounded,
                      size: 19,
                      color: (_memberDipilih != null ||
                              _promoDipilih != null ||
                              totalDiskon > 0)
                          ? t.primaryColor
                          : t.textSecondary,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    tooltip: 'Parkir Antrean (Hold)',
                    onPressed:
                        itemsKeranjang.isEmpty ? null : _dialogTahanDariPanel,
                    icon: Icon(
                      Icons.pause_circle_outline_rounded,
                      size: 19,
                      color: t.accentColor,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    tooltip: 'Kosongkan Keranjang',
                    onPressed: itemsKeranjang.isEmpty
                        ? null
                        : () {
                            widget.onKosongkanKeranjang();
                            _resetFormPembayaran();
                          },
                    icon: Icon(
                      Icons.delete_sweep_rounded,
                      size: 19,
                      color: t.dangerColor,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (!isSplitScreen)
                    IconButton(
                      tooltip: 'Tutup Laci',
                      onPressed: () => setState(() => _laciTerbuka = false),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ),

          // Panel Opsi Tambahan (Member, Promo, Diskon Manual)
          if (_opsiTambahanTerbuka)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: t.inputColor,
                border: Border(bottom: BorderSide(color: t.borderColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_memberDipilih != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: t.primaryColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: t.primaryColor.withAlpha(90)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            size: 18,
                            color: t.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_memberDipilih!.nama} • ${_memberDipilih!.telepon}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Saldo Poin: ${_memberDipilih!.poin} pts',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: t.successColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Lepas Member',
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              setState(() {
                                _memberDipilih = null;
                                _tukarPoin = false;
                                _hpMemberCtrl.clear();
                                _pelangganCtrl.text = 'Pelanggan Umum';
                              });
                            },
                            icon: const Icon(Icons.close_rounded, size: 17),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _hpMemberCtrl,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(fontSize: 12),
                            onSubmitted: _cariMemberDenganHp,
                            decoration: const InputDecoration(
                              labelText: 'No. HP Member (08xx)',
                              hintText: 'Masukkan nomor HP member...',
                              prefixIcon: Icon(Icons.phone_android_rounded, size: 17),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: t.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 10,
                            ),
                          ),
                          onPressed: () =>
                              _cariMemberDenganHp(_hpMemberCtrl.text),
                          child: const Text(
                            'Cari HP',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Daftar Member Terdaftar',
                          onPressed: () => _bukaModalCariMemberHp(),
                          icon: Icon(
                            Icons.card_membership_rounded,
                            size: 20,
                            color: t.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  if (_memberDipilih != null && _memberDipilih!.poin > 0)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Tukar ${_memberDipilih!.poin} Poin (1 pt = ${formatRupiah(widget.toko.nilaiTukarPoin)})',
                        style: const TextStyle(fontSize: 11),
                      ),
                      value: _tukarPoin,
                      onChanged: (v) => setState(() => _tukarPoin = v ?? false),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _diskonCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            labelText:
                                _diskonPersen ? 'Diskon (%)' : 'Diskon (Rp)',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => setState(() {
                          _diskonPersen = !_diskonPersen;
                          _diskonCtrl.text = '0';
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: dekorasiKartu(t),
                          child: Text(
                            _diskonPersen ? '%' : 'Rp',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (promoAktifList.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 28,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: promoAktifList.map((prm) {
                          final terpilih = _promoDipilih?.id == prm.id;
                          final memenuhi = subtotal >= prm.minBelanja;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: !memenuhi
                                  ? null
                                  : () => setState(
                                        () => _promoDipilih =
                                            terpilih ? null : prm,
                                      ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: terpilih
                                      ? t.primaryColor
                                      : (memenuhi
                                          ? t.surfaceColor
                                          : t.bgColor),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: terpilih
                                        ? t.primaryColor
                                        : t.borderColor,
                                  ),
                                ),
                                child: Text(
                                  '${prm.kode} (${prm.isPersen ? '${prm.nilai}%' : formatRupiah(prm.nilai)})',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: terpilih
                                        ? Colors.white
                                        : (memenuhi
                                            ? t.textPrimary
                                            : t.textSecondary),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Daftar Item Keranjang (Bisa Geser Hapus & Ketuk Qty untuk Numpad)
          Expanded(
            child: itemsKeranjang.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 34,
                            color: t.textSecondary.withAlpha(110),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Belum ada pesanan\nKlik produk atau scan barcode',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: t.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: itemsKeranjang.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 5),
                    itemBuilder: (ctx, idx) {
                      final item = itemsKeranjang[idx];
                      return Dismissible(
                        key: ValueKey('cart_${item.produk.id}'),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) =>
                            widget.onUbahQty(item.produk.id, -item.qty),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 14),
                          decoration: BoxDecoration(
                            color: t.dangerColor,
                            borderRadius: BorderRadius.circular(t.radius - 2),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: t.inputColor,
                            borderRadius: BorderRadius.circular(t.radius - 2),
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
                                        Flexible(
                                          child: Text(
                                            item.produk.nama,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        if (item.dapatGrosir) ...[
                                          const SizedBox(width: 4),
                                          StatusBadge(
                                            label: 'GROSIR',
                                            color: t.successColor,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${formatRupiah(item.hargaSatuanAktif)} • ${formatRupiah(item.subtotal)}',
                                      style: gayaAngka(
                                        TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: t.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Tombol Kurang Kompak
                              InkWell(
                                onTap: () =>
                                    widget.onUbahQty(item.produk.id, -1),
                                borderRadius: BorderRadius.circular(5),
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: t.surfaceColor,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: t.borderColor),
                                  ),
                                  child: const Icon(Icons.remove, size: 15),
                                ),
                              ),
                              // Badge Qty Bisa Diketuk untuk Numpad
                              GestureDetector(
                                onTap: () => _dialogInputQty(item),
                                child: Container(
                                  constraints: const BoxConstraints(minWidth: 32),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: t.primaryColor.withAlpha(24),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: t.primaryColor.withAlpha(90),
                                    ),
                                  ),
                                  child: Text(
                                    '${item.qty}',
                                    style: gayaAngka(
                                      TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        color: t.primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Tombol Tambah Kompak
                              InkWell(
                                onTap: item.qty >= item.produk.stok
                                    ? null
                                    : () => widget.onUbahQty(item.produk.id, 1),
                                borderRadius: BorderRadius.circular(5),
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: t.surfaceColor,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: t.borderColor),
                                  ),
                                  child: const Icon(Icons.add, size: 15),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Dock Pembayaran Langsung (Metode Bayar + Nominal Cepat + Eksekusi)
          if (itemsKeranjang.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: t.inputColor,
                border: Border(top: BorderSide(color: t.borderColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pilih Metode Bayar Kompak
                  Row(
                    children: kMetodePembayaran.map((m) {
                      final aktif = _metodeBayar == m;
                      final labelPendek =
                          m == 'Transfer / Debit' ? 'Transfer' : m;
                      final warnaAktif =
                          m == 'Kasbon' ? t.warningColor : t.primaryColor;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _metodeBayar = m;
                              if (m == 'QRIS' || m == 'Transfer / Debit') {
                                _bayarCtrl.text = totalAkhir.toString();
                              } else if (m == 'Kasbon') {
                                _bayarCtrl.text = '0';
                                _opsiTambahanTerbuka = true;
                              } else {
                                _bayarCtrl.clear();
                              }
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: aktif ? warnaAktif : t.surfaceColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: aktif ? warnaAktif : t.borderColor,
                              ),
                            ),
                            child: Text(
                              labelPendek,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: aktif ? Colors.white : t.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),

                  // Tombol Nominal Cepat Tunai
                  if (_metodeBayar == 'Tunai')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _ChipNominalCepat(
                              tema: t,
                              label: 'Uang Pas',
                              highlight: true,
                              onTap: () => setState(
                                () => _bayarCtrl.text = totalAkhir.toString(),
                              ),
                            ),
                            ...pecahanCepat.map(
                              (nom) => Padding(
                                padding: const EdgeInsets.only(left: 5),
                                child: _ChipNominalCepat(
                                  tema: t,
                                  label: formatRupiah(nom).replaceAll('Rp ', ''),
                                  onTap: () => setState(
                                    () => _bayarCtrl.text = nom.toString(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Input Uang Diterima (Kecuali QRIS/Transfer yang otomatis pas)
                  if (!isNonTunaiOtomatis)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: _bayarCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        style: gayaAngka(
                          const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        decoration: InputDecoration(
                          labelText: isKasbon
                              ? 'DP / Uang Muka Kasbon'
                              : 'Uang Diterima (Tunai)',
                          prefixText: 'Rp ',
                          isDense: true,
                          filled: true,
                          fillColor: t.surfaceColor,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(t.radius),
                          ),
                        ),
                      ),
                    ),

                  // Ringkasan Angka Total & Kembalian
                  if (totalDiskon > 0 ||
                      potonganPoin > 0 ||
                      nominalPajak > 0 ||
                      nominalService > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Subtotal ${formatRupiah(subtotal)}${totalDiskon > 0 ? ' • Disc -${formatRupiah(totalDiskon)}' : ''}',
                            style: gayaAngka(
                              TextStyle(fontSize: 10.5, color: t.textSecondary),
                            ),
                          ),
                          if (nominalPajak + nominalService > 0)
                            Text(
                              '+Tax/Svc ${formatRupiah(nominalPajak + nominalService)}',
                              style: gayaAngka(
                                TextStyle(
                                  fontSize: 10.5,
                                  color: t.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        formatRupiah(totalAkhir),
                        style: gayaAngka(
                          TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: t.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isKasbon
                            ? 'Sisa Piutang'
                            : (selisih >= 0 ? 'Kembalian' : 'Kurang Bayar'),
                        style: TextStyle(fontSize: 11, color: t.textSecondary),
                      ),
                      Text(
                        formatRupiah(selisih.abs()),
                        style: gayaAngka(
                          TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isKasbon
                                ? t.warningColor
                                : (selisih >= 0
                                    ? t.successColor
                                    : t.dangerColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Tombol Eksekusi Final
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          isKasbon ? t.warningColor : t.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(t.radius),
                      ),
                    ),
                    onPressed: !validBayar
                        ? null
                        : () => _eksekusiPembayaran(
                              totalDiskon: totalDiskon,
                              nominalPajak: nominalPajak,
                              nominalService: nominalService,
                              nominalBayar: nominalBayar,
                              poinDipakai: poinDipakai,
                              poinDidapat: poinDidapat,
                            ),
                    icon: Icon(
                      isKasbon
                          ? Icons.receipt_long_rounded
                          : Icons.check_circle_rounded,
                      size: 19,
                    ),
                    label: Text(
                      isKasbon
                          ? 'SIMPAN PIUTANG KASBON'
                          : 'SELESAIKAN & CETAK STRUK',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChipNominalCepat extends StatelessWidget {
  final AppThemeConfig tema;
  final String label;
  final bool highlight;
  final VoidCallback onTap;

  const _ChipNominalCepat({
    required this.tema,
    required this.label,
    this.highlight = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: highlight
              ? tema.primaryColor.withAlpha(28)
              : tema.surfaceColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: highlight ? tema.primaryColor : tema.borderColor,
          ),
        ),
        child: Text(
          label,
          style: gayaAngka(
            TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: highlight ? tema.primaryColor : tema.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TombolKeypadQty extends StatelessWidget {
  final AppThemeConfig tema;
  final String? label;
  final IconData? icon;
  final bool isSecondary;
  final VoidCallback onTap;

  const _TombolKeypadQty({
    required this.tema,
    this.label,
    this.icon,
    this.isSecondary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TactilePress(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSecondary ? tema.bgColor : tema.inputColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tema.borderColor),
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, size: 18, color: tema.textSecondary)
            : Text(
                label ?? '',
                style: gayaAngka(
                  TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: tema.textPrimary,
                  ),
                ),
              ),
      ),
    );
  }
}


