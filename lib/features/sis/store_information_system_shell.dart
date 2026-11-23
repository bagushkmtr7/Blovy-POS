import 'package:flutter/material.dart';
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
import 'executive_dashboard_view.dart';
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _subDash = 0),
                        borderRadius: BorderRadius.circular(999),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            color: _subDash == 0 ? t.primaryColor : t.inputColor,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _subDash == 0 ? t.primaryColor : t.borderColor,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Control Tower',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: _subDash == 0 ? Colors.white : t.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _subDash = 1),
                        borderRadius: BorderRadius.circular(999),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            color: _subDash == 1 ? t.primaryColor : t.inputColor,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _subDash == 1 ? t.primaryColor : t.borderColor,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Dead Stock',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: _subDash == 1 ? Colors.white : t.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _dialogTambahPengeluaran,
                icon: const Icon(Icons.receipt_long_rounded, size: 15),
                label: const Text(
                  '+ Biaya',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _subDash == 0
              ? ExecutiveDashboardView(
                  tema: t,
                  toko: widget.toko,
                  daftarProduk: widget.daftarProduk,
                  daftarTransaksi: widget.daftarTransaksi,
                  daftarPengeluaran: widget.daftarPengeluaran,
                  daftarShift: widget.daftarShift,
                  daftarMember: widget.daftarMember,
                  periodeTerpilih: _periodeLaporan,
                  onUbahPeriode: (p) => setState(() => _periodeLaporan = p),
                  onMutasiStok: widget.onMutasiStok,
                  onBukaTabDeadStock: () => setState(() => _subDash = 1),
                )
              : _buildSubDeadStock(t),
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

