import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../core/utils/pdf_clerek_report.dart';
import '../../models/clerek_model.dart';
import '../../models/sis_models.dart';
import '../../widgets/pos_components.dart';
import 'sis_audit_system_view.dart';
import 'sis_promo_crm_view.dart';
import 'sis_inventory_so_view.dart';

class StoreInformationSystemShell extends StatefulWidget {
  final AppThemeConfig tema;
  final PengaturanToko toko;
  final AkunStaff currentStaff;
  final List<AkunStaff> daftarStaff;
  final List<ShiftKasir> daftarShift;
  final List<Produk> daftarProduk;
  final List<LogStok> daftarLogStok;
  final List<MemberPelanggan> daftarMember;
  final List<PromoVoucher> daftarPromo;
  final List<TransaksiPos> daftarTransaksi;
  final List<PengeluaranToko> daftarPengeluaran;

  final void Function(Produk produk, bool isBaru) onSimpanProduk;
  final void Function(String produkId) onHapusProduk;
  final void Function({
    required Produk produk,
    required String tipe,
    required int perubahan,
    required String keterangan,
  }) onMutasiStok;

  final void Function(MemberPelanggan member, bool isBaru) onSimpanMember;
  final void Function(String id) onHapusMember;

  final void Function(PengeluaranToko item) onTambahPengeluaran;
  final void Function(String id) onHapusPengeluaran;

  final void Function(AkunStaff staff, bool isBaru) onSimpanStaff;
  final void Function(String id) onHapusStaff;

  final void Function(PromoVoucher promo, bool isBaru) onSimpanPromo;
  final void Function(String id) onHapusPromo;

  final void Function(PengaturanToko toko) onSimpanToko;
  final void Function(String temaId) onGantiTema;
  final void Function(String jsonStr) onRestoreJson;
  final void Function(TransaksiPos trx) onVoidTransaksi;
  final void Function(TransaksiPos trx, int nominalBayar) onBayarKasbon;
  final VoidCallback onKeluarAkun;

  const StoreInformationSystemShell({
    super.key,
    required this.tema,
    required this.toko,
    required this.currentStaff,
    required this.daftarStaff,
    required this.daftarShift,
    required this.daftarProduk,
    required this.daftarLogStok,
    required this.daftarMember,
    required this.daftarPromo,
    required this.daftarTransaksi,
    required this.daftarPengeluaran,
    required this.onSimpanProduk,
    required this.onHapusProduk,
    required this.onMutasiStok,
    required this.onSimpanMember,
    required this.onHapusMember,
    required this.onTambahPengeluaran,
    required this.onHapusPengeluaran,
    required this.onSimpanStaff,
    required this.onHapusStaff,
    required this.onSimpanPromo,
    required this.onHapusPromo,
    required this.onSimpanToko,
    required this.onGantiTema,
    required this.onRestoreJson,
    required this.onVoidTransaksi,
    required this.onBayarKasbon,
    required this.onKeluarAkun,
  });

  @override
  State<StoreInformationSystemShell> createState() =>
      _StoreInformationSystemShellState();
}

class _StoreInformationSystemShellState
    extends State<StoreInformationSystemShell> {
  static const String _keySupplier = 'sis_supplier_v1';
  static const String _keyExpired = 'sis_expired_batches_v1';

  int _navIndex = 0;

  // Sub-tab navigasi
  int _subDash = 0; // 0: Laba Rugi & KPI, 1: Dead Stock & Slow Moving
  // Filter & Pencarian
  String _periodeLaporan = 'Hari Ini';
  int _hariDeadStock = 30;
  final TextEditingController _cariSkuCtrl = TextEditingController();
  final TextEditingController _cariMemberCtrl = TextEditingController();
  final TextEditingController _cariStrukCtrl = TextEditingController();

  // Data Lanjutan SIS
  List<BatchKedaluwarsa> _daftarBatchEd = [];
  Map<String, LaporanClerekShift> _mapClerekZReport = {};

  @override
  void initState() {
    super.initState();
    _muatDataSisLanjutan();
  }

  @override
  void dispose() {
    _cariSkuCtrl.dispose();
    _cariMemberCtrl.dispose();
    _cariStrukCtrl.dispose();
    super.dispose();
  }

  Future<void> _muatDataSisLanjutan() async {
    final prefs = await SharedPreferences.getInstance();
    var suppliers = SupplierItem.decodeList(prefs.getString(_keySupplier));
    if (suppliers.isEmpty) {
      suppliers = [
        const SupplierItem(
          id: 'sup_default_1',
          nama: 'PT Distribusi Nusantara Makmur',
          kontak: 'Bpk. Hendra',
          telepon: '0812-8899-1122',
          alamat: 'Kawasan Industri Karawang Barat',
          leadTimeHari: 2,
          kategoriUtama: 'Makanan',
        ),
        const SupplierItem(
          id: 'sup_default_2',
          nama: 'CV Sumber Segar Jaya',
          kontak: 'Ibu Ratna',
          telepon: '0813-7766-4433',
          alamat: 'Jl. Tuparev No. 45, Karawang',
          leadTimeHari: 1,
          kategoriUtama: 'Minuman',
        ),
      ];
      await prefs.setString(_keySupplier, SupplierItem.encodeList(suppliers));
    }
    final eds = BatchKedaluwarsa.decodeList(prefs.getString(_keyExpired));
    final clerekMap = await ClerekStorageService.muatSemua();

    if (!mounted) return;
    setState(() {
      _daftarBatchEd = eds;
      _mapClerekZReport = clerekMap;
    });
  }

  

  

  

  

  

  void _info(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  

  // ==================== KALKULASI PERIODE ====================

  List<TransaksiPos> get _trxPeriode {
    final now = DateTime.now();
    return widget.daftarTransaksi.where((trx) {
      if (_periodeLaporan == 'Semua') return true;
      if (_periodeLaporan == 'Hari Ini') {
        return trx.tanggal.year == now.year &&
            trx.tanggal.month == now.month &&
            trx.tanggal.day == now.day;
      }
      final batas = _periodeLaporan == '7 Hari'
          ? now.subtract(const Duration(days: 7))
          : now.subtract(const Duration(days: 30));
      return trx.tanggal.isAfter(batas);
    }).toList();
  }

  List<PengeluaranToko> get _expPeriode {
    final now = DateTime.now();
    return widget.daftarPengeluaran.where((exp) {
      if (_periodeLaporan == 'Semua') return true;
      if (_periodeLaporan == 'Hari Ini') {
        return exp.tanggal.year == now.year &&
            exp.tanggal.month == now.month &&
            exp.tanggal.day == now.day;
      }
      final batas = _periodeLaporan == '7 Hari'
          ? now.subtract(const Duration(days: 7))
          : now.subtract(const Duration(days: 30));
      return exp.tanggal.isAfter(batas);
    }).toList();
  }

  // ==================== DIALOG MASTER SKU & LABEL ====================

  

  // ==================== DIALOG SUPPLIER & AUTO-DRAFT PO ====================

  

  

  

  // ==================== DIALOG RETUR & PEMUSNAHAN BAD STOCK ====================

  

  // ==================== DIALOG CATAT BATCH EXPIRED ====================

  

  // ==================== DIALOG KASBON, BIAYA, PROMO, MEMBER, STAFF ====================

  void _dialogBayarKasbonSis(TransaksiPos trx) {
    final t = widget.tema;
    final sisa = (trx.totalBelanja - trx.bayar).clamp(0, 999999999).toInt();
    final bayarCtrl = TextEditingController(text: sisa.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surfaceColor,
        title: Text(
          'Pelunasan Kasbon ${trx.nomorStruk}',
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pelanggan: ${trx.namaPelanggan}\nTotal Struk: ${formatRupiah(trx.totalBelanja)}\nSudah Dibayar: ${formatRupiah(trx.bayar)}\nSisa Tagihan: ${formatRupiah(sisa)}',
              style: gayaAngka(const TextStyle(fontSize: 12.5, height: 1.4)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bayarCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nominal Pembayaran Diterima',
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
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: t.successColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final nom =
                  int.tryParse(bayarCtrl.text.replaceAll('.', '')) ?? 0;
              if (nom <= 0) return;
              Navigator.pop(ctx);
              widget.onBayarKasbon(trx, nom);
              _info('Pembayaran kasbon sebesar ${formatRupiah(nom)} dicatat.');
            },
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('Posting Pembayaran'),
          ),
        ],
      ),
    );
  }

  void _dialogTambahPengeluaran() {
    final t = widget.tema;
    final judulCtrl = TextEditingController();
    final nomCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    String kategori = 'Listrik & Utilitas';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: t.surfaceColor,
          title: const Text(
            'Catat Biaya Operasional Toko',
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: judulCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Uraian Pengeluaran',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: kategori,
                  decoration: const InputDecoration(
                    labelText: 'Pos Biaya',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'Listrik & Utilitas',
                        child: Text('Listrik & Utilitas')),
                    DropdownMenuItem(
                        value: 'Perlengkapan Toko',
                        child: Text('Perlengkapan Toko / ATK')),
                    DropdownMenuItem(
                        value: 'Operasional & Transport',
                        child: Text('Operasional & Transport')),
                    DropdownMenuItem(
                        value: 'Perawatan & Kebersihan',
                        child: Text('Perawatan & Kebersihan')),
                    DropdownMenuItem(
                        value: 'Lain-lain', child: Text('Lain-lain')),
                  ],
                  onChanged: (v) =>
                      setDlg(() => kategori = v ?? 'Listrik & Utilitas'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nomCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nominal Biaya',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: catCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Catatan / No. Kwitansi',
                    border: OutlineInputBorder(),
                  ),
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
              onPressed: () {
                final judul = judulCtrl.text.trim();
                final nom =
                    int.tryParse(nomCtrl.text.replaceAll('.', '')) ?? 0;
                if (judul.isEmpty || nom <= 0) return;

                Navigator.pop(ctx);
                widget.onTambahPengeluaran(
                  PengeluaranToko(
                    id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
                    judul: judul,
                    kategori: kategori,
                    nominal: nom,
                    ambilDariLaciKas: false,
                    olehStaff: widget.currentStaff.nama,
                    tanggal: DateTime.now(),
                    catatan: catCtrl.text.trim(),
                  ),
                );
                _info('Biaya operasional berhasil dibukukan.');
              },
              child: const Text('Simpan Biaya'),
            ),
          ],
        ),
      ),
    );
  }

  void _dialogFormPromo({
    PromoVoucher? editPromo,
    String? presetKode,
    String? presetNama,
  }) {
    final t = widget.tema;
    final isBaru = editPromo == null;
    final kodeCtrl =
        TextEditingController(text: editPromo?.kode ?? presetKode ?? '');
    final namaCtrl =
        TextEditingController(text: editPromo?.nama ?? presetNama ?? '');
    final nilaiCtrl = TextEditingController(
      text: editPromo != null
          ? editPromo.nilai.toString()
          : (presetKode != null ? '20' : ''),
    );
    final minCtrl = TextEditingController(
      text: editPromo != null ? editPromo.minBelanja.toString() : '0',
    );
    bool isPersen = editPromo?.isPersen ?? true;
    bool aktif = editPromo?.aktif ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: t.surfaceColor,
          title: Text(
            isBaru ? 'Buat Promo / Voucher Baru' : 'Edit Promo / Voucher',
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: kodeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Kode Voucher',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: namaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Program Promosi',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Persen (%)')),
                    ButtonSegment(value: false, label: Text('Nominal (Rp)')),
                  ],
                  selected: {isPersen},
                  onSelectionChanged: (v) =>
                      setDlg(() => isPersen = v.first),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nilaiCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText:
                        isPersen ? 'Besar Diskon (%)' : 'Nominal Potongan (Rp)',
                    prefixText: isPersen ? null : 'Rp ',
                    suffixText: isPersen ? '%' : null,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: minCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minimum Belanja (Rp)',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Status Voucher Aktif',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  value: aktif,
                  onChanged: (v) => setDlg(() => aktif = v),
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
              onPressed: () {
                final kode = kodeCtrl.text.trim().toUpperCase();
                final nama = namaCtrl.text.trim();
                final nilai =
                    int.tryParse(nilaiCtrl.text.replaceAll('.', '')) ?? 0;
                final minBel =
                    int.tryParse(minCtrl.text.replaceAll('.', '')) ?? 0;
                if (kode.isEmpty || nama.isEmpty || nilai <= 0) return;

                Navigator.pop(ctx);
                widget.onSimpanPromo(
                  PromoVoucher(
                    id: editPromo?.id ??
                        'prm_${DateTime.now().millisecondsSinceEpoch}',
                    kode: kode,
                    nama: nama,
                    isPersen: isPersen,
                    nilai: nilai,
                    minBelanja: minBel,
                    aktif: aktif,
                  ),
                  isBaru,
                );
                _info('Program promosi berhasil disimpan.');
              },
              child: const Text('Simpan Promo'),
            ),
          ],
        ),
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
          isBaru ? 'Registrasi Member Baru' : 'Edit Data Member',
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: namaCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap Pelanggan',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: telpCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Nomor HP / WhatsApp',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: poinCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Saldo Poin Loyalty',
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
              backgroundColor: t.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final nama = namaCtrl.text.trim();
              final telp = telpCtrl.text.trim();
              if (nama.isEmpty) return;
              Navigator.pop(ctx);
              widget.onSimpanMember(
                MemberPelanggan(
                  id: editMember?.id ??
                      'mbr_${DateTime.now().millisecondsSinceEpoch}',
                  nama: nama,
                  telepon: telp,
                  poin: int.tryParse(poinCtrl.text) ?? 0,
                  totalBelanja: editMember?.totalBelanja ?? 0,
                  jumlahKunjungan: editMember?.jumlahKunjungan ?? 0,
                ),
                isBaru,
              );
              _info('Data member berhasil disimpan.');
            },
            child: const Text('Simpan Member'),
          ),
        ],
      ),
    );
  }

  void _dialogFormStaff({AkunStaff? editStaff}) {
    final t = widget.tema;
    final isBaru = editStaff == null;
    final namaCtrl = TextEditingController(text: editStaff?.nama ?? '');
    final pinCtrl = TextEditingController(text: editStaff?.pin ?? '');
    RoleStaff role = editStaff?.role ?? RoleStaff.kasir;
    bool aktif = editStaff?.aktif ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: t.surfaceColor,
          title: Text(
            isBaru ? 'Tambah Akun Operator' : 'Edit Akun Operator',
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: namaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap Operator',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pinCtrl,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'PIN Akses (4 Digit)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<RoleStaff>(
                  value: role,
                  decoration: const InputDecoration(
                    labelText: 'Hak Akses Sistem',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: RoleStaff.storeSystem,
                      child: Text('Store Information System (Back-Office)'),
                    ),
                    DropdownMenuItem(
                      value: RoleStaff.kasir,
                      child: Text('Kasir POS (Terminal Transaksi)'),
                    ),
                  ],
                  onChanged: (v) =>
                      setDlg(() => role = v ?? RoleStaff.kasir),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Status Akun Aktif',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  value: aktif,
                  onChanged: (v) => setDlg(() => aktif = v),
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
              onPressed: () {
                final nama = namaCtrl.text.trim();
                final pin = pinCtrl.text.trim();
                if (nama.isEmpty || pin.length != 4) return;

                Navigator.pop(ctx);
                widget.onSimpanStaff(
                  AkunStaff(
                    id: editStaff?.id ??
                        'stf_${DateTime.now().millisecondsSinceEpoch}',
                    nama: nama,
                    pin: pin,
                    role: role,
                    aktif: aktif,
                  ),
                  isBaru,
                );
                _info('Akun operator berhasil diperbarui.');
              },
              child: const Text('Simpan Akun'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== BUILD SHELL UTAMA ====================

  @override
  Widget build(BuildContext context) {
    final t = widget.tema;
    final jumlahEdKritis =
        _daftarBatchEd.where((b) => b.sudahExpired || b.kritis7Hari).length;
    final jumlahKasbon =
        widget.daftarTransaksi.where((e) => !e.statusLunas).length;

    return Scaffold(
      backgroundColor: t.bgColor,
      appBar: AppBar(
        backgroundColor: t.surfaceColor,
        elevation: 0,
        titleSpacing: 14,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: t.primaryColor,
                borderRadius: BorderRadius.circular(t.radius),
              ),
              child: const Icon(
                Icons.dns_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.toko.namaToko,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'STORE INFORMATION SYSTEM • ${widget.currentStaff.nama}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: t.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: t.primaryColor.withAlpha(22),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: t.primaryColor.withAlpha(90)),
            ),
            child: Text(
              'BACK-OFFICE',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: t.primaryColor,
                letterSpacing: 0.4,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Keluar / Ganti Operator',
            onPressed: widget.onKeluarAkun,
            icon: Icon(Icons.logout_rounded, color: t.dangerColor, size: 21),
          ),
        ],
      ),
      body: IndexedStack(
        index: _navIndex,
        children: [
          _buildDashboardTab(t),
          SisInventorySoView(
            tema: t,
            daftarProduk: widget.daftarProduk,
            daftarLogStok: widget.daftarLogStok,
            onSimpanProduk: widget.onSimpanProduk,
            onHapusProduk: widget.onHapusProduk,
            onMutasiStok: widget.onMutasiStok,
          ),
          SisPromoCrmView(
            tema: t,
            daftarPromo: widget.daftarPromo,
            daftarMember: widget.daftarMember,
            daftarTransaksi: widget.daftarTransaksi,
            onBukaFormPromo: ({editPromo}) => _dialogFormPromo(editPromo: editPromo),
            onSimpanPromo: widget.onSimpanPromo,
            onHapusPromo: widget.onHapusPromo,
            onBukaFormMember: ({editMember}) => _dialogFormMember(editMember: editMember),
            onHapusMember: widget.onHapusMember,
            onBayarKasbon: _dialogBayarKasbonSis,
          ),
          SisAuditSystemView(
            tema: t,
            toko: widget.toko,
            currentStaff: widget.currentStaff,
            daftarStaff: widget.daftarStaff,
            daftarShift: widget.daftarShift,
            daftarTransaksi: widget.daftarTransaksi,
            mapClerekZReport: _mapClerekZReport,
            onLihatStruk: (trx) => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: t.surfaceColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text('Struk ${trx.nomorStruk}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                content: Text('${trx.namaKasir} • ${formatRupiah(trx.totalBelanja)}'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
                ],
              ),
            ),
            onVoidTransaksi: widget.onVoidTransaksi,
            onBukaClerekBlind: (sh, draft) async {
              final tunaiCtrl = TextEditingController(text: '0');
              final qrisCtrl = TextEditingController(text: '0');
              final edcCtrl = TextEditingController(text: '0');
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  backgroundColor: t.surfaceColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text('Blind Clerek • ${draft.nomorClerek}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: tunaiCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Total Fisik Tunai (Rp)'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: qrisCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Settlement QRIS (Rp)'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: edcCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Settlement EDC / Transfer (Rp)'),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: t.primaryColor, foregroundColor: Colors.white),
                      onPressed: () async {
                        int pInt(TextEditingController c) =>
                            int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                        final locked = LaporanClerekShift(
                          shiftId: draft.shiftId,
                          nomorClerek: draft.nomorClerek,
                          namaKasir: draft.namaKasir,
                          namaOtorisasiTutup: draft.namaOtorisasiTutup,
                          namaPejabatRekonsiliasi: widget.currentStaff.nama,
                          waktuBuka: draft.waktuBuka,
                          waktuClerek: draft.waktuClerek,
                          waktuRekonsiliasi: DateTime.now(),
                          statusClerek: 'TERKUNCI_Z_REPORT',
                          totalFisikTunai: pInt(tunaiCtrl),
                          modalDitinggalLaci: draft.modalDitinggalLaci,
                          fisikSettlementQris: pInt(qrisCtrl),
                          fisikSettlementEdcTransfer: pInt(edcCtrl),
                          fisikNotaKasbon: draft.fisikNotaKasbon,
                          catatanRekonsiliasi: draft.catatanRekonsiliasi,
                          modalAwalSistem: draft.modalAwalSistem,
                          penjualanTunaiSistem: draft.penjualanTunaiSistem,
                          penjualanNonTunaiSistem: draft.penjualanNonTunaiSistem,
                          pengeluaranLaciSistem: draft.pengeluaranLaciSistem,
                          kasbonBaruSistem: draft.kasbonBaruSistem,
                          jumlahStrukSukses: draft.jumlahStrukSukses,
                          totalItemTerjual: draft.totalItemTerjual,
                        );
                        setState(() => _mapClerekZReport[sh.id] = locked);
                        await ClerekStorageService.simpan(locked);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Kunci Z-Report'),
                    ),
                  ],
                ),
              );
            },
            onLihatZReport: (z) => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: t.surfaceColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text('Z-Report ${z.nomorClerek}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                content: Text('Kasir: ${z.namaKasir}\nSelisih Tunai: ${formatRupiah(z.selisihTunai)}'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
                ],
              ),
            ),
            onUnduhPdfClerek: (z) async {
              final bytes = await generatePdfLaporanClerek(laporan: z, toko: widget.toko);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('PDF ${z.nomorClerek} siap (${bytes.length} bytes)')),
                );
              }
            },
            onBukaFormStaff: ({editStaff}) => _dialogFormStaff(editStaff: editStaff),
            onHapusStaff: widget.onHapusStaff,
            onSimpanToko: widget.onSimpanToko,
            onGantiTema: widget.onGantiTema,
            onRestoreJson: widget.onRestoreJson,
            onExportJson: () {
              return jsonEncode({
                'toko': widget.toko.toMap(),
                'staff': widget.daftarStaff.map((e) => e.toMap()).toList(),
                'shift': widget.daftarShift.map((e) => e.toMap()).toList(),
                'produk': widget.daftarProduk.map((e) => e.toMap()).toList(),
                'logStok': widget.daftarLogStok.map((e) => e.toMap()).toList(),
                'transaksi': widget.daftarTransaksi.map((e) => e.toMap()).toList(),
                'pengeluaran': widget.daftarPengeluaran.map((e) => e.toMap()).toList(),
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        backgroundColor: t.surfaceColor,
        indicatorColor: t.primaryColor.withAlpha(32),
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: jumlahEdKritis > 0,
              label: Text('$jumlahEdKritis'),
              child: const Icon(Icons.inventory_2_outlined),
            ),
            selectedIcon: const Icon(Icons.inventory_2_rounded),
            label: 'Inventory & SO',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: jumlahKasbon > 0,
              label: Text('$jumlahKasbon'),
              child: const Icon(Icons.local_offer_outlined),
            ),
            selectedIcon: const Icon(Icons.local_offer_rounded),
            label: 'Promo & CRM',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_applications_outlined),
            selectedIcon: Icon(Icons.settings_applications_rounded),
            label: 'Audit & Sistem',
          ),
        ],
      ),
    );
  }

  // ==================== TAB 1: DASHBOARD & DEAD STOCK ====================

  Widget _buildDashboardTab(AppThemeConfig t) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Laba Rugi & KPI')),
              ButtonSegment(value: 1, label: Text('Dead Stock & Slow Moving')),
            ],
            selected: {_subDash},
            onSelectionChanged: (v) => setState(() => _subDash = v.first),
          ),
        ),
        Expanded(
          child: _subDash == 0
              ? _buildSubLabaRugi(t)
              : _buildSubDeadStock(t),
        ),
      ],
    );
  }

  Widget _buildSubLabaRugi(AppThemeConfig t) {
    final trxList = _trxPeriode;
    final expList = _expPeriode;

    final omzet = trxList.fold<int>(0, (s, e) => s + e.totalBelanja);
    final labaKotor = trxList.fold<int>(0, (s, e) => s + e.estimasiLabaKotor);
    final totalHpp = trxList.fold<int>(
      0,
      (s, e) =>
          s +
          e.items.fold<int>(0, (si, item) => si + (item.hargaModal * item.qty)),
    );
    final totalBiaya = expList.fold<int>(0, (s, e) => s + e.nominal);
    final labaBersih = labaKotor - totalBiaya;
    final marginPersen = omzet > 0 ? (labaKotor / omzet) * 100 : 0.0;
    final avgBasket = trxList.isEmpty ? 0 : (omzet ~/ trxList.length);

    final nilaiAsetHpp = widget.daftarProduk
        .fold<int>(0, (s, p) => s + (p.hargaModal * p.stok));
    final nilaiAsetJual = widget.daftarProduk
        .fold<int>(0, (s, p) => s + (p.hargaJual * p.stok));
    final stokMenipisCount = widget.daftarProduk
        .where((p) => p.stok <= p.minStokAlert)
        .length;
    final totalKasbon = widget.daftarTransaksi
        .where((e) => !e.statusLunas)
        .fold<int>(
            0,
            (s, e) =>
                s + (e.totalBelanja - e.bayar).clamp(0, 999999999).toInt());

    final mapProdukQty = <String, int>{};
    final mapProdukOmzet = <String, int>{};
    final mapKasirOmzet = <String, int>{};
    final mapKasirTrx = <String, int>{};

    for (final trx in trxList) {
      mapKasirOmzet[trx.namaKasir] =
          (mapKasirOmzet[trx.namaKasir] ?? 0) + trx.totalBelanja;
      mapKasirTrx[trx.namaKasir] = (mapKasirTrx[trx.namaKasir] ?? 0) + 1;
      for (final item in trx.items) {
        mapProdukQty[item.namaProduk] =
            (mapProdukQty[item.namaProduk] ?? 0) + item.qty;
        mapProdukOmzet[item.namaProduk] =
            (mapProdukOmzet[item.namaProduk] ?? 0) +
                (item.hargaJual * item.qty);
      }
    }

    final topSku = mapProdukQty.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topKasir = mapKasirOmzet.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Hari Ini', '7 Hari', '30 Hari', 'Semua'].map((p) {
                    final aktif = _periodeLaporan == p;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(p, style: const TextStyle(fontSize: 11.5)),
                        selected: aktif,
                        onSelected: (_) =>
                            setState(() => _periodeLaporan = p),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final csv = buatCsvLaporan(trxList);
                await Clipboard.setData(ClipboardData(text: csv));
                _info('Laporan CSV (${trxList.length} transaksi) disalin.');
              },
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('CSV', style: TextStyle(fontSize: 11.5)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                tema: t,
                label: 'Omzet Penjualan',
                value: formatRupiah(omzet),
                sublabel:
                    '${trxList.length} struk • ATV ${formatRupiah(avgBasket)}',
                valueColor: t.primaryColor,
                icon: Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricTile(
                tema: t,
                label: 'Laba Kotor (Gross)',
                value: formatRupiah(labaKotor),
                sublabel:
                    'Margin ${marginPersen.toStringAsFixed(1)}% • HPP ${formatRupiah(totalHpp)}',
                valueColor: t.successColor,
                icon: Icons.trending_up_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                tema: t,
                label: 'Biaya Operasional',
                value: formatRupiah(totalBiaya),
                sublabel: '${expList.length} pos pengeluaran',
                valueColor: t.warningColor,
                icon: Icons.receipt_long_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricTile(
                tema: t,
                label: 'Laba Bersih (Net)',
                value: formatRupiah(labaBersih),
                sublabel: 'Gross Profit - Biaya',
                valueColor:
                    labaBersih >= 0 ? t.successColor : t.dangerColor,
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                tema: t,
                label: 'Valuasi Inventaris',
                value: formatRupiah(nilaiAsetHpp),
                sublabel: 'Potensi jual ${formatRupiah(nilaiAsetJual)}',
                valueColor: t.accentColor,
                icon: Icons.warehouse_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricTile(
                tema: t,
                label: 'Piutang Kasbon',
                value: formatRupiah(totalKasbon),
                sublabel: '$stokMenipisCount SKU stok kritis',
                valueColor:
                    totalKasbon > 0 ? t.dangerColor : t.textSecondary,
                icon: Icons.warning_amber_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const SectionHeader(
          title: 'Top Produk Terlaris',
          subtitle: 'Peringkat pergerakan barang berdasarkan volume terjual',
        ),
        const SizedBox(height: 8),
        if (topSku.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: dekorasiKartu(t),
            child: Text(
              'Belum ada penjualan pada periode ini.',
              style: TextStyle(fontSize: 12, color: t.textSecondary),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: dekorasiKartu(t),
            child: Column(
              children: List.generate(topSku.take(5).length, (i) {
                final entry = topSku[i];
                final omzSku = mapProdukOmzet[entry.key] ?? 0;
                return Padding(
                  padding: EdgeInsets.only(bottom: i == 4 ? 0 : 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 13,
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
                        child: Text(
                          entry.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      Text(
                        '${entry.value} unit • ${formatRupiah(omzSku)}',
                        style: gayaAngka(
                          TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: t.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        if (topKasir.isNotEmpty) ...[
          const SizedBox(height: 14),
          const SectionHeader(
            title: 'Kinerja Terminal Kasir',
            subtitle: 'Kontribusi omzet per operator kasir',
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: dekorasiKartu(t),
            child: Column(
              children: topKasir.map((e) {
                final jmlStruk = mapKasirTrx[e.key] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${e.key} ($jmlStruk struk)',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        formatRupiah(e.value),
                        style: gayaAngka(
                          TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: t.successColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: SectionHeader(
                title: 'Buku Pengeluaran Operasional',
                subtitle: 'Biaya non-HPP untuk kalkulasi laba bersih',
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: t.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: _dialogTambahPengeluaran,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Biaya', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (expList.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: dekorasiKartu(t),
            child: Text(
              'Belum ada catatan biaya operasional pada periode ini.',
              style: TextStyle(fontSize: 12, color: t.textSecondary),
            ),
          )
        else
          ...expList.map(
            (exp) => Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.all(11),
              decoration: dekorasiKartu(t),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exp.judul,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${exp.kategori} • ${formatTanggalWaktu(exp.tanggal)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: t.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '-${formatRupiah(exp.nominal)}',
                    style: gayaAngka(
                      TextStyle(
                        fontWeight: FontWeight.w800,
                        color: t.dangerColor,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => widget.onHapusPengeluaran(exp.id),
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: t.dangerColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSubDeadStock(AppThemeConfig t) {
    final batas = DateTime.now().subtract(Duration(days: _hariDeadStock));
    final terjualPeriode = <String, int>{};
    for (final trx in widget.daftarTransaksi) {
      if (trx.tanggal.isAfter(batas)) {
        for (final it in trx.items) {
          terjualPeriode[it.produkId] =
              (terjualPeriode[it.produkId] ?? 0) + it.qty;
        }
      }
    }

    final deadList = widget.daftarProduk.where((p) {
      final sold = terjualPeriode[p.id] ?? 0;
      return p.stok > 0 && sold == 0;
    }).toList();

    final slowList = widget.daftarProduk.where((p) {
      final sold = terjualPeriode[p.id] ?? 0;
      return p.stok > 0 && sold > 0 && sold <= 2;
    }).toList();

    final modalDead =
        deadList.fold<int>(0, (s, p) => s + (p.hargaModal * p.stok));
    final modalSlow =
        slowList.fold<int>(0, (s, p) => s + (p.hargaModal * p.stok));

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
      children: [
        Row(
          children: [
            const Text(
              'Rentang Evaluasi:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('30 Hari', style: TextStyle(fontSize: 11.5)),
              selected: _hariDeadStock == 30,
              onSelected: (_) => setState(() => _hariDeadStock = 30),
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              label: const Text('60 Hari', style: TextStyle(fontSize: 11.5)),
              selected: _hariDeadStock == 60,
              onSelected: (_) => setState(() => _hariDeadStock = 60),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                tema: t,
                label: 'Dead Stock (0 Terjual)',
                value: '${deadList.length} SKU',
                sublabel: 'Modal mengendap ${formatRupiah(modalDead)}',
                valueColor:
                    deadList.isNotEmpty ? t.dangerColor : t.successColor,
                icon: Icons.hourglass_disabled_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricTile(
                tema: t,
                label: 'Slow Moving (1-2 Unit)',
                value: '${slowList.length} SKU',
                sublabel: 'Modal ${formatRupiah(modalSlow)}',
                valueColor: t.warningColor,
                icon: Icons.trending_down_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SectionHeader(
          title: 'Daftar Produk Dead Stock (${deadList.length} SKU)',
          subtitle: 'Tidak ada penjualan sama sekali dalam $_hariDeadStock hari terakhir',
        ),
        const SizedBox(height: 8),
        if (deadList.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: dekorasiKartu(t),
            child: Text(
              'Tidak ada produk dead stock pada rentang $_hariDeadStock hari terakhir.',
              style: TextStyle(fontSize: 12, color: t.textSecondary),
            ),
          )
        else
          ...deadList.map((p) {
            final modalMengendap = p.hargaModal * p.stok;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
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
                            StatusBadge(
                              label: 'DEAD STOCK',
                              color: t.dangerColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${p.stok} ${p.satuan}',
                              style: gayaAngka(
                                const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.nama,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Modal Mengendap: ${formatRupiah(modalMengendap)} • Jual: ${formatRupiah(p.hargaJual)}',
                          style: gayaAngka(
                            TextStyle(fontSize: 11, color: t.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () {
                      final kodeSaran =
                          'CUCI${p.kodeSku.length >= 3 ? p.kodeSku.substring(p.kodeSku.length - 3) : '20'}';
                      _dialogFormPromo(
                        presetKode: kodeSaran,
                        presetNama: 'Cuci Gudang ${p.nama}',
                      );
                    },
                    child: const Text(
                      'Buat Promo',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            );
          }),
        if (slowList.isNotEmpty) ...[
          const SizedBox(height: 14),
          SectionHeader(
            title: 'Produk Slow Moving (${slowList.length} SKU)',
            subtitle: 'Perputaran lambat (terjual 1 - 2 unit)',
          ),
          const SizedBox(height: 8),
          ...slowList.map((p) {
            final sold = terjualPeriode[p.id] ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.all(11),
              decoration: dekorasiKartu(t),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nama,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Stok: ${p.stok} ${p.satuan} • Terjual: $sold unit',
                          style: gayaAngka(
                            TextStyle(fontSize: 11, color: t.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: 'HPP ${formatRupiah(p.hargaModal * p.stok)}',
                    color: t.warningColor,
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  // ==================== TAB 2: MERCHANDISING & GUDANG ====================

  

  

  

  

  

  // ==================== TAB 3: PROMO, CRM & BUKU KASBON ====================

  // ==================== TAB 4: AUDIT, SDM & SISTEM ====================

}

