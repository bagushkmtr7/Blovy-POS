enum RoleStaff { storeSystem, kasir }

class AkunStaff {
  final String id;
  final String nama;
  final String pin;
  final RoleStaff role;
  final bool aktif;

  const AkunStaff({
    required this.id,
    required this.nama,
    required this.pin,
    required this.role,
    this.aktif = true,
  });

  bool get isStoreSystem => role == RoleStaff.storeSystem;
  String get labelRole => isStoreSystem ? 'Store Information System' : 'Kasir';

  AkunStaff copyWith({
    String? nama,
    String? pin,
    RoleStaff? role,
    bool? aktif,
  }) {
    return AkunStaff(
      id: id,
      nama: nama ?? this.nama,
      pin: pin ?? this.pin,
      role: role ?? this.role,
      aktif: aktif ?? this.aktif,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nama': nama,
        'pin': pin,
        'role': role.name,
        'aktif': aktif,
      };

  factory AkunStaff.fromMap(Map<String, dynamic> m) {
    final rawRole = (m['role'] as String?) ?? '';
    final namaLower = (m['nama'] as String? ?? '').toLowerCase();
    final isSis = rawRole == 'storeSystem' ||
        rawRole == 'superAdmin' ||
        rawRole == 'sis' ||
        (m['id'] as String?) == 'staff_sis' ||
        namaLower.contains('store information system');
    return AkunStaff(
      id: m['id'] as String,
      nama: m['nama'] as String,
      pin: m['pin'] as String,
      role: isSis ? RoleStaff.storeSystem : RoleStaff.kasir,
      aktif: (m['aktif'] as bool?) ?? true,
    );
  }
}

class ShiftKasir {
  final String id;
  final String staffId;
  final String namaStaff;
  final DateTime waktuBuka;
  final DateTime? waktuTutup;
  final int modalAwal;
  final int penjualanTunai;
  final int penjualanNonTunai;
  final int pengeluaranKas;
  final int kasAktualTutup;
  final bool aktif;

  const ShiftKasir({
    required this.id,
    required this.staffId,
    required this.namaStaff,
    required this.waktuBuka,
    this.waktuTutup,
    required this.modalAwal,
    this.penjualanTunai = 0,
    this.penjualanNonTunai = 0,
    this.pengeluaranKas = 0,
    this.kasAktualTutup = 0,
    this.aktif = true,
  });

  int get kasSeharusnya => modalAwal + penjualanTunai - pengeluaranKas;
  int get selisihKas => kasAktualTutup - kasSeharusnya;

  ShiftKasir copyWith({
    DateTime? waktuTutup,
    int? penjualanTunai,
    int? penjualanNonTunai,
    int? pengeluaranKas,
    int? kasAktualTutup,
    bool? aktif,
  }) {
    return ShiftKasir(
      id: id,
      staffId: staffId,
      namaStaff: namaStaff,
      waktuBuka: waktuBuka,
      waktuTutup: waktuTutup ?? this.waktuTutup,
      modalAwal: modalAwal,
      penjualanTunai: penjualanTunai ?? this.penjualanTunai,
      penjualanNonTunai: penjualanNonTunai ?? this.penjualanNonTunai,
      pengeluaranKas: pengeluaranKas ?? this.pengeluaranKas,
      kasAktualTutup: kasAktualTutup ?? this.kasAktualTutup,
      aktif: aktif ?? this.aktif,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'staffId': staffId,
        'namaStaff': namaStaff,
        'waktuBuka': waktuBuka.toIso8601String(),
        'waktuTutup': waktuTutup?.toIso8601String(),
        'modalAwal': modalAwal,
        'penjualanTunai': penjualanTunai,
        'penjualanNonTunai': penjualanNonTunai,
        'pengeluaranKas': pengeluaranKas,
        'kasAktualTutup': kasAktualTutup,
        'aktif': aktif,
      };

  factory ShiftKasir.fromMap(Map<String, dynamic> m) => ShiftKasir(
        id: m['id'] as String,
        staffId: (m['staffId'] as String?) ?? '',
        namaStaff: (m['namaStaff'] as String?) ?? 'Kasir',
        waktuBuka: DateTime.parse(m['waktuBuka'] as String),
        waktuTutup: m['waktuTutup'] != null
            ? DateTime.parse(m['waktuTutup'] as String)
            : null,
        modalAwal: (m['modalAwal'] as int?) ?? 0,
        penjualanTunai: (m['penjualanTunai'] as int?) ?? 0,
        penjualanNonTunai: (m['penjualanNonTunai'] as int?) ?? 0,
        pengeluaranKas: (m['pengeluaranKas'] as int?) ?? 0,
        kasAktualTutup: (m['kasAktualTutup'] as int?) ?? 0,
        aktif: (m['aktif'] as bool?) ?? false,
      );
}

class Produk {
  final String id;
  final String nama;
  final String kategori;
  final String satuan;
  final int hargaJual;
  final int hargaModal;
  final int hargaGrosir;
  final int minQtyGrosir;
  final int stok;
  final int minStokAlert;
  final String kodeSku;

  const Produk({
    required this.id,
    required this.nama,
    required this.kategori,
    this.satuan = 'pcs',
    required this.hargaJual,
    required this.hargaModal,
    this.hargaGrosir = 0,
    this.minQtyGrosir = 0,
    required this.stok,
    this.minStokAlert = 5,
    required this.kodeSku,
  });

  bool isGrosirAktif(int qty) {
    return hargaGrosir > 0 && minQtyGrosir > 0 && qty >= minQtyGrosir;
  }

  int hargaUntukQty(int qty) {
    return isGrosirAktif(qty) ? hargaGrosir : hargaJual;
  }

  Produk copyWith({
    String? nama,
    String? kategori,
    String? satuan,
    int? hargaJual,
    int? hargaModal,
    int? hargaGrosir,
    int? minQtyGrosir,
    int? stok,
    int? minStokAlert,
    String? kodeSku,
  }) {
    return Produk(
      id: id,
      nama: nama ?? this.nama,
      kategori: kategori ?? this.kategori,
      satuan: satuan ?? this.satuan,
      hargaJual: hargaJual ?? this.hargaJual,
      hargaModal: hargaModal ?? this.hargaModal,
      hargaGrosir: hargaGrosir ?? this.hargaGrosir,
      minQtyGrosir: minQtyGrosir ?? this.minQtyGrosir,
      stok: stok ?? this.stok,
      minStokAlert: minStokAlert ?? this.minStokAlert,
      kodeSku: kodeSku ?? this.kodeSku,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nama': nama,
        'kategori': kategori,
        'satuan': satuan,
        'hargaJual': hargaJual,
        'hargaModal': hargaModal,
        'hargaGrosir': hargaGrosir,
        'minQtyGrosir': minQtyGrosir,
        'stok': stok,
        'minStokAlert': minStokAlert,
        'kodeSku': kodeSku,
      };

  factory Produk.fromMap(Map<String, dynamic> m) => Produk(
        id: m['id'] as String,
        nama: m['nama'] as String,
        kategori: (m['kategori'] as String?) ?? 'Lainnya',
        satuan: (m['satuan'] as String?) ?? 'pcs',
        hargaJual: (m['hargaJual'] as int?) ?? 0,
        hargaModal: (m['hargaModal'] as int?) ?? 0,
        hargaGrosir: (m['hargaGrosir'] as int?) ?? 0,
        minQtyGrosir: (m['minQtyGrosir'] as int?) ?? 0,
        stok: (m['stok'] as int?) ?? 0,
        minStokAlert: (m['minStokAlert'] as int?) ?? 5,
        kodeSku: (m['kodeSku'] as String?) ?? '',
      );
}

class LogStok {
  final String id;
  final String produkId;
  final String namaProduk;
  final String tipe; // Masuk, Keluar, Opname, Void
  final int perubahan;
  final int stokAkhir;
  final String keterangan;
  final String olehStaff;
  final DateTime tanggal;

  const LogStok({
    required this.id,
    required this.produkId,
    required this.namaProduk,
    required this.tipe,
    required this.perubahan,
    required this.stokAkhir,
    required this.keterangan,
    required this.olehStaff,
    required this.tanggal,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'produkId': produkId,
        'namaProduk': namaProduk,
        'tipe': tipe,
        'perubahan': perubahan,
        'stokAkhir': stokAkhir,
        'keterangan': keterangan,
        'olehStaff': olehStaff,
        'tanggal': tanggal.toIso8601String(),
      };

  factory LogStok.fromMap(Map<String, dynamic> m) => LogStok(
        id: m['id'] as String,
        produkId: (m['produkId'] as String?) ?? '',
        namaProduk: (m['namaProduk'] as String?) ?? '',
        tipe: (m['tipe'] as String?) ?? 'Opname',
        perubahan: (m['perubahan'] as int?) ?? 0,
        stokAkhir: (m['stokAkhir'] as int?) ?? 0,
        keterangan: (m['keterangan'] as String?) ?? '',
        olehStaff: (m['olehStaff'] as String?) ?? 'Sistem',
        tanggal: DateTime.parse(m['tanggal'] as String),
      );
}

class ItemKeranjang {
  final Produk produk;
  final int qty;

  const ItemKeranjang({
    required this.produk,
    required this.qty,
  });

  bool get dapatGrosir => produk.isGrosirAktif(qty);
  int get hargaSatuanAktif => produk.hargaUntukQty(qty);
  int get subtotal => hargaSatuanAktif * qty;
  int get totalModal => produk.hargaModal * qty;
}

class KeranjangTertahan {
  final String id;
  final String label;
  final DateTime waktu;
  final Map<String, int> items;

  const KeranjangTertahan({
    required this.id,
    required this.label,
    required this.waktu,
    required this.items,
  });

  int get totalQty => items.values.fold<int>(0, (s, q) => s + q);

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'waktu': waktu.toIso8601String(),
        'items': items,
      };

  factory KeranjangTertahan.fromMap(Map<String, dynamic> m) =>
      KeranjangTertahan(
        id: m['id'] as String,
        label: (m['label'] as String?) ?? 'Antrean',
        waktu: DateTime.parse(m['waktu'] as String),
        items: Map<String, int>.from(m['items'] as Map),
      );
}

class MemberPelanggan {
  final String id;
  final String nama;
  final String telepon;
  final int poin;
  final int totalBelanja;
  final int jumlahKunjungan;

  const MemberPelanggan({
    required this.id,
    required this.nama,
    required this.telepon,
    this.poin = 0,
    this.totalBelanja = 0,
    this.jumlahKunjungan = 0,
  });

  MemberPelanggan copyWith({
    String? nama,
    String? telepon,
    int? poin,
    int? totalBelanja,
    int? jumlahKunjungan,
  }) {
    return MemberPelanggan(
      id: id,
      nama: nama ?? this.nama,
      telepon: telepon ?? this.telepon,
      poin: poin ?? this.poin,
      totalBelanja: totalBelanja ?? this.totalBelanja,
      jumlahKunjungan: jumlahKunjungan ?? this.jumlahKunjungan,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nama': nama,
        'telepon': telepon,
        'poin': poin,
        'totalBelanja': totalBelanja,
        'jumlahKunjungan': jumlahKunjungan,
      };

  factory MemberPelanggan.fromMap(Map<String, dynamic> m) => MemberPelanggan(
        id: m['id'] as String,
        nama: m['nama'] as String,
        telepon: (m['telepon'] as String?) ?? '',
        poin: (m['poin'] as int?) ?? 0,
        totalBelanja: (m['totalBelanja'] as int?) ?? 0,
        jumlahKunjungan: (m['jumlahKunjungan'] as int?) ?? 0,
      );
}

class PromoVoucher {
  final String id;
  final String kode;
  final String nama;
  final bool isPersen;
  final int nilai;
  final int minBelanja;
  final bool aktif;

  const PromoVoucher({
    required this.id,
    required this.kode,
    required this.nama,
    required this.isPersen,
    required this.nilai,
    this.minBelanja = 0,
    this.aktif = true,
  });

  int hitungDiskon(int subtotal) {
    if (!aktif || subtotal < minBelanja) return 0;
    if (isPersen) {
      return ((subtotal * nilai.clamp(0, 100)) / 100).round();
    }
    return nilai.clamp(0, subtotal);
  }

  PromoVoucher copyWith({bool? aktif}) {
    return PromoVoucher(
      id: id,
      kode: kode,
      nama: nama,
      isPersen: isPersen,
      nilai: nilai,
      minBelanja: minBelanja,
      aktif: aktif ?? this.aktif,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'kode': kode,
        'nama': nama,
        'isPersen': isPersen,
        'nilai': nilai,
        'minBelanja': minBelanja,
        'aktif': aktif,
      };

  factory PromoVoucher.fromMap(Map<String, dynamic> m) => PromoVoucher(
        id: m['id'] as String,
        kode: (m['kode'] as String?) ?? '',
        nama: (m['nama'] as String?) ?? '',
        isPersen: (m['isPersen'] as bool?) ?? false,
        nilai: (m['nilai'] as int?) ?? 0,
        minBelanja: (m['minBelanja'] as int?) ?? 0,
        aktif: (m['aktif'] as bool?) ?? true,
      );
}

class ItemTransaksi {
  final String produkId;
  final String namaProduk;
  final String satuan;
  final int hargaJual;
  final int hargaModal;
  final int qty;
  final bool hargaGrosirTerpakai;

  const ItemTransaksi({
    required this.produkId,
    required this.namaProduk,
    this.satuan = 'pcs',
    required this.hargaJual,
    required this.hargaModal,
    required this.qty,
    this.hargaGrosirTerpakai = false,
  });

  int get subtotal => hargaJual * qty;
  int get totalModal => hargaModal * qty;

  Map<String, dynamic> toMap() => {
        'produkId': produkId,
        'namaProduk': namaProduk,
        'satuan': satuan,
        'hargaJual': hargaJual,
        'hargaModal': hargaModal,
        'qty': qty,
        'hargaGrosirTerpakai': hargaGrosirTerpakai,
      };

  factory ItemTransaksi.fromMap(Map<String, dynamic> m) => ItemTransaksi(
        produkId: (m['produkId'] as String?) ?? '',
        namaProduk: m['namaProduk'] as String,
        satuan: (m['satuan'] as String?) ?? 'pcs',
        hargaJual: (m['hargaJual'] as int?) ?? 0,
        hargaModal: (m['hargaModal'] as int?) ?? 0,
        qty: (m['qty'] as int?) ?? 1,
        hargaGrosirTerpakai: (m['hargaGrosirTerpakai'] as bool?) ?? false,
      );
}

class TransaksiPos {
  final String id;
  final String nomorStruk;
  final String shiftId;
  final String namaKasir;
  final DateTime tanggal;
  final List<ItemTransaksi> items;
  final int subtotal;
  final int diskon;
  final String kodePromo;
  final int pajak;
  final int serviceCharge;
  final int totalBelanja;
  final int totalModal;
  final int bayar;
  final int kembalian;
  final String metodeBayar;
  final bool statusLunas;
  final String memberId;
  final String namaPelanggan;
  final int poinDidapat;
  final int poinDipakai;
  final String catatan;

  const TransaksiPos({
    required this.id,
    required this.nomorStruk,
    this.shiftId = '',
    this.namaKasir = 'Kasir',
    required this.tanggal,
    required this.items,
    required this.subtotal,
    required this.diskon,
    this.kodePromo = '',
    this.pajak = 0,
    this.serviceCharge = 0,
    required this.totalBelanja,
    required this.totalModal,
    required this.bayar,
    required this.kembalian,
    required this.metodeBayar,
    this.statusLunas = true,
    this.memberId = '',
    required this.namaPelanggan,
    this.poinDidapat = 0,
    this.poinDipakai = 0,
    this.catatan = '',
  });

  int get estimasiLabaKotor =>
      (totalBelanja - pajak - serviceCharge) - totalModal;

  int get sisaPiutang {
    if (statusLunas) return 0;
    return (totalBelanja - bayar).clamp(0, totalBelanja);
  }

  TransaksiPos copyWith({
    int? bayar,
    int? kembalian,
    bool? statusLunas,
    String? catatan,
  }) {
    return TransaksiPos(
      id: id,
      nomorStruk: nomorStruk,
      shiftId: shiftId,
      namaKasir: namaKasir,
      tanggal: tanggal,
      items: items,
      subtotal: subtotal,
      diskon: diskon,
      kodePromo: kodePromo,
      pajak: pajak,
      serviceCharge: serviceCharge,
      totalBelanja: totalBelanja,
      totalModal: totalModal,
      bayar: bayar ?? this.bayar,
      kembalian: kembalian ?? this.kembalian,
      metodeBayar: metodeBayar,
      statusLunas: statusLunas ?? this.statusLunas,
      memberId: memberId,
      namaPelanggan: namaPelanggan,
      poinDidapat: poinDidapat,
      poinDipakai: poinDipakai,
      catatan: catatan ?? this.catatan,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nomorStruk': nomorStruk,
        'shiftId': shiftId,
        'namaKasir': namaKasir,
        'tanggal': tanggal.toIso8601String(),
        'items': items.map((e) => e.toMap()).toList(),
        'subtotal': subtotal,
        'diskon': diskon,
        'kodePromo': kodePromo,
        'pajak': pajak,
        'serviceCharge': serviceCharge,
        'totalBelanja': totalBelanja,
        'totalModal': totalModal,
        'bayar': bayar,
        'kembalian': kembalian,
        'metodeBayar': metodeBayar,
        'statusLunas': statusLunas,
        'memberId': memberId,
        'namaPelanggan': namaPelanggan,
        'poinDidapat': poinDidapat,
        'poinDipakai': poinDipakai,
        'catatan': catatan,
      };

  factory TransaksiPos.fromMap(Map<String, dynamic> m) {
    final total = (m['totalBelanja'] as int?) ?? 0;
    final sub = (m['subtotal'] as int?) ?? total;
    return TransaksiPos(
      id: m['id'] as String,
      nomorStruk: (m['nomorStruk'] as String?) ?? 'TRX-001',
      shiftId: (m['shiftId'] as String?) ?? '',
      namaKasir: (m['namaKasir'] as String?) ?? 'Kasir',
      tanggal: DateTime.parse(m['tanggal'] as String),
      items: (m['items'] as List<dynamic>)
          .map((e) => ItemTransaksi.fromMap(e as Map<String, dynamic>))
          .toList(),
      subtotal: sub,
      diskon: (m['diskon'] as int?) ?? 0,
      kodePromo: (m['kodePromo'] as String?) ?? '',
      pajak: (m['pajak'] as int?) ?? 0,
      serviceCharge: (m['serviceCharge'] as int?) ?? 0,
      totalBelanja: total,
      totalModal: (m['totalModal'] as int?) ?? 0,
      bayar: (m['bayar'] as int?) ?? 0,
      kembalian: (m['kembalian'] as int?) ?? 0,
      metodeBayar: (m['metodeBayar'] as String?) ?? 'Tunai',
      statusLunas: (m['statusLunas'] as bool?) ?? true,
      memberId: (m['memberId'] as String?) ?? '',
      namaPelanggan: (m['namaPelanggan'] as String?) ?? 'Pelanggan Umum',
      poinDidapat: (m['poinDidapat'] as int?) ?? 0,
      poinDipakai: (m['poinDipakai'] as int?) ?? 0,
      catatan: (m['catatan'] as String?) ?? '',
    );
  }
}

class PengeluaranToko {
  final String id;
  final String shiftId;
  final String judul;
  final String kategori;
  final int nominal;
  final bool ambilDariLaciKas;
  final String olehStaff;
  final DateTime tanggal;
  final String catatan;

  const PengeluaranToko({
    required this.id,
    this.shiftId = '',
    required this.judul,
    required this.kategori,
    required this.nominal,
    this.ambilDariLaciKas = true,
    this.olehStaff = 'Admin',
    required this.tanggal,
    this.catatan = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'shiftId': shiftId,
        'judul': judul,
        'kategori': kategori,
        'nominal': nominal,
        'ambilDariLaciKas': ambilDariLaciKas,
        'olehStaff': olehStaff,
        'tanggal': tanggal.toIso8601String(),
        'catatan': catatan,
      };

  factory PengeluaranToko.fromMap(Map<String, dynamic> m) => PengeluaranToko(
        id: m['id'] as String,
        shiftId: (m['shiftId'] as String?) ?? '',
        judul: m['judul'] as String,
        kategori: (m['kategori'] as String?) ?? 'Operasional',
        nominal: (m['nominal'] as int?) ?? 0,
        ambilDariLaciKas: (m['ambilDariLaciKas'] as bool?) ?? true,
        olehStaff: (m['olehStaff'] as String?) ?? 'Admin',
        tanggal: DateTime.parse(m['tanggal'] as String),
        catatan: (m['catatan'] as String?) ?? '',
      );
}

class PengaturanToko {
  final String namaToko;
  final String alamatToko;
  final String teleponToko;
  final String catatanStruk;
  final int persenPajak;
  final int persenService;
  final int nominalPerPoin;
  final int nilaiTukarPoin;

  const PengaturanToko({
    required this.namaToko,
    required this.alamatToko,
    required this.teleponToko,
    required this.catatanStruk,
    this.persenPajak = 0,
    this.persenService = 0,
    this.nominalPerPoin = 10000,
    this.nilaiTukarPoin = 500,
  });

  factory PengaturanToko.defaultAwal() => const PengaturanToko(
        namaToko: 'Nusantara Retail POS',
        alamatToko: 'Jl. Raya Niaga No. 88',
        teleponToko: '0812-8899-0011',
        catatanStruk: 'Barang yang sudah dibeli tidak dapat ditukar/dikembalikan.',
        persenPajak: 0,
        persenService: 0,
        nominalPerPoin: 10000,
        nilaiTukarPoin: 500,
      );

  PengaturanToko copyWith({
    String? namaToko,
    String? alamatToko,
    String? teleponToko,
    String? catatanStruk,
    int? persenPajak,
    int? persenService,
    int? nominalPerPoin,
    int? nilaiTukarPoin,
  }) {
    return PengaturanToko(
      namaToko: namaToko ?? this.namaToko,
      alamatToko: alamatToko ?? this.alamatToko,
      teleponToko: teleponToko ?? this.teleponToko,
      catatanStruk: catatanStruk ?? this.catatanStruk,
      persenPajak: persenPajak ?? this.persenPajak,
      persenService: persenService ?? this.persenService,
      nominalPerPoin: nominalPerPoin ?? this.nominalPerPoin,
      nilaiTukarPoin: nilaiTukarPoin ?? this.nilaiTukarPoin,
    );
  }

  Map<String, dynamic> toMap() => {
        'namaToko': namaToko,
        'alamatToko': alamatToko,
        'teleponToko': teleponToko,
        'catatanStruk': catatanStruk,
        'persenPajak': persenPajak,
        'persenService': persenService,
        'nominalPerPoin': nominalPerPoin,
        'nilaiTukarPoin': nilaiTukarPoin,
      };

  factory PengaturanToko.fromMap(Map<String, dynamic> m) {
    final def = PengaturanToko.defaultAwal();
    return PengaturanToko(
      namaToko: (m['namaToko'] as String?) ?? def.namaToko,
      alamatToko: (m['alamatToko'] as String?) ?? def.alamatToko,
      teleponToko: (m['teleponToko'] as String?) ?? def.teleponToko,
      catatanStruk: (m['catatanStruk'] as String?) ?? def.catatanStruk,
      persenPajak: (m['persenPajak'] as int?) ?? 0,
      persenService: (m['persenService'] as int?) ?? 0,
      nominalPerPoin: (m['nominalPerPoin'] as int?) ?? 10000,
      nilaiTukarPoin: (m['nilaiTukarPoin'] as int?) ?? 500,
    );
  }
}
