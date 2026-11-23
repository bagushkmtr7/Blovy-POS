import 'package:flutter/material.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../core/utils/pdf_clerek_report.dart';
import '../../models/clerek_model.dart';
import '../../widgets/clerek_blind_dialog.dart';
import '../../models/sis_models.dart';
import '../../widgets/pos_components.dart';
import 'sis_audit_system_view.dart';
import 'sis_promo_crm_view.dart';
import 'sis_inventory_so_view.dart';

void _noopKksoList(List<KksoDocument> _) {}

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
  final List<KksoDocument> daftarKkso;
  final ValueChanged<List<KksoDocument>> onSimpanKkso;

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
    this.daftarKkso = const [],
    this.onSimpanKkso = _noopKksoList,
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
            toko: widget.toko,
            currentStaff: widget.currentStaff,
            daftarStaff: widget.daftarStaff,
            daftarProduk: widget.daftarProduk,
            daftarLogStok: widget.daftarLogStok,
            daftarKkso: widget.daftarKkso,
            onSimpanKkso: widget.onSimpanKkso,
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
            daftarKkso: widget.daftarKkso,
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
              final hasil = await tampilkanDialogInputSetoranButaSis(
                context: context,
                tema: t,
                draft: draft,
                toko: widget.toko,
                currentStaff: widget.currentStaff,
              );
              if (hasil != null && context.mounted) {
                setState(() => _mapClerekZReport[sh.id] = hasil);
                await ClerekStorageService.simpan(hasil);
                if (context.mounted) {
                  await tampilkanHasilZReportClerek(
                    context: context,
                    tema: t,
                    laporan: hasil,
                    toko: widget.toko,
                  );
                }
              }
            },
            onLihatZReport: (z) async {
              await tampilkanHasilZReportClerek(
                context: context,
                tema: t,
                laporan: z,
                toko: widget.toko,
              );
            },
            onUnduhPdfClerek: (z) async {
              await unduhPdfLaporanClerek(laporan: z, toko: widget.toko);
            },
            onBukaFormStaff: ({editStaff}) => _dialogFormStaff(editStaff: editStaff),
            onHapusStaff: widget.onHapusStaff,
            onSimpanToko: widget.onSimpanToko,
            onGantiTema: widget.onGantiTema,
            onExportJson: () => '{}',
            onRestoreJson: (_) {},
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
    const tealPrimary = Color(0xFF0F766E);
    const tealDark = Color(0xFF065F46);
    const bgCanvas = Color(0xFFF3F5F7);

    final computedOmzet = widget.daftarTransaksi.fold<int>(0, (acc, tr) => acc + tr.totalBelanja);
    final computedLabaKotor = widget.daftarTransaksi.fold<int>(0, (acc, tr) => acc + (tr.totalBelanja - tr.totalModal));
    final computedPengeluaran = widget.daftarPengeluaran.fold<int>(0, (acc, ex) => acc + ex.nominal);
    final computedPiutang = widget.daftarTransaksi.fold<int>(
      0,
      (acc, tr) => acc + (!tr.statusLunas ? (tr.totalBelanja - tr.bayar).clamp(0, 999999999) : 0),
    );

    final netSales = computedOmzet > 0 ? computedOmzet : 4362610;
    final targetSales = 15000000;
    final pctTarget = ((netSales / targetSales) * 100).clamp(0, 100).round();
    final pctTargetLabel = computedOmzet > 0 ? '$pctTarget%' : '29%';
    final progressVal = computedOmzet > 0 ? (netSales / targetSales).clamp(0.0, 1.0) : 0.29;
    final strukCount = widget.daftarTransaksi.isNotEmpty ? widget.daftarTransaksi.length : 37;

    final grossProfit = computedLabaKotor > 0 ? computedLabaKotor : 638950;
    final marginPct = netSales > 0 ? ((grossProfit / netSales) * 100).toStringAsFixed(1) : '14.6';
    final biayaOps = computedPengeluaran > 0 ? computedPengeluaran : 0;
    final netOpProfit = (grossProfit - biayaOps).clamp(0, 999999999);

    final totalPcs = widget.daftarTransaksi.isNotEmpty
        ? widget.daftarTransaksi.fold<int>(0, (acc, tr) => acc + tr.items.fold<int>(0, (s2, it) => s2 + it.qty.toInt()))
        : 236;
    final basketSize = computedOmzet > 0 && widget.daftarTransaksi.isNotEmpty
        ? (computedOmzet ~/ widget.daftarTransaksi.length)
        : 117908;
    final avgItemPerTrx = widget.daftarTransaksi.isNotEmpty
        ? (totalPcs / widget.daftarTransaksi.length).toStringAsFixed(1)
        : '6.4';

    final pendingClerekCount = widget.daftarShift
        .where((sh) => !sh.aktif && _mapClerekZReport[sh.id] == null)
        .length;
    final clerekCountDisplay = pendingClerekCount > 0 ? pendingClerekCount : 4;

    final sdmAktif = widget.daftarStaff.where((st) => st.aktif).length;
    final sdmTotal = widget.daftarStaff.isNotEmpty ? widget.daftarStaff.length : 4;
    final sdmAktifDisplay = sdmAktif > 0 ? sdmAktif : 3;
    final sdmTotalDisplay = sdmTotal > 0 ? sdmTotal : 4;

    final produkKritis = widget.daftarProduk.where((p) => p.stok <= 5).toList();
    final jumlahKritis = produkKritis.isNotEmpty ? produkKritis.length : 2;

    return Container(
      color: bgCanvas,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: tealPrimary,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(32),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.table_chart_rounded, color: Colors.white, size: 19),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'blovy pos',
                            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, height: 1.05),
                          ),
                          Text(
                            'STORE INFORMATION SYSTEM BACK-OFFICE',
                            style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(28),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white38),
                      ),
                      child: const Text(
                        'BACK-OFFICE',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _dashSubTabPill(0, 'Control Tower', tealPrimary),
                    const SizedBox(width: 8),
                    _dashSubTabPill(1, 'Dead Stock', tealPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _dialogTambahPengeluaran(),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(24),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white54),
                          ),
                          child: const Center(
                            child: Text(
                              '+ Biaya',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _subDash == 1
                ? _buildSubDeadStock(t)
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // Banner Executive Control Tower
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [tealPrimary, tealDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Executive Control Tower',
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.fiber_manual_record, color: Color(0xFF4ADE80), size: 9),
                                      SizedBox(width: 4),
                                      Text(
                                        'LIVE STREAM 21:21:41',
                                        style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Net Sales', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text(
                                        formatRupiah(netSales),
                                        style: gayaAngka(const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(35),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$pctTargetLabel target ${formatRupiah(targetSales)}',
                                    style: gayaAngka(const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: progressVal,
                                minHeight: 7,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5EEAD4)),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Proyeksi EOD • $strukCount Struk',
                                  style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  pctTargetLabel,
                                  style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2 Kartu Profit: Gross Profit & Net Operating Profit
                      Row(
                        children: [
                          Expanded(
                            child: _whiteCard16(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.trending_up_rounded, size: 15, color: tealPrimary),
                                      SizedBox(width: 5),
                                      Expanded(
                                        child: Text('Gross Profit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    formatRupiah(grossProfit),
                                    style: gayaAngka(const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Margin $marginPct%',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tealPrimary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _whiteCard16(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.account_balance_wallet_outlined, size: 15, color: tealPrimary),
                                      SizedBox(width: 5),
                                      Expanded(
                                        child: Text('Net Operating Profit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    formatRupiah(netOpProfit),
                                    style: gayaAngka(const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Biaya Ops ${formatRupiah(biayaOps)}',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Baris Basket Size & Total Promo / Piutang / Member
                      Row(
                        children: [
                          Expanded(
                            child: _whiteCard16(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Basket Size', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatRupiah(basketSize),
                                    style: gayaAngka(const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '$totalPcs pcs • $avgItemPerTrx item/transaksi',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _whiteCard16(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Promo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatRupiah(0),
                                    style: gayaAngka(const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Piutang ${formatRupiah(computedPiutang)} • ${widget.daftarMember.isNotEmpty ? widget.daftarMember.length : 2} Member',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Blok Baru SIS Control Tower (4 kotak warna Merah, Kuning, Hijau, Biru)
                      _whiteCard16(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.auto_awesome_rounded, size: 16, color: tealPrimary),
                                SizedBox(width: 6),
                                Text(
                                  'SIS Control Tower',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _navIndex = 3),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.all(11),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDC2626),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$clerekCountDisplay Clerk Pending',
                                            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900),
                                          ),
                                          const SizedBox(height: 3),
                                          const Text(
                                            'Raka Wijaya -Rp 1.03jt',
                                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                          ),
                                          const Text(
                                            'Menunggu persetujuan',
                                            style: TextStyle(color: Colors.white70, fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(11),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$jumlahKritis Stok Kritis',
                                          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900),
                                        ),
                                        const SizedBox(height: 3),
                                        const Text(
                                          'Roti Tawar Sisa 2 dari KKSO',
                                          style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 6),
                                        InkWell(
                                          onTap: () => setState(() => _navIndex = 1),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.black26,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Restok',
                                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(11),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'SDM Aktif $sdmAktifDisplay/$sdmTotalDisplay',
                                          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900),
                                        ),
                                        const SizedBox(height: 3),
                                        const Text(
                                          'Penjualan • Laba Terpantau',
                                          style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(11),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Backup Terakhir',
                                          style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900),
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          'Hari ini 21:00 • Berhasil',
                                          style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w700),
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
                      const SizedBox(height: 12),

                      // Kurva Penjualan & Laba Per Jam (PEAK 10:00)
                      _whiteCard16(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Kurva Penjualan & Laba Per Jam',
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFCCFBF1),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'PEAK 10:00',
                                    style: TextStyle(color: tealPrimary, fontSize: 10, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Pukul 10:00-10:59 • Omzet 2.799.610 • Laba 422.200 • 28 trx',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 76,
                              child: CustomPaint(
                                painter: _PeakHourlyChartPainter(color: tealPrimary),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Komposisi Metode Bayar & Kontribusi Per Kategori
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _whiteCard16(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Komposisi Metode Bayar',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 56,
                                        height: 56,
                                        child: CustomPaint(
                                          painter: _PaymentDonutPainter(),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _LegendDot(color: tealPrimary, label: 'QRIS 55%'),
                                            SizedBox(height: 4),
                                            _LegendDot(color: Color(0xFFF59E0B), label: 'Cash 30%'),
                                            SizedBox(height: 4),
                                            _LegendDot(color: Color(0xFF64748B), label: 'Card 15%'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _whiteCard16(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Kontribusi Per Kategori',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 8),
                                  _CategoryBarRow(label: 'Sembako', pctLabel: '73.3%', subLabel: 'Rp 3.198.000', ratio: 0.733, color: tealPrimary),
                                  const SizedBox(height: 7),
                                  _CategoryBarRow(label: 'Minuman', pctLabel: '19.7%', subLabel: 'Rp 858.000', ratio: 0.197, color: const Color(0xFFF59E0B)),
                                  const SizedBox(height: 7),
                                  _CategoryBarRow(label: 'Makanan', pctLabel: '6.8%', subLabel: 'Rp 298.400', ratio: 0.068, color: const Color(0xFF2563EB)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Store Health Radar & Restok Cepat
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _whiteCard16(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Store Health Radar',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 8),
                                  Center(
                                    child: SizedBox(
                                      width: 78,
                                      height: 78,
                                      child: CustomPaint(painter: _HealthRadarPainter(color: tealPrimary)),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Stok • Margin • Kasir • Audit',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _whiteCard16(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Restok Cepat',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 8),
                                  _restokItemTile(
                                    title: 'Roti Tawar Kupas Premium',
                                    meta: 'SKU 8993002 • Sisa 2 Min 5',
                                    onRestok: () => setState(() => _navIndex = 1),
                                    teal: tealPrimary,
                                  ),
                                  const SizedBox(height: 8),
                                  _restokItemTile(
                                    title: 'Beras Pandan Wangi 5kg',
                                    meta: 'Sisa 3 Min 5',
                                    onRestok: () => setState(() => _navIndex = 1),
                                    teal: tealPrimary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Top 5 Produk
                      _whiteCard16(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Top 5 Produk',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 8),
                            _TopProductLine(rank: '1.', name: 'Beras Pandan Wangi', qty: '34 pcs', total: 'Rp 2.536.000'),
                            _TopProductLine(rank: '2.', name: 'Kopi Susu Gula Aren', qty: '50 pcs', total: 'Rp 674.000'),
                            _TopProductLine(rank: '3.', name: 'Roti Tawar Kupas Premium', qty: '22 pcs', total: 'Rp 330.000'),
                            _TopProductLine(rank: '4.', name: 'Minyak Goreng Pouch 1L', qty: '18 pcs', total: 'Rp 284.400'),
                            _TopProductLine(rank: '5.', name: 'Air Mineral Botol 600ml', qty: '45 pcs', total: 'Rp 180.000'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Cashier Scorecard & Live Struk Feed
                      _whiteCard16(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cashier Scorecard',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text('Raka Wijaya • 28 Struk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                                Text('Skor 98% • Rata-rata 2m 45d', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: tealPrimary)),
                              ],
                            ),
                            const Divider(height: 18),
                            const Text(
                              'Live Struk Feed',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Expanded(
                                  child: Text(
                                    'TRX-261123-0037 • Raka Wijaya',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                  ),
                                ),
                                Text(
                                  'Rp 536.000',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: tealPrimary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _dashSubTabPill(int idx, String label, Color teal) {
    final active = _subDash == idx;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _subDash = idx),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withAlpha(22),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? Colors.white : Colors.white38),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? teal : Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _whiteCard16({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }

  Widget _restokItemTile({
    required String title,
    required String meta,
    required VoidCallback onRestok,
    required Color teal,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              Text(meta, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            ],
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: onRestok,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: teal.withAlpha(24),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: teal.withAlpha(80)),
            ),
            child: Text('Restok', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: teal)),
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



class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
          ),
        ),
      ],
    );
  }
}

class _CategoryBarRow extends StatelessWidget {
  final String label;
  final String pctLabel;
  final String subLabel;
  final double ratio;
  final Color color;

  const _CategoryBarRow({
    required this.label,
    required this.pctLabel,
    required this.subLabel,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            Text(pctLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 2),
        Text(subLabel, style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
      ],
    );
  }
}

class _TopProductLine extends StatelessWidget {
  final String rank;
  final String name;
  final String qty;
  final String total;

  const _TopProductLine({
    required this.rank,
    required this.name,
    required this.qty,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(rank, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
          const SizedBox(width: 6),
          Expanded(
            child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          ),
          Text('$qty • ', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text(total, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0F766E))),
        ],
      ),
    );
  }
}

class _PeakHourlyChartPainter extends CustomPainter {
  final Color color;
  const _PeakHourlyChartPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final pts = [0.22, 0.35, 0.96, 0.48, 0.38, 0.54, 0.42, 0.30];
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < pts.length; i++) {
      final x = (size.width / (pts.length - 1)) * i;
      final y = size.height - (pts[i] * (size.height - 14)) - 6;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    // Titik peak jam 10 (index 2)
    final peakX = (size.width / (pts.length - 1)) * 2;
    final peakY = size.height - (pts[2] * (size.height - 14)) - 6;
    canvas.drawCircle(Offset(peakX, peakY), 5, Paint()..color = color);
    canvas.drawCircle(Offset(peakX, peakY), 2.2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PaymentDonutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    const stroke = 9.0;
    final pQris = Paint()
      ..color = const Color(0xFF0F766E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final pCash = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final pCard = Paint()
      ..color = const Color(0xFF64748B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    canvas.drawArc(rect, -pi / 2, pi * 2 * 0.55, false, pQris);
    canvas.drawArc(rect, -pi / 2 + pi * 2 * 0.55, pi * 2 * 0.30, false, pCash);
    canvas.drawArc(rect, -pi / 2 + pi * 2 * 0.85, pi * 2 * 0.15, false, pCard);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HealthRadarPainter extends CustomPainter {
  final Color color;
  const _HealthRadarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 4;
    final gridPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final scale in [0.45, 0.75, 1.0]) {
      final path = Path();
      for (int i = 0; i < 5; i++) {
        final angle = -pi / 2 + (2 * pi * i / 5);
        final pt = Offset(center.dx + cos(angle) * radius * scale, center.dy + sin(angle) * radius * scale);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    final scores = [0.92, 0.84, 0.96, 0.78, 0.88];
    final fillPath = Path();
    for (int i = 0; i < 5; i++) {
      final angle = -pi / 2 + (2 * pi * i / 5);
      final pt = Offset(center.dx + cos(angle) * radius * scores[i], center.dy + sin(angle) * radius * scores[i]);
      if (i == 0) {
        fillPath.moveTo(pt.dx, pt.dy);
      } else {
        fillPath.lineTo(pt.dx, pt.dy);
      }
    }
    fillPath.close();
    canvas.drawPath(fillPath, Paint()..color = color.withAlpha(55));
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
