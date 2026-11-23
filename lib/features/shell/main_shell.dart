import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../services/storage_service.dart';
import '../../services/realtime_sync_service.dart';
import '../../widgets/struk_sheet.dart';
import '../sis/store_information_system_shell.dart';
import '../auth/login_shift_screen.dart';
import '../kasir/kasir_tab.dart';

class PosMainShell extends StatefulWidget {
  final AppThemeConfig tema;
  final ValueChanged<String> onGantiTema;

  const PosMainShell({
    super.key,
    required this.tema,
    required this.onGantiTema,
  });

  @override
  State<PosMainShell> createState() => _PosMainShellState();
}

class _PosMainShellState extends State<PosMainShell> {
  final StorageService _storage = StorageService();

  bool _loading = true;

  PengaturanToko _toko = PengaturanToko.defaultAwal();
  List<AkunStaff> _daftarStaff = [];
  List<ShiftKasir> _daftarShift = [];
  List<Produk> _daftarProduk = [];
  List<LogStok> _daftarLogStok = [];
  List<TransaksiPos> _daftarTransaksi = [];
  List<PengeluaranToko> _daftarPengeluaran = [];
  List<MemberPelanggan> _daftarMember = [];
  List<PromoVoucher> _daftarPromo = [];
  List<KeranjangTertahan> _daftarHold = [];

  AkunStaff? _currentStaff;
  final Map<String, int> _keranjang = {};

  @override
  void initState() {
    super.initState();
    RealtimeSyncService.instance.onRemoteDataApplied = _muatSemuaData;
    _initRealtimeDanData();
  }

  Future<void> _initRealtimeDanData() async {
    await _muatSemuaData();
    await RealtimeSyncService.instance.init();
  }

  @override
  void dispose() {
    if (RealtimeSyncService.instance.onRemoteDataApplied == _muatSemuaData) {
      RealtimeSyncService.instance.onRemoteDataApplied = null;
    }
    super.dispose();
  }

  Future<void> _muatSemuaData() async {
    final toko = await _storage.muatToko();
    final staff = await _storage.muatStaff();
    final shift = await _storage.muatShift();
    final produk = await _storage.muatProduk();
    final logStok = await _storage.muatLogStok();
    final trx = await _storage.muatTransaksi();
    final exp = await _storage.muatPengeluaran();
    final member = await _storage.muatMember();
    final promo = await _storage.muatPromo();
    final hold = await _storage.muatHold();

    if (!mounted) return;
    setState(() {
      _toko = toko;
      _daftarStaff = staff;
      _daftarShift = shift;
      _daftarProduk = produk;
      _daftarLogStok = logStok;
      _daftarTransaksi = trx;
      _daftarPengeluaran = exp;
      _daftarMember = member;
      _daftarPromo = promo;
      _daftarHold = hold;
      _loading = false;
    });
  }

  ShiftKasir? get _shiftAktif {
    final idx = _daftarShift.indexWhere((s) => s.aktif);
    return idx == -1 ? null : _daftarShift[idx];
  }

  void _info(String pesan) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pesan),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --- SHIFT & LOGIN ---
  void _masukTerminal(AkunStaff staff, int? modalAwalShift) {
    setState(() {
      _currentStaff = staff;
    });
    if (modalAwalShift != null) {
      _bukaShift(modalAwalShift);
    }
  }

  void _bukaShift(int modalAwal) {
    final staff = _currentStaff;
    if (staff == null) return;
    final shiftBaru = ShiftKasir(
      id: 'shf_${DateTime.now().millisecondsSinceEpoch}',
      staffId: staff.id,
      namaStaff: staff.nama,
      waktuBuka: DateTime.now(),
      modalAwal: modalAwal,
      aktif: true,
    );
    setState(() {
      _daftarShift.insert(0, shiftBaru);
    });
    _storage.simpanShift(_daftarShift);
    _info('Shift dibuka oleh ${staff.nama}');
  }

  Future<void> _tutupShift([int? kasAktual]) async {
    final shift = _shiftAktif;
    if (shift == null) return;
    final waktuTutup = DateTime.now();
    setState(() {
      final idx = _daftarShift.indexWhere((s) => s.id == shift.id);
      if (idx != -1) {
        _daftarShift[idx] = ShiftKasir(
          id: shift.id,
          staffId: shift.staffId,
          namaStaff: shift.namaStaff,
          waktuBuka: shift.waktuBuka,
          waktuTutup: waktuTutup,
          modalAwal: shift.modalAwal,
          penjualanTunai: shift.penjualanTunai,
          penjualanNonTunai: shift.penjualanNonTunai,
          pengeluaranKas: shift.pengeluaranKas,
          kasAktualTutup: kasAktual ?? 0,
          aktif: false,
        );
      }
    });
    await _storage.simpanShift(_daftarShift);
  }

  // --- KERANJANG & HOLD ---
  void _ubahQtyKeranjang(String produkId, int delta) {
    final idx = _daftarProduk.indexWhere((p) => p.id == produkId);
    if (idx == -1) return;
    final produk = _daftarProduk[idx];
    final qtySekarang = _keranjang[produkId] ?? 0;
    final qtyBaru = (qtySekarang + delta).clamp(0, produk.stok);

    setState(() {
      if (qtyBaru <= 0) {
        _keranjang.remove(produkId);
      } else {
        _keranjang[produkId] = qtyBaru;
      }
    });
  }

  void _tahanKeranjang(String labelPelanggan) {
    if (_keranjang.isEmpty) return;
    final hold = KeranjangTertahan(
      id: 'hld_${DateTime.now().millisecondsSinceEpoch}',
      label: labelPelanggan.isEmpty ? 'Antrean Pelanggan' : labelPelanggan,
      waktu: DateTime.now(),
      items: Map<String, int>.from(_keranjang),
    );
    setState(() {
      _daftarHold.insert(0, hold);
      _keranjang.clear();
    });
    _storage.simpanHold(_daftarHold);
    _info('Keranjang diparkir ke antrean.');
  }

  void _pulihkanHold(KeranjangTertahan hold) {
    setState(() {
      _keranjang.clear();
      for (final entry in hold.items.entries) {
        final idx = _daftarProduk.indexWhere((p) => p.id == entry.key);
        if (idx != -1 && _daftarProduk[idx].stok > 0) {
          _keranjang[entry.key] =
              entry.value.clamp(1, _daftarProduk[idx].stok);
        }
      }
      _daftarHold.removeWhere((h) => h.id == hold.id);
    });
    _storage.simpanHold(_daftarHold);
    _info('Antrean ${hold.label} dipulihkan.');
  }

  void _hapusHold(String holdId) {
    setState(() {
      _daftarHold.removeWhere((h) => h.id == holdId);
    });
    _storage.simpanHold(_daftarHold);
  }

  // --- TRANSAKSI & STOK OTOMATIS ---
  void _selesaikanTransaksi({
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
  }) {
    if (_keranjang.isEmpty || _currentStaff == null) return;

    final now = DateTime.now();
    final nomorStruk = buatNomorStruk(_daftarTransaksi.length);
    final itemsTrx = <ItemTransaksi>[];
    int subtotal = 0;
    int totalModal = 0;

    for (final entry in _keranjang.entries) {
      final pIdx = _daftarProduk.indexWhere((p) => p.id == entry.key);
      if (pIdx == -1 || entry.value <= 0) continue;
      final prod = _daftarProduk[pIdx];
      final grosir = prod.isGrosirAktif(entry.value);
      final hargaAktif = prod.hargaUntukQty(entry.value);

      final item = ItemTransaksi(
        produkId: prod.id,
        namaProduk: prod.nama,
        satuan: prod.satuan,
        hargaJual: hargaAktif,
        hargaModal: prod.hargaModal,
        qty: entry.value,
        hargaGrosirTerpakai: grosir,
      );
      itemsTrx.add(item);
      subtotal += item.subtotal;
      totalModal += item.totalModal;

      // Potong stok & catat Kartu Stok
      final stokBaru = (prod.stok - entry.value).clamp(0, 999999);
      _daftarProduk[pIdx] = prod.copyWith(stok: stokBaru);
      _daftarLogStok.insert(
        0,
        LogStok(
          id: 'log_${now.millisecondsSinceEpoch}_${prod.id}',
          produkId: prod.id,
          namaProduk: prod.nama,
          tipe: 'Keluar',
          perubahan: -entry.value,
          stokAkhir: stokBaru,
          keterangan: 'Penjualan $nomorStruk',
          olehStaff: _currentStaff!.nama,
          tanggal: now,
        ),
      );
    }

    final potonganPoin = poinDipakai * _toko.nilaiTukarPoin;
    final dasar =
        (subtotal - diskon - potonganPoin).clamp(0, subtotal);
    final totalBelanja = dasar + serviceCharge + pajak;
    final kembalian =
        statusLunas ? (bayar - totalBelanja).clamp(0, bayar) : 0;

    final shift = _shiftAktif;
    final trxBaru = TransaksiPos(
      id: 'trx_${now.millisecondsSinceEpoch}',
      nomorStruk: nomorStruk,
      shiftId: shift?.id ?? '',
      namaKasir: _currentStaff!.nama,
      tanggal: now,
      items: itemsTrx,
      subtotal: subtotal,
      diskon: diskon,
      kodePromo: kodePromo,
      pajak: pajak,
      serviceCharge: serviceCharge,
      totalBelanja: totalBelanja,
      totalModal: totalModal,
      bayar: bayar,
      kembalian: kembalian,
      metodeBayar: metodeBayar,
      statusLunas: statusLunas,
      memberId: memberId,
      namaPelanggan: namaPelanggan,
      poinDidapat: poinDidapat,
      poinDipakai: poinDipakai,
      catatan: catatan,
    );

    // Update Poin & Riwayat Member
    if (memberId.isNotEmpty) {
      final mIdx = _daftarMember.indexWhere((m) => m.id == memberId);
      if (mIdx != -1) {
        final mLama = _daftarMember[mIdx];
        final poinBaru =
            (mLama.poin - poinDipakai + poinDidapat).clamp(0, 999999);
        _daftarMember[mIdx] = mLama.copyWith(
          poin: poinBaru,
          totalBelanja: mLama.totalBelanja + totalBelanja,
          jumlahKunjungan: mLama.jumlahKunjungan + 1,
        );
      }
    }

    // Update Laci Kas Shift Aktif
    if (shift != null) {
      final sIdx = _daftarShift.indexWhere((s) => s.id == shift.id);
      if (sIdx != -1) {
        if (metodeBayar == 'Tunai' && statusLunas) {
          _daftarShift[sIdx] = shift.copyWith(
            penjualanTunai: shift.penjualanTunai + totalBelanja,
          );
        } else if (statusLunas) {
          _daftarShift[sIdx] = shift.copyWith(
            penjualanNonTunai: shift.penjualanNonTunai + totalBelanja,
          );
        } else if (!statusLunas && bayar > 0) {
          _daftarShift[sIdx] = shift.copyWith(
            penjualanTunai: shift.penjualanTunai + bayar,
          );
        }
      }
    }

    setState(() {
      _daftarTransaksi.insert(0, trxBaru);
      _keranjang.clear();
    });

    _storage.simpanProduk(_daftarProduk);
    _storage.simpanLogStok(_daftarLogStok);
    _storage.simpanTransaksi(_daftarTransaksi);
    _storage.simpanMember(_daftarMember);
    _storage.simpanShift(_daftarShift);

    try {
      if (!mounted) return;
      tampilkanStrukDigital(
        context: context,
        tema: widget.tema,
        transaksi: trxBaru,
        toko: _toko,
        currentStaff: _currentStaff!,
        daftarStaff: _daftarStaff,
        onVoidTransaksi: () => _voidTransaksi(trxBaru),
      );
    } catch (e) {
      _info('Transaksi ${trxBaru.nomorStruk} tersimpan, namun struk gagal dibuka: $e');
    }
  }

  void _voidTransaksi(TransaksiPos trx) {
    final now = DateTime.now();
    // Kembalikan stok & catat log void
    for (final item in trx.items) {
      final pIdx = _daftarProduk.indexWhere((p) => p.id == item.produkId);
      if (pIdx != -1) {
        final prod = _daftarProduk[pIdx];
        final stokBaru = prod.stok + item.qty;
        _daftarProduk[pIdx] = prod.copyWith(stok: stokBaru);
        _daftarLogStok.insert(
          0,
          LogStok(
            id: 'log_${now.millisecondsSinceEpoch}_${prod.id}',
            produkId: prod.id,
            namaProduk: prod.nama,
            tipe: 'Void',
            perubahan: item.qty,
            stokAkhir: stokBaru,
            keterangan: 'Void Struk ${trx.nomorStruk}',
            olehStaff: _currentStaff?.nama ?? 'Store Information System',
            tanggal: now,
          ),
        );
      }
    }

    // Kurangi penjualan di shift terkait jika masih aktif
    if (trx.shiftId.isNotEmpty) {
      final sIdx = _daftarShift.indexWhere((s) => s.id == trx.shiftId);
      if (sIdx != -1 && _daftarShift[sIdx].aktif) {
        final sh = _daftarShift[sIdx];
        if (trx.metodeBayar == 'Tunai' && trx.statusLunas) {
          _daftarShift[sIdx] = sh.copyWith(
            penjualanTunai:
                (sh.penjualanTunai - trx.totalBelanja).clamp(0, 999999999),
          );
        } else if (trx.statusLunas) {
          _daftarShift[sIdx] = sh.copyWith(
            penjualanNonTunai:
                (sh.penjualanNonTunai - trx.totalBelanja).clamp(0, 999999999),
          );
        }
      }
    }

    setState(() {
      _daftarTransaksi.removeWhere((t) => t.id == trx.id);
    });

    _storage.simpanProduk(_daftarProduk);
    _storage.simpanLogStok(_daftarLogStok);
    _storage.simpanTransaksi(_daftarTransaksi);
    _storage.simpanShift(_daftarShift);
    _info('Transaksi ${trx.nomorStruk} dibatalkan (Void) & stok dikembalikan.');
  }

  // --- INVENTORY ---
  void _simpanProduk(Produk produk, bool isBaru) {
    setState(() {
      if (isBaru) {
        _daftarProduk.insert(0, produk);
        _daftarLogStok.insert(
          0,
          LogStok(
            id: 'log_${DateTime.now().millisecondsSinceEpoch}',
            produkId: produk.id,
            namaProduk: produk.nama,
            tipe: 'Masuk',
            perubahan: produk.stok,
            stokAkhir: produk.stok,
            keterangan: 'Stok Awal Master Produk',
            olehStaff: _currentStaff?.nama ?? 'Store Information System',
            tanggal: DateTime.now(),
          ),
        );
      } else {
        final idx = _daftarProduk.indexWhere((p) => p.id == produk.id);
        if (idx != -1) _daftarProduk[idx] = produk;
      }
    });
    _storage.simpanProduk(_daftarProduk);
    _storage.simpanLogStok(_daftarLogStok);
    _info(isBaru ? 'Produk baru ditambahkan.' : 'Data produk diperbarui.');
  }

  void _hapusProduk(String id) {
    setState(() {
      _daftarProduk.removeWhere((p) => p.id == id);
      _keranjang.remove(id);
    });
    _storage.simpanProduk(_daftarProduk);
    _info('Produk dihapus dari katalog.');
  }

  void _mutasiStok({
    required Produk produk,
    required String tipe,
    required int perubahan,
    required String keterangan,
  }) {
    final idx = _daftarProduk.indexWhere((p) => p.id == produk.id);
    if (idx == -1) return;
    final stokBaru = (_daftarProduk[idx].stok + perubahan).clamp(0, 999999);
    setState(() {
      _daftarProduk[idx] = _daftarProduk[idx].copyWith(stok: stokBaru);
      _daftarLogStok.insert(
        0,
        LogStok(
          id: 'log_${DateTime.now().millisecondsSinceEpoch}',
          produkId: produk.id,
          namaProduk: produk.nama,
          tipe: tipe,
          perubahan: perubahan,
          stokAkhir: stokBaru,
          keterangan: keterangan,
          olehStaff: _currentStaff?.nama ?? 'Operator',
          tanggal: DateTime.now(),
        ),
      );
    });
    _storage.simpanProduk(_daftarProduk);
    _storage.simpanLogStok(_daftarLogStok);
    _info('Stok ${produk.nama} diperbarui menjadi $stokBaru.');
  }

  // --- KASBON & MEMBER ---
  void _bayarKasbon(TransaksiPos trx, int nominalBayar) {
    final idx = _daftarTransaksi.indexWhere((t) => t.id == trx.id);
    if (idx == -1) return;

    final totalBayarBaru = trx.bayar + nominalBayar;
    final lunas = totalBayarBaru >= trx.totalBelanja;
    final kembalian =
        lunas ? (totalBayarBaru - trx.totalBelanja).clamp(0, nominalBayar) : 0;

    final shift = _shiftAktif;
    if (shift != null) {
      final sIdx = _daftarShift.indexWhere((s) => s.id == shift.id);
      if (sIdx != -1) {
        final masukLaci = nominalBayar - kembalian;
        _daftarShift[sIdx] = shift.copyWith(
          penjualanTunai: shift.penjualanTunai + masukLaci,
        );
      }
    }

    setState(() {
      _daftarTransaksi[idx] = trx.copyWith(
        bayar: totalBayarBaru,
        kembalian: kembalian,
        statusLunas: lunas,
      );
    });
    _storage.simpanTransaksi(_daftarTransaksi);
    _storage.simpanShift(_daftarShift);
    _info(lunas
        ? 'Kasbon ${trx.namaPelanggan} telah LUNAS!'
        : 'Cicilan kasbon dicatat.');
  }

  void _simpanMember(MemberPelanggan member, bool isBaru) {
    setState(() {
      if (isBaru) {
        _daftarMember.insert(0, member);
      } else {
        final idx = _daftarMember.indexWhere((m) => m.id == member.id);
        if (idx != -1) _daftarMember[idx] = member;
      }
    });
    _storage.simpanMember(_daftarMember);
    _info(isBaru ? 'Member baru terdaftar.' : 'Data member diperbarui.');
  }

  void _hapusMember(String id) {
    setState(() => _daftarMember.removeWhere((m) => m.id == id));
    _storage.simpanMember(_daftarMember);
    _info('Member dihapus.');
  }

  // --- SUPER ADMIN ---
  void _tambahPengeluaran(PengeluaranToko item) {
    final shift = _shiftAktif;
    final itemFinal = PengeluaranToko(
      id: item.id,
      shiftId: (item.ambilDariLaciKas && shift != null) ? shift.id : '',
      judul: item.judul,
      kategori: item.kategori,
      nominal: item.nominal,
      ambilDariLaciKas: item.ambilDariLaciKas,
      olehStaff: item.olehStaff,
      tanggal: item.tanggal,
      catatan: item.catatan,
    );

    if (item.ambilDariLaciKas && shift != null) {
      final sIdx = _daftarShift.indexWhere((s) => s.id == shift.id);
      if (sIdx != -1) {
        _daftarShift[sIdx] = shift.copyWith(
          pengeluaranKas: shift.pengeluaranKas + item.nominal,
        );
      }
    }

    setState(() {
      _daftarPengeluaran.insert(0, itemFinal);
    });
    _storage.simpanPengeluaran(_daftarPengeluaran);
    _storage.simpanShift(_daftarShift);
    _info('Pengeluaran toko dicatat.');
  }

  void _hapusPengeluaran(String id) {
    setState(() => _daftarPengeluaran.removeWhere((e) => e.id == id));
    _storage.simpanPengeluaran(_daftarPengeluaran);
    _info('Catatan pengeluaran dihapus.');
  }

  void _simpanStaff(AkunStaff staff, bool isBaru) {
    setState(() {
      if (isBaru) {
        _daftarStaff.add(staff);
      } else {
        final idx = _daftarStaff.indexWhere((s) => s.id == staff.id);
        if (idx != -1) _daftarStaff[idx] = staff;
      }
    });
    _storage.simpanStaff(_daftarStaff);
    _info('Data akun staff disimpan.');
  }

  void _hapusStaff(String id) {
    setState(() => _daftarStaff.removeWhere((s) => s.id == id));
    _storage.simpanStaff(_daftarStaff);
    _info('Akun staff dihapus.');
  }

  void _simpanPromo(PromoVoucher promo, bool isBaru) {
    setState(() {
      if (isBaru) {
        _daftarPromo.insert(0, promo);
      } else {
        final idx = _daftarPromo.indexWhere((p) => p.id == promo.id);
        if (idx != -1) _daftarPromo[idx] = promo;
      }
    });
    _storage.simpanPromo(_daftarPromo);
    _info('Data voucher promo diperbarui.');
  }

  void _hapusPromo(String id) {
    setState(() => _daftarPromo.removeWhere((p) => p.id == id));
    _storage.simpanPromo(_daftarPromo);
    _info('Voucher promo dihapus.');
  }

  void _simpanToko(PengaturanToko tokoBaru) {
    setState(() => _toko = tokoBaru);
    _storage.simpanToko(tokoBaru);
    _info('Pengaturan toko disimpan.');
  }

  void _restoreJson(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      setState(() {
        if (map['toko'] != null) {
          _toko = PengaturanToko.fromMap(map['toko'] as Map<String, dynamic>);
        }
        if (map['staff'] != null) {
          _daftarStaff = (map['staff'] as List)
              .map((e) => AkunStaff.fromMap(e as Map<String, dynamic>))
              .toList();
        }
        if (map['produk'] != null) {
          _daftarProduk = (map['produk'] as List)
              .map((e) => Produk.fromMap(e as Map<String, dynamic>))
              .toList();
        }
        if (map['member'] != null) {
          _daftarMember = (map['member'] as List)
              .map((e) => MemberPelanggan.fromMap(e as Map<String, dynamic>))
              .toList();
        }
        if (map['promo'] != null) {
          _daftarPromo = (map['promo'] as List)
              .map((e) => PromoVoucher.fromMap(e as Map<String, dynamic>))
              .toList();
        }
        if (map['transaksi'] != null) {
          _daftarTransaksi = (map['transaksi'] as List)
              .map((e) => TransaksiPos.fromMap(e as Map<String, dynamic>))
              .toList();
        }
        if (map['pengeluaran'] != null) {
          _daftarPengeluaran = (map['pengeluaran'] as List)
              .map((e) => PengeluaranToko.fromMap(e as Map<String, dynamic>))
              .toList();
        }
      });
      _storage.simpanToko(_toko);
      _storage.simpanStaff(_daftarStaff);
      _storage.simpanProduk(_daftarProduk);
      _storage.simpanMember(_daftarMember);
      _storage.simpanPromo(_daftarPromo);
      _storage.simpanTransaksi(_daftarTransaksi);
      _storage.simpanPengeluaran(_daftarPengeluaran);
      _info('Database berhasil dipulihkan dari JSON.');
    } catch (_) {
      _info('Format JSON backup tidak valid.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tema;

    if (_loading) {
      return Scaffold(
        backgroundColor: t.bgColor,
        body: Center(
          child: CircularProgressIndicator(color: t.primaryColor),
        ),
      );
    }

    if (_currentStaff == null) {
      return LoginShiftScreen(
        tema: cariTemaById(null),
        toko: _toko,
        daftarStaff: _daftarStaff,
        shiftAktif: _shiftAktif,
        onMasukTerminal: _masukTerminal,
      );
    }

    final staff = _currentStaff!;
    if (staff.isStoreSystem) {
      return StoreInformationSystemShell(
        onBayarKasbon: _bayarKasbon,
        tema: cariTemaById(null),
        toko: _toko,
        currentStaff: staff,
        daftarStaff: _daftarStaff,
        daftarShift: _daftarShift,
        daftarProduk: _daftarProduk,
        daftarLogStok: _daftarLogStok,
        daftarMember: _daftarMember,
        daftarPromo: _daftarPromo,
        daftarTransaksi: _daftarTransaksi,
        daftarPengeluaran: _daftarPengeluaran,
        onSimpanProduk: _simpanProduk,
        onHapusProduk: _hapusProduk,
        onMutasiStok: _mutasiStok,
        onSimpanMember: _simpanMember,
        onHapusMember: _hapusMember,
        onTambahPengeluaran: _tambahPengeluaran,
        onHapusPengeluaran: _hapusPengeluaran,
        onSimpanStaff: _simpanStaff,
        onHapusStaff: _hapusStaff,
        onSimpanPromo: _simpanPromo,
        onHapusPromo: _hapusPromo,
        onSimpanToko: _simpanToko,
        onGantiTema: widget.onGantiTema,
        onRestoreJson: _restoreJson,
        onVoidTransaksi: _voidTransaksi,
        onKeluarAkun: () => setState(() => _currentStaff = null),
      );
    }
    final shiftIdAktif = _shiftAktif?.id ?? '';
    final listTrxShift = _daftarTransaksi
        .where((trx) => trx.shiftId == shiftIdAktif)
        .toList();
    final trxTerakhirShift =
        listTrxShift.isNotEmpty ? listTrxShift.first : null;
    return Scaffold(
      backgroundColor: t.bgColor,
      body: SafeArea(
        child: KasirTab(
          tema: cariTemaById(null),
          toko: _toko,
          currentStaff: staff,
          shiftAktif: _shiftAktif,
          daftarProduk: _daftarProduk,
          daftarMember: _daftarMember,
          daftarPromo: _daftarPromo,
          daftarHold: _daftarHold,
          keranjang: _keranjang,
          onUbahQty: _ubahQtyKeranjang,
          onKosongkanKeranjang: () => setState(() => _keranjang.clear()),
          onTahanKeranjang: _tahanKeranjang,
          onPulihkanHold: _pulihkanHold,
          onHapusHold: _hapusHold,
          onSelesaikanTransaksi: _selesaikanTransaksi,
          onTutupShift: _tutupShift,
          onBukaShift: _bukaShift,
          onKunciLayar: () => setState(() => _currentStaff = null),
          strukTerakhir: trxTerakhirShift,
          onCetakUlangStrukTerakhir: trxTerakhirShift == null
              ? null
              : () => tampilkanStrukDigital(
                    context: context,
                    tema: cariTemaById(null),
                    transaksi: trxTerakhirShift,
                    toko: _toko,
                    currentStaff: staff,
                    daftarStaff: _daftarStaff,
                    onVoidTransaksi: () => _voidTransaksi(trxTerakhirShift),
                  ),
        ),
      ),
    );
  }
}
