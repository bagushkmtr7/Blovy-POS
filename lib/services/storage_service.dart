import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/pos_models.dart';
import 'realtime_sync_service.dart';

class StorageService {
  static const String _kToko = 'pos_pro_toko';
  static const String _kStaff = 'pos_pro_staff';
  static const String _kShift = 'pos_pro_shift';
  static const String _kProduk = 'pos_pro_produk';
  static const String _kLogStok = 'pos_pro_log_stok';
  static const String _kTransaksi = 'pos_pro_transaksi';
  static const String _kPengeluaran = 'pos_pro_pengeluaran';
  static const String _kMember = 'pos_pro_member';
  static const String _kPromo = 'pos_pro_promo';
  static const String _kHold = 'pos_pro_hold';
  static const String _kTema = 'pos_pro_tema';

  static List<AkunStaff> staffDefault() => const [
        AkunStaff(
          id: 'stf_sis',
          nama: 'Store Information System',
          pin: '1234',
          role: RoleStaff.storeSystem,
        ),
        AkunStaff(
          id: 'stf_kasir1',
          nama: 'Kasir Shift Pagi',
          pin: '1111',
          role: RoleStaff.kasir,
        ),
      ];

  static List<Produk> produkDefault() => const [
        Produk(
          id: 'prd_1',
          nama: 'Kopi Susu Gula Aren 250ml',
          kategori: 'Minuman',
          satuan: 'cup',
          hargaJual: 15000,
          hargaModal: 8000,
          hargaGrosir: 13000,
          minQtyGrosir: 3,
          stok: 42,
          minStokAlert: 8,
          kodeSku: '8991001',
        ),
        Produk(
          id: 'prd_2',
          nama: 'Air Mineral Botol 600ml',
          kategori: 'Minuman',
          satuan: 'botol',
          hargaJual: 4000,
          hargaModal: 2200,
          hargaGrosir: 3300,
          minQtyGrosir: 12,
          stok: 96,
          minStokAlert: 15,
          kodeSku: '8991002',
        ),
        Produk(
          id: 'prd_3',
          nama: 'Beras Pandan Wangi 5kg',
          kategori: 'Sembako',
          satuan: 'karung',
          hargaJual: 76000,
          hargaModal: 69500,
          hargaGrosir: 74000,
          minQtyGrosir: 2,
          stok: 16,
          minStokAlert: 5,
          kodeSku: '8992001',
        ),
        Produk(
          id: 'prd_4',
          nama: 'Minyak Goreng Pouch 1L',
          kategori: 'Sembako',
          satuan: 'bungkus',
          hargaJual: 18000,
          hargaModal: 15800,
          hargaGrosir: 17000,
          minQtyGrosir: 3,
          stok: 24,
          minStokAlert: 6,
          kodeSku: '8992002',
        ),
        Produk(
          id: 'prd_5',
          nama: 'Mie Instan Goreng Spesial',
          kategori: 'Makanan',
          satuan: 'pcs',
          hargaJual: 3500,
          hargaModal: 2850,
          hargaGrosir: 3100,
          minQtyGrosir: 5,
          stok: 120,
          minStokAlert: 20,
          kodeSku: '8993001',
        ),
        Produk(
          id: 'prd_6',
          nama: 'Roti Tawar Kupas Premium',
          kategori: 'Makanan',
          satuan: 'bungkus',
          hargaJual: 14500,
          hargaModal: 11000,
          hargaGrosir: 13500,
          minQtyGrosir: 3,
          stok: 4,
          minStokAlert: 5,
          kodeSku: '8993002',
        ),
      ];

  static List<PromoVoucher> promoDefault() => const [
        PromoVoucher(
          id: 'prm_1',
          kode: 'HEMAT5K',
          nama: 'Potongan Belanja Rp 5.000',
          isPersen: false,
          nilai: 5000,
          minBelanja: 50000,
        ),
        PromoVoucher(
          id: 'prm_2',
          kode: 'DISKON10',
          nama: 'Diskon Member 10%',
          isPersen: true,
          nilai: 10,
          minBelanja: 30000,
        ),
      ];

  static List<MemberPelanggan> memberDefault() => const [
        MemberPelanggan(
          id: 'mbr_1',
          nama: 'Budi Santoso',
          telepon: '0813-4455-6677',
          poin: 25,
          totalBelanja: 250000,
          jumlahKunjungan: 4,
        ),
        MemberPelanggan(
          id: 'mbr_2',
          nama: 'Siti Aminah',
          telepon: '0857-1122-3344',
          poin: 40,
          totalBelanja: 410000,
          jumlahKunjungan: 6,
        ),
      ];

  Future<String?> muatTemaId() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kTema);
  }

  Future<void> simpanTemaId(String id) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTema, id);
  }

  Future<PengaturanToko> muatToko() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kToko);
    if (raw == null) return PengaturanToko.defaultAwal();
    return PengaturanToko.fromMap(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> simpanToko(PengaturanToko toko) async {
    final p = await SharedPreferences.getInstance();
    final map = toko.toMap();
    await p.setString(_kToko, jsonEncode(map));
    unawaited(RealtimeSyncService.instance.pushCollection(_kToko, map));
  }

  Future<List<AkunStaff>> muatStaff() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kStaff);
    if (raw == null) {
      final def = staffDefault();
      await simpanStaff(def);
      return def;
    }
    final list = (jsonDecode(raw) as List)
        .map((e) => AkunStaff.fromMap(e as Map<String, dynamic>))
        .toList();
    await simpanStaff(list);
    return list;
  }

  Future<void> simpanStaff(List<AkunStaff> list) async {
    final p = await SharedPreferences.getInstance();
    final data = list.map((e) => e.toMap()).toList();
    await p.setString(_kStaff, jsonEncode(data));
    unawaited(RealtimeSyncService.instance.pushCollection(_kStaff, data));
  }

  Future<List<ShiftKasir>> muatShift() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kShift);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => ShiftKasir.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> simpanShift(List<ShiftKasir> list) async {
    final p = await SharedPreferences.getInstance();
    final data = list.map((e) => e.toMap()).toList();
    await p.setString(_kShift, jsonEncode(data));
    unawaited(RealtimeSyncService.instance.pushCollection(_kShift, data));
  }

  Future<List<Produk>> muatProduk() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kProduk);
    if (raw == null) {
      final def = produkDefault();
      await simpanProduk(def);
      return def;
    }
    return (jsonDecode(raw) as List)
        .map((e) => Produk.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> simpanProduk(List<Produk> list) async {
    final p = await SharedPreferences.getInstance();
    final data = list.map((e) => e.toMap()).toList();
    await p.setString(_kProduk, jsonEncode(data));
    unawaited(RealtimeSyncService.instance.pushCollection(_kProduk, data));
  }

  Future<List<LogStok>> muatLogStok() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kLogStok);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => LogStok.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> simpanLogStok(List<LogStok> list) async {
    final p = await SharedPreferences.getInstance();
    final data = list.map((e) => e.toMap()).toList();
    await p.setString(_kLogStok, jsonEncode(data));
    unawaited(RealtimeSyncService.instance.pushCollection(_kLogStok, data));
  }

  Future<List<TransaksiPos>> muatTransaksi() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kTransaksi);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => TransaksiPos.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> simpanTransaksi(List<TransaksiPos> list) async {
    final p = await SharedPreferences.getInstance();
    final data = list.map((e) => e.toMap()).toList();
    await p.setString(_kTransaksi, jsonEncode(data));
    unawaited(RealtimeSyncService.instance.pushCollection(_kTransaksi, data));
  }

  Future<List<PengeluaranToko>> muatPengeluaran() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kPengeluaran);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => PengeluaranToko.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> simpanPengeluaran(List<PengeluaranToko> list) async {
    final p = await SharedPreferences.getInstance();
    final data = list.map((e) => e.toMap()).toList();
    await p.setString(_kPengeluaran, jsonEncode(data));
    unawaited(RealtimeSyncService.instance.pushCollection(_kPengeluaran, data));
  }

  Future<List<MemberPelanggan>> muatMember() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kMember);
    if (raw == null) {
      final def = memberDefault();
      await simpanMember(def);
      return def;
    }
    return (jsonDecode(raw) as List)
        .map((e) => MemberPelanggan.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> simpanMember(List<MemberPelanggan> list) async {
    final p = await SharedPreferences.getInstance();
    final data = list.map((e) => e.toMap()).toList();
    await p.setString(_kMember, jsonEncode(data));
    unawaited(RealtimeSyncService.instance.pushCollection(_kMember, data));
  }

  Future<List<PromoVoucher>> muatPromo() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kPromo);
    if (raw == null) {
      final def = promoDefault();
      await simpanPromo(def);
      return def;
    }
    return (jsonDecode(raw) as List)
        .map((e) => PromoVoucher.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> simpanPromo(List<PromoVoucher> list) async {
    final p = await SharedPreferences.getInstance();
    final data = list.map((e) => e.toMap()).toList();
    await p.setString(_kPromo, jsonEncode(data));
    unawaited(RealtimeSyncService.instance.pushCollection(_kPromo, data));
  }

  Future<List<KeranjangTertahan>> muatHold() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kHold);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => KeranjangTertahan.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> simpanHold(List<KeranjangTertahan> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kHold, jsonEncode(list.map((e) => e.toMap()).toList()));
  }

  String exportBackupJson({
    required PengaturanToko toko,
    required List<AkunStaff> staff,
    required List<Produk> produk,
    required List<MemberPelanggan> member,
    required List<PromoVoucher> promo,
    required List<TransaksiPos> transaksi,
    required List<PengeluaranToko> pengeluaran,
  }) {
    return jsonEncode({
      'toko': toko.toMap(),
      'staff': staff.map((e) => e.toMap()).toList(),
      'produk': produk.map((e) => e.toMap()).toList(),
      'member': member.map((e) => e.toMap()).toList(),
      'promo': promo.map((e) => e.toMap()).toList(),
      'transaksi': transaksi.map((e) => e.toMap()).toList(),
      'pengeluaran': pengeluaran.map((e) => e.toMap()).toList(),
    });
  }
}
