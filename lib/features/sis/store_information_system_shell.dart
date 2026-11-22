import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../core/utils/pdf_clerek_report.dart';
import '../../models/clerek_model.dart';
import '../../models/sis_models.dart';
import '../../widgets/clerek_blind_dialog.dart';
import '../../services/storage_service.dart';
import '../../widgets/pos_components.dart';
import '../../widgets/struk_sheet.dart';
import '../inventory/inventory_tab.dart';

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
  int _subCrm = 0; // 0: Promo & Voucher, 1: Member & Loyalty, 2: Buku Kasbon
  int _subSistem = 0; // 0: Audit Struk, 1: Shift Kas, 2: SDM & PIN, 3: Sistem
  String _filterShiftStatus = 'Semua';

  // Filter & Pencarian
  String _periodeLaporan = 'Hari Ini';
  int _hariDeadStock = 30;
  final TextEditingController _cariSkuCtrl = TextEditingController();
  final TextEditingController _cariMemberCtrl = TextEditingController();
  String _filterStatusTrx = 'Semua';
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
          _buildMerchandisingTab(t),
          _buildPromoCrmTab(t),
          _buildAuditSistemTab(t),
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

  Widget _buildMerchandisingTab(AppThemeConfig t) {
    return InventoryTab(
      tema: t,
      toko: widget.toko,
      currentStaff: widget.currentStaff,
      daftarStaff: widget.daftarStaff,
      daftarProduk: widget.daftarProduk,
      daftarLogStok: widget.daftarLogStok,
      onSimpanProduk: widget.onSimpanProduk,
      onHapusProduk: widget.onHapusProduk,
      onMutasiStok: widget.onMutasiStok,
    );
  }

  

  

  

  

  

  // ==================== TAB 3: PROMO, CRM & BUKU KASBON ====================

  Widget _buildPromoCrmTab(AppThemeConfig t) {
    final qMember = _cariMemberCtrl.text.trim().toLowerCase();
    final listMember = widget.daftarMember.where((m) {
      return qMember.isEmpty ||
          m.nama.toLowerCase().contains(qMember) ||
          m.telepon.toLowerCase().contains(qMember);
    }).toList();

    final listKasbon =
        widget.daftarTransaksi.where((e) => !e.statusLunas).toList();
    final totalPiutang = listKasbon.fold<int>(
      0,
      (s, e) => s + (e.totalBelanja - e.bayar).clamp(0, 999999999).toInt(),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: SegmentedButton<int>(
            segments: [
              const ButtonSegment(
                value: 0,
                label: Text('Promo', style: TextStyle(fontSize: 11.5)),
              ),
              const ButtonSegment(
                value: 1,
                label: Text('Member', style: TextStyle(fontSize: 11.5)),
              ),
              ButtonSegment(
                value: 2,
                label: Text(
                  'Kasbon (${listKasbon.length})',
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
            ],
            selected: {_subCrm},
            onSelectionChanged: (v) => setState(() => _subCrm = v.first),
          ),
        ),
        if (_subCrm == 0) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SectionHeader(
                    title: 'Program Promosi (${widget.daftarPromo.length})',
                    subtitle: 'Voucher aktif otomatis sinkron ke kasir POS',
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _dialogFormPromo(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Promo'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
              itemCount: widget.daftarPromo.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final prm = widget.daftarPromo[idx];
                final dipakaiCount = widget.daftarTransaksi
                    .where((trx) => trx.kodePromo == prm.kode)
                    .length;

                return Container(
                  padding: const EdgeInsets.all(12),
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
                                  label: prm.kode,
                                  color: prm.aktif
                                      ? t.primaryColor
                                      : t.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                StatusBadge(
                                  label: prm.isPersen
                                      ? 'DISKON ${prm.nilai}%'
                                      : 'POTONGAN ${formatRupiah(prm.nilai)}',
                                  color: t.successColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              prm.nama,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                            Text(
                              'Min. belanja ${formatRupiah(prm.minBelanja)} • Terpakai $dipakaiCount×',
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
                      Switch(
                        value: prm.aktif,
                        onChanged: (v) {
                          widget.onSimpanPromo(
                            PromoVoucher(
                              id: prm.id,
                              kode: prm.kode,
                              nama: prm.nama,
                              isPersen: prm.isPersen,
                              nilai: prm.nilai,
                              minBelanja: prm.minBelanja,
                              aktif: v,
                            ),
                            false,
                          );
                        },
                      ),
                      IconButton(
                        onPressed: () => _dialogFormPromo(editPromo: prm),
                        icon: const Icon(Icons.edit_outlined, size: 19),
                      ),
                      IconButton(
                        onPressed: () => widget.onHapusPromo(prm.id),
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
        ] else if (_subCrm == 1) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cariMemberCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau nomor HP member...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      isDense: true,
                      filled: true,
                      fillColor: t.surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(t.radius),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _dialogFormMember(),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Member'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
              itemCount: listMember.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final m = listMember[idx];
                final tier = m.totalBelanja >= 5000000
                    ? 'PLATINUM'
                    : (m.totalBelanja >= 2000000
                        ? 'GOLD'
                        : (m.totalBelanja >= 500000 ? 'SILVER' : 'REGULER'));

                return Container(
                  padding: const EdgeInsets.all(12),
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
                                  m.nama,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                StatusBadge(
                                  label: tier,
                                  color: tier == 'PLATINUM'
                                      ? t.primaryColor
                                      : (tier == 'GOLD'
                                          ? t.warningColor
                                          : t.accentColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${m.telepon.isEmpty ? 'Tanpa No. HP' : m.telepon} • ${m.jumlahKunjungan}× transaksi',
                              style: TextStyle(
                                fontSize: 11,
                                color: t.textSecondary,
                              ),
                            ),
                            Text(
                              'Total Belanja: ${formatRupiah(m.totalBelanja)}',
                              style: gayaAngka(
                                TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: t.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StatusBadge(
                            label: '${m.poin} POIN',
                            color: t.successColor,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () =>
                                    _dialogFormMember(editMember: m),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                onPressed: () => widget.onHapusMember(m.id),
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: t.dangerColor,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
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
            child: MetricTile(
              tema: t,
              label: 'Total Piutang Kasbon Aktif',
              value: formatRupiah(totalPiutang),
              sublabel: '${listKasbon.length} transaksi belum lunas',
              valueColor:
                  totalPiutang > 0 ? t.dangerColor : t.successColor,
              icon: Icons.account_balance_wallet_outlined,
            ),
          ),
          Expanded(
            child: listKasbon.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada tagihan kasbon pelanggan yang belum lunas.',
                      style: TextStyle(color: t.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
                    itemCount: listKasbon.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final trx = listKasbon[idx];
                      final sisa = (trx.totalBelanja - trx.bayar)
                          .clamp(0, 999999999)
                          .toInt();

                      return Container(
                        padding: const EdgeInsets.all(12),
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
                                        trx.namaPelanggan,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      StatusBadge(
                                        label: trx.nomorStruk,
                                        color: t.warningColor,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Total: ${formatRupiah(trx.totalBelanja)} • Terbayar: ${formatRupiah(trx.bayar)}',
                                    style: gayaAngka(
                                      TextStyle(
                                        fontSize: 11,
                                        color: t.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Sisa Piutang: ${formatRupiah(sisa)} • ${formatTanggalWaktu(trx.tanggal)}',
                                    style: gayaAngka(
                                      TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: t.dangerColor,
                                      ),
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
                              onPressed: () => _dialogBayarKasbonSis(trx),
                              child: const Text(
                                'Bayar',
                                style: TextStyle(fontWeight: FontWeight.w800),
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

  // ==================== TAB 4: AUDIT, SDM & SISTEM ====================

  Widget _buildAuditSistemTab(AppThemeConfig t) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Struk & Audit', style: TextStyle(fontSize: 10.5)),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Shift & Clerek', style: TextStyle(fontSize: 10.5)),
              ),
              ButtonSegment(
                value: 2,
                label: Text('SDM & PIN', style: TextStyle(fontSize: 10.5)),
              ),
              ButtonSegment(
                value: 3,
                label: Text('Sistem & DB', style: TextStyle(fontSize: 10.5)),
              ),
            ],
            selected: {_subSistem},
            onSelectionChanged: (v) => setState(() => _subSistem = v.first),
          ),
        ),
        Expanded(
          child: _subSistem == 0
              ? _buildSubAuditStruk(t)
              : (_subSistem == 1
                  ? _buildSubAuditShift(t)
                  : (_subSistem == 2
                      ? _buildSubSdmStaff(t)
                      : _buildSubPengaturanSistem(t))),
        ),
      ],
    );
  }

  Widget _buildSubAuditStruk(AppThemeConfig t) {
    final q = _cariStrukCtrl.text.trim().toLowerCase();
    final listTrx = widget.daftarTransaksi.where((trx) {
      if (_filterStatusTrx == 'Lunas' && !trx.statusLunas) return false;
      if (_filterStatusTrx == 'Kasbon' && trx.statusLunas) return false;
      if (_filterStatusTrx == 'Tunai' &&
          trx.metodeBayar.toLowerCase() != 'tunai') {
        return false;
      }
      if (_filterStatusTrx == 'QRIS' &&
          trx.metodeBayar.toLowerCase() != 'qris') {
        return false;
      }
      if (_filterStatusTrx == 'Transfer' &&
          !trx.metodeBayar.toLowerCase().contains('transfer') &&
          !trx.metodeBayar.toLowerCase().contains('edc')) {
        return false;
      }

      return q.isEmpty ||
          trx.nomorStruk.toLowerCase().contains(q) ||
          trx.namaKasir.toLowerCase().contains(q) ||
          trx.namaPelanggan.toLowerCase().contains(q) ||
          trx.items.any((i) => i.namaProduk.toLowerCase().contains(q));
    }).toList();

    final totalOmzetFilter =
        listTrx.fold<int>(0, (sum, e) => sum + e.totalBelanja);
    final totalMarginFilter =
        listTrx.fold<int>(0, (sum, e) => sum + e.estimasiLabaKotor);
    final totalKasbonFilter = listTrx
        .where((e) => !e.statusLunas)
        .fold<int>(0, (sum, e) => sum + e.totalBelanja);

    return Column(
      children: [
        // Ringkasan Audit Struk
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: MetricTile(
                  tema: t,
                  label: 'Omzet Struk (${listTrx.length})',
                  value: formatRupiah(totalOmzetFilter),
                  valueColor: t.primaryColor,
                  icon: Icons.receipt_long_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  tema: t,
                  label: 'Laba Kotor Audit',
                  value: formatRupiah(totalMarginFilter),
                  valueColor: t.successColor,
                  icon: Icons.trending_up_rounded,
                ),
              ),
            ],
          ),
        ),
        if (totalKasbonFilter > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: t.warningColor.withAlpha(22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: t.warningColor.withAlpha(80)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Piutang / Kasbon Belum Lunas:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: t.warningColor,
                    ),
                  ),
                  Text(
                    formatRupiah(totalKasbonFilter),
                    style: gayaAngka(
                      TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: t.warningColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Pencarian Nomor Struk / Produk / Kasir
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
          child: TextField(
            controller: _cariStrukCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Cari no. struk, nama barang, kasir, atau member...',
              hintStyle: const TextStyle(fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _cariStrukCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 17),
                      onPressed: () {
                        _cariStrukCtrl.clear();
                        setState(() {});
                      },
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: t.surfaceColor,
              contentPadding: const EdgeInsets.symmetric(vertical: 9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.radius),
              ),
            ),
          ),
        ),

        // Chip Filter Status & Metode Pembayaran
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              for (final f in [
                'Semua',
                'Lunas',
                'Tunai',
                'QRIS',
                'Transfer',
                'Kasbon',
              ]) ...[
                ChoiceChip(
                  label: Text(f, style: const TextStyle(fontSize: 11)),
                  selected: _filterStatusTrx == f,
                  onSelected: (_) => setState(() => _filterStatusTrx = f),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Daftar Struk Audit
        Expanded(
          child: listTrx.isEmpty
              ? Center(
                  child: Text(
                    'Tidak ada data struk yang sesuai filter.',
                    style: TextStyle(color: t.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
                  itemCount: listTrx.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final trx = listTrx[idx];
                    final totalQty =
                        trx.items.fold<int>(0, (s, item) => s + item.qty);

                    return TactilePress(
                      onTap: () {
                        tampilkanStrukDigital(
                          context: context,
                          tema: t,
                          transaksi: trx,
                          toko: widget.toko,
                          currentStaff: widget.currentStaff,
                          daftarStaff: widget.daftarStaff,
                          onVoidTransaksi: () => widget.onVoidTransaksi(trx),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: dekorasiKartu(
                          t,
                          borderOverride: trx.statusLunas
                              ? t.borderColor
                              : t.warningColor,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Text(
                                        trx.nomorStruk,
                                        style: gayaAngka(
                                          const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      StatusBadge(
                                        label: trx.statusLunas
                                            ? trx.metodeBayar.toUpperCase()
                                            : 'KASBON',
                                        color: trx.statusLunas
                                            ? t.successColor
                                            : t.warningColor,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  formatRupiah(trx.totalBelanja),
                                  style: gayaAngka(
                                    TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: t.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Kasir: ${trx.namaKasir} • Pelanggan: ${trx.namaPelanggan} ($totalQty item)',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formatTanggalWaktu(trx.tanggal),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: t.textSecondary,
                                  ),
                                ),
                                Text(
                                  'Laba: ${formatRupiah(trx.estimasiLabaKotor)} • Ketuk Audit/Void ›',
                                  style: gayaAngka(
                                    TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: t.successColor,
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
                ),
        ),
      ],
    );
  }

  Widget _buildSubAuditShift(AppThemeConfig t) {
    int jmlAktif = 0;
    int jmlMenungguClerek = 0;
    int jmlSelesaiZ = 0;
    int totalSelisihTerkunci = 0;

    for (final sh in widget.daftarShift) {
      final z = _mapClerekZReport[sh.id];
      if (sh.aktif) {
        jmlAktif++;
      } else if (z != null && z.sudahDirekonsiliasi) {
        jmlSelesaiZ++;
        totalSelisihTerkunci += z.selisihTunai;
      } else {
        jmlMenungguClerek++;
      }
    }

    final listShiftFiltered = widget.daftarShift.where((sh) {
      final z = _mapClerekZReport[sh.id];
      final sudahZ = z != null && z.sudahDirekonsiliasi;
      if (_filterShiftStatus == 'Aktif') return sh.aktif;
      if (_filterShiftStatus == 'Perlu Clerek') return !sh.aktif && !sudahZ;
      if (_filterShiftStatus == 'Selesai Z-Report') return sudahZ;
      return true;
    }).toList();

    return Column(
      children: [
        // Ringkasan KPI Shift & Clerek
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: MetricTile(
                  tema: t,
                  label: 'Antrean Clerek',
                  value: '$jmlMenungguClerek Pending • $jmlAktif Aktif',
                  valueColor:
                      jmlMenungguClerek > 0 ? t.warningColor : t.primaryColor,
                  icon: Icons.point_of_sale_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  tema: t,
                  label: 'Selisih Z-Report ($jmlSelesaiZ)',
                  value:
                      '${totalSelisihTerkunci >= 0 ? '+' : ''}${formatRupiah(totalSelisihTerkunci)}',
                  valueColor: totalSelisihTerkunci == 0
                      ? t.successColor
                      : t.dangerColor,
                  icon: Icons.balance_rounded,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Filter Status Shift
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              for (final st in [
                'Semua',
                'Aktif',
                'Perlu Clerek',
                'Selesai Z-Report',
              ]) ...[
                ChoiceChip(
                  label: Text(
                    st == 'Perlu Clerek'
                        ? 'Perlu Clerek ($jmlMenungguClerek)'
                        : st,
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: _filterShiftStatus == st,
                  onSelected: (_) => setState(() => _filterShiftStatus = st),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Daftar Kartu Shift yang Rapi & Terstruktur
        Expanded(
          child: listShiftFiltered.isEmpty
              ? Center(
                  child: Text(
                    'Tidak ada data shift pada filter "$_filterShiftStatus".',
                    style: TextStyle(color: t.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
                  itemCount: listShiftFiltered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final sh = listShiftFiltered[idx];
                    final draftOrZ = _mapClerekZReport[sh.id] ??
                        buatDraftClerekDariShift(
                          shift: sh,
                          namaOtorisasiTutup: sh.namaStaff,
                          daftarTransaksi: widget.daftarTransaksi,
                          daftarPengeluaran: widget.daftarPengeluaran,
                          waktuTutup: sh.waktuTutup ?? DateTime.now(),
                        );
                    final terkunci = draftOrZ.sudahDirekonsiliasi;

                    Color badgeColor = t.warningColor;
                    String badgeLabel = 'PERLU SETORAN CLEREK';
                    if (sh.aktif) {
                      badgeColor = t.successColor;
                      badgeLabel = 'SHIFT BERJALAN';
                    } else if (terkunci) {
                      badgeColor = draftOrZ.selisihTunai == 0
                          ? t.primaryColor
                          : t.dangerColor;
                      badgeLabel = draftOrZ.selisihTunai == 0
                          ? 'Z-REPORT KLOP'
                          : 'Z-REPORT SELISIH';
                    }

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: dekorasiKartu(
                        t,
                        borderOverride: (!sh.aktif && !terkunci)
                            ? t.warningColor
                            : t.borderColor,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header Kartu Shift
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 17,
                                backgroundColor: badgeColor.withAlpha(24),
                                child: Icon(
                                  sh.aktif
                                      ? Icons.sensors_rounded
                                      : (terkunci
                                          ? Icons.verified_rounded
                                          : Icons.lock_clock_rounded),
                                  size: 18,
                                  color: badgeColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sh.namaStaff,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    Text(
                                      draftOrZ.nomorClerek,
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
                              StatusBadge(
                                label: badgeLabel,
                                color: badgeColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Informasi Waktu Buka & Tutup
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: t.inputColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Buka: ${formatTanggalWaktu(sh.waktuBuka)}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                Text(
                                  sh.waktuTutup != null
                                      ? 'Tutup: ${formatTanggalWaktu(sh.waktuTutup!)}'
                                      : 'Kasir masih aktif',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: sh.aktif
                                        ? t.successColor
                                        : t.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Konten Sesuai Fase Shift (Aktif / Menunggu Clerek / Z-Report Terkunci)
                          if (sh.aktif) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _BarisSistem(
                                    'Modal Awal Laci',
                                    formatRupiah(sh.modalAwal),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _BarisSistem(
                                    'Struk Shift Ini',
                                    '${draftOrZ.jumlahStrukSukses} Struk',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Input setoran clerek & Z-Report akan terbuka otomatis setelah kasir melakukan Tutup Shift di terminal POS.',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: t.textSecondary,
                              ),
                            ),
                          ] else if (!terkunci) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: t.warningColor.withAlpha(18),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: t.warningColor.withAlpha(70),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.visibility_off_rounded,
                                    size: 18,
                                    color: t.warningColor,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Shift sudah ditutup. Hitung fisik uang laci & settlement non-tunai untuk membuka Z-Report.',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: t.primaryColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 11),
                              ),
                              onPressed: () async {
                                final locked =
                                    await tampilkanDialogInputSetoranButaSis(
                                  context: ctx,
                                  tema: t,
                                  draft: draftOrZ,
                                  daftarStaff: widget.daftarStaff,
                                );
                                if (locked != null && ctx.mounted) {
                                  setState(() {
                                    _mapClerekZReport[sh.id] = locked;
                                  });
                                  await tampilkanHasilZReportClerek(
                                    context: ctx,
                                    tema: t,
                                    toko: widget.toko,
                                    laporan: locked,
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.lock_open_rounded,
                                size: 17,
                              ),
                              label: const Text(
                                'Input Setoran Clerek SIS',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ] else ...[
                            _BarisSistem(
                              'Kas Seharusnya (Sistem)',
                              formatRupiah(draftOrZ.kasSeharusnyaSistem),
                            ),
                            _BarisSistem(
                              'Total Fisik Tunai (SIS)',
                              formatRupiah(draftOrZ.totalFisikTunai),
                            ),
                            _BarisSistem(
                              'Net Setoran ke Brankas',
                              formatRupiah(draftOrZ.netSetoranBrankas),
                            ),
                            _BarisSistem(
                              'Selisih Tunai Laci',
                              '${draftOrZ.selisihTunai >= 0 ? '+' : ''}${formatRupiah(draftOrZ.selisihTunai)}',
                              warnaNilai: draftOrZ.selisihTunai == 0
                                  ? t.successColor
                                  : t.dangerColor,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => tampilkanHasilZReportClerek(
                                      context: ctx,
                                      tema: t,
                                      toko: widget.toko,
                                      laporan: draftOrZ,
                                    ),
                                    icon: const Icon(
                                      Icons.fact_check_outlined,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Detail Z-Report',
                                      style: TextStyle(fontSize: 11.5),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.tonalIcon(
                                    onPressed: () => unduhPdfLaporanClerek(
                                      laporan: draftOrZ,
                                      toko: widget.toko,
                                    ),
                                    icon: const Icon(
                                      Icons.picture_as_pdf_rounded,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Unduh PDF',
                                      style: TextStyle(fontSize: 11.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSubSdmStaff(AppThemeConfig t) {
    final totalSis =
        widget.daftarStaff.where((s) => s.isStoreSystem).length;
    final totalKasir =
        widget.daftarStaff.where((s) => !s.isStoreSystem).length;
    final totalAktif = widget.daftarStaff.where((s) => s.aktif).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: MetricTile(
                tema: t,
                label: 'Komposisi Tim',
                value: '$totalSis SIS • $totalKasir Kasir',
                valueColor: t.primaryColor,
                icon: Icons.badge_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricTile(
                tema: t,
                label: 'Status Akses PIN',
                value: '$totalAktif / ${widget.daftarStaff.length} Aktif',
                valueColor: t.successColor,
                icon: Icons.verified_user_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: SectionHeader(
                title: 'Manajemen Akun & Otoritas PIN',
                subtitle: 'Pemisahan akses Store Information System & Kasir POS',
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: t.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _dialogFormStaff(),
              icon: const Icon(Icons.person_add_rounded, size: 17),
              label: const Text('Tambah Akun'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...widget.daftarStaff.map((st) {
          final jumlahShiftStaff =
              widget.daftarShift.where((s) => s.staffId == st.id).length;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: dekorasiKartu(
              t,
              borderOverride: st.aktif ? t.borderColor : t.dangerColor,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          (st.isStoreSystem ? t.primaryColor : t.accentColor)
                              .withAlpha(26),
                      child: Icon(
                        st.isStoreSystem
                            ? Icons.dns_rounded
                            : Icons.point_of_sale_rounded,
                        color: st.isStoreSystem ? t.primaryColor : t.accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  st.nama,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              StatusBadge(
                                label: st.aktif ? 'AKTIF' : 'NONAKTIF',
                                color:
                                    st.aktif ? t.successColor : t.dangerColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${st.labelRole} • PIN: **** • $jumlahShiftStaff Sesi Shift',
                            style:
                                TextStyle(fontSize: 11, color: t.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (st.id != widget.currentStaff.id)
                      Switch(
                        value: st.aktif,
                        activeColor: t.successColor,
                        onChanged: (val) {
                          widget.onSimpanStaff(
                            st.copyWith(aktif: val),
                            false,
                          );
                          _info(
                            val
                                ? 'Akun ${st.nama} diaktifkan kembali.'
                                : 'Akses login ${st.nama} dinonaktifkan.',
                          );
                        },
                      ),
                  ],
                ),
                const Divider(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _dialogFormStaff(editStaff: st),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text(
                        'Edit Profil / Reset PIN',
                        style: TextStyle(fontSize: 11.5),
                      ),
                    ),
                    if (st.id != widget.currentStaff.id)
                      TextButton.icon(
                        onPressed: () => widget.onHapusStaff(st.id),
                        icon: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: t.dangerColor,
                        ),
                        label: Text(
                          'Hapus',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: t.dangerColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSubPengaturanSistem(AppThemeConfig t) {
    final namaCtrl = TextEditingController(text: widget.toko.namaToko);
    final alamatCtrl = TextEditingController(text: widget.toko.alamatToko);
    final telpCtrl = TextEditingController(text: widget.toko.teleponToko);
    final strukCtrl = TextEditingController(text: widget.toko.catatanStruk);
    final ppnCtrl =
        TextEditingController(text: widget.toko.persenPajak.toString());
    final serviceCtrl =
        TextEditingController(text: widget.toko.persenService.toString());
    final perPoinCtrl =
        TextEditingController(text: widget.toko.nominalPerPoin.toString());
    final tukarPoinCtrl =
        TextEditingController(text: widget.toko.nilaiTukarPoin.toString());

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 28),
      children: [
        // Ringkasan Kapasitas Database Lokal
        Container(
          padding: const EdgeInsets.all(12),
          decoration: dekorasiKartu(t),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.storage_rounded, size: 18, color: t.primaryColor),
                  const SizedBox(width: 6),
                  const Text(
                    'Ringkasan Database Store Information System',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  StatusBadge(
                    label: '${widget.daftarProduk.length} SKU Produk',
                    color: t.primaryColor,
                  ),
                  StatusBadge(
                    label: '${widget.daftarTransaksi.length} Struk',
                    color: t.successColor,
                  ),
                  StatusBadge(
                    label: '${widget.daftarShift.length} Shift',
                    color: t.accentColor,
                  ),
                  StatusBadge(
                    label: '${widget.daftarMember.length} Member',
                    color: const Color(0xFF1565C0),
                  ),
                  StatusBadge(
                    label: '${widget.daftarLogStok.length} Log Stok',
                    color: t.warningColor,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        const SectionHeader(
          title: 'Identitas Toko & Parameter POS',
          subtitle: 'Konfigurasi kop struk, dokumen PDF, pajak & poin',
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: dekorasiKartu(t),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: namaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Toko / Cabang',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: alamatCtrl,
                decoration: const InputDecoration(
                  labelText: 'Alamat Lengkap Toko',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: telpCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nomor Telepon Toko',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: strukCtrl,
                decoration: const InputDecoration(
                  labelText: 'Catatan Footer Struk',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ppnCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'PPN (%)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: serviceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Service (%)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: perPoinCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Belanja / 1 Poin (Rp)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: tukarPoinCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Nilai 1 Poin (Rp)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: t.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                onPressed: () {
                  widget.onSimpanToko(
                    PengaturanToko(
                      namaToko: namaCtrl.text.trim().isEmpty
                          ? widget.toko.namaToko
                          : namaCtrl.text.trim(),
                      alamatToko: alamatCtrl.text.trim(),
                      teleponToko: telpCtrl.text.trim(),
                      catatanStruk: strukCtrl.text.trim(),
                      persenPajak: int.tryParse(ppnCtrl.text) ?? 0,
                      persenService: int.tryParse(serviceCtrl.text) ?? 0,
                      nominalPerPoin: int.tryParse(perPoinCtrl.text) ?? 10000,
                      nilaiTukarPoin: int.tryParse(tukarPoinCtrl.text) ?? 500,
                    ),
                  );
                  _info('Konfigurasi Store Information System disimpan.');
                },
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Simpan Konfigurasi Sistem'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionHeader(
          title: 'Tema Antarmuka POS',
          subtitle: 'Berlaku untuk Store Information System & Terminal Kasir',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kDaftarTema.map((itemTema) {
            final dipilih = itemTema.id == t.id;
            return ChoiceChip(
              label: Text(itemTema.nama),
              selected: dipilih,
              onSelected: (_) => widget.onGantiTema(itemTema.id),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        const SectionHeader(
          title: 'Backup & Restore Database',
          subtitle: 'Ekspor seluruh master data, transaksi & shift ke JSON',
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () async {
                  final jsonStr = StorageService().exportBackupJson(
                    toko: widget.toko,
                    staff: widget.daftarStaff,
                    produk: widget.daftarProduk,
                    member: widget.daftarMember,
                    promo: widget.daftarPromo,
                    transaksi: widget.daftarTransaksi,
                    pengeluaran: widget.daftarPengeluaran,
                  );
                  await Clipboard.setData(ClipboardData(text: jsonStr));
                  _info('Full Backup JSON disalin ke clipboard.');
                },
                icon: const Icon(Icons.backup_rounded, size: 18),
                label: const Text('Backup JSON'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final pasteCtrl = TextEditingController();
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Restore Database JSON'),
                      content: TextField(
                        controller: pasteCtrl,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Tempel JSON backup di sini...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Batal'),
                        ),
                        FilledButton(
                          onPressed: () {
                            if (pasteCtrl.text.trim().isEmpty) return;
                            Navigator.pop(ctx);
                            widget.onRestoreJson(pasteCtrl.text.trim());
                            _info('Database berhasil dipulihkan.');
                          },
                          child: const Text('Restore'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: const Text('Restore JSON'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BarisSistem extends StatelessWidget {
  final String label;
  final String nilai;
  final Color? warnaNilai;

  const _BarisSistem(this.label, this.nilai, {this.warnaNilai});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            nilai,
            style: gayaAngka(
              TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: warnaNilai,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
