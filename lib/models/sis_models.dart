import 'dart:convert';

class SupplierItem {
  final String id;
  final String nama;
  final String kontak;
  final String telepon;
  final String alamat;
  final int leadTimeHari;
  final String kategoriUtama;
  final bool aktif;

  const SupplierItem({
    required this.id,
    required this.nama,
    this.kontak = '',
    this.telepon = '',
    this.alamat = '',
    this.leadTimeHari = 2,
    this.kategoriUtama = 'Semua',
    this.aktif = true,
  });

  SupplierItem copyWith({
    String? nama,
    String? kontak,
    String? telepon,
    String? alamat,
    int? leadTimeHari,
    String? kategoriUtama,
    bool? aktif,
  }) {
    return SupplierItem(
      id: id,
      nama: nama ?? this.nama,
      kontak: kontak ?? this.kontak,
      telepon: telepon ?? this.telepon,
      alamat: alamat ?? this.alamat,
      leadTimeHari: leadTimeHari ?? this.leadTimeHari,
      kategoriUtama: kategoriUtama ?? this.kategoriUtama,
      aktif: aktif ?? this.aktif,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nama': nama,
        'kontak': kontak,
        'telepon': telepon,
        'alamat': alamat,
        'leadTimeHari': leadTimeHari,
        'kategoriUtama': kategoriUtama,
        'aktif': aktif,
      };

  factory SupplierItem.fromMap(Map<String, dynamic> map) => SupplierItem(
        id: map['id']?.toString() ?? '',
        nama: map['nama']?.toString() ?? '',
        kontak: map['kontak']?.toString() ?? '',
        telepon: map['telepon']?.toString() ?? '',
        alamat: map['alamat']?.toString() ?? '',
        leadTimeHari: (map['leadTimeHari'] as num?)?.toInt() ?? 2,
        kategoriUtama: map['kategoriUtama']?.toString() ?? 'Semua',
        aktif: map['aktif'] != false,
      );

  static String encodeList(List<SupplierItem> list) =>
      jsonEncode(list.map((e) => e.toMap()).toList());

  static List<SupplierItem> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => SupplierItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}

class ItemPurchaseOrder {
  final String produkId;
  final String kodeSku;
  final String namaProduk;
  final String satuan;
  final int stokSaatOrder;
  final int qtyOrder;
  final int hargaBeliSatuan;

  const ItemPurchaseOrder({
    required this.produkId,
    required this.kodeSku,
    required this.namaProduk,
    required this.satuan,
    required this.stokSaatOrder,
    required this.qtyOrder,
    required this.hargaBeliSatuan,
  });

  int get subtotal => qtyOrder * hargaBeliSatuan;

  Map<String, dynamic> toMap() => {
        'produkId': produkId,
        'kodeSku': kodeSku,
        'namaProduk': namaProduk,
        'satuan': satuan,
        'stokSaatOrder': stokSaatOrder,
        'qtyOrder': qtyOrder,
        'hargaBeliSatuan': hargaBeliSatuan,
      };

  factory ItemPurchaseOrder.fromMap(Map<String, dynamic> map) =>
      ItemPurchaseOrder(
        produkId: map['produkId']?.toString() ?? '',
        kodeSku: map['kodeSku']?.toString() ?? '',
        namaProduk: map['namaProduk']?.toString() ?? '',
        satuan: map['satuan']?.toString() ?? 'pcs',
        stokSaatOrder: (map['stokSaatOrder'] as num?)?.toInt() ?? 0,
        qtyOrder: (map['qtyOrder'] as num?)?.toInt() ?? 0,
        hargaBeliSatuan: (map['hargaBeliSatuan'] as num?)?.toInt() ?? 0,
      );
}

class PurchaseOrderSis {
  final String id;
  final String nomorPo;
  final String supplierId;
  final String namaSupplier;
  final DateTime tanggalOrder;
  final DateTime estimasiTiba;
  final String status; // Draft, Dikirim, Diterima
  final String catatan;
  final String dibuatOleh;
  final List<ItemPurchaseOrder> items;

  const PurchaseOrderSis({
    required this.id,
    required this.nomorPo,
    required this.supplierId,
    required this.namaSupplier,
    required this.tanggalOrder,
    required this.estimasiTiba,
    this.status = 'Draft',
    this.catatan = '',
    required this.dibuatOleh,
    required this.items,
  });

  int get totalQty => items.fold<int>(0, (s, e) => s + e.qtyOrder);
  int get totalNilaiHpp => items.fold<int>(0, (s, e) => s + e.subtotal);

  PurchaseOrderSis copyWith({
    String? status,
    String? catatan,
    List<ItemPurchaseOrder>? items,
  }) {
    return PurchaseOrderSis(
      id: id,
      nomorPo: nomorPo,
      supplierId: supplierId,
      namaSupplier: namaSupplier,
      tanggalOrder: tanggalOrder,
      estimasiTiba: estimasiTiba,
      status: status ?? this.status,
      catatan: catatan ?? this.catatan,
      dibuatOleh: dibuatOleh,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nomorPo': nomorPo,
        'supplierId': supplierId,
        'namaSupplier': namaSupplier,
        'tanggalOrder': tanggalOrder.toIso8601String(),
        'estimasiTiba': estimasiTiba.toIso8601String(),
        'status': status,
        'catatan': catatan,
        'dibuatOleh': dibuatOleh,
        'items': items.map((e) => e.toMap()).toList(),
      };

  factory PurchaseOrderSis.fromMap(Map<String, dynamic> map) =>
      PurchaseOrderSis(
        id: map['id']?.toString() ?? '',
        nomorPo: map['nomorPo']?.toString() ?? '',
        supplierId: map['supplierId']?.toString() ?? '',
        namaSupplier: map['namaSupplier']?.toString() ?? '',
        tanggalOrder: DateTime.tryParse(map['tanggalOrder']?.toString() ?? '') ??
            DateTime.now(),
        estimasiTiba: DateTime.tryParse(map['estimasiTiba']?.toString() ?? '') ??
            DateTime.now(),
        status: map['status']?.toString() ?? 'Draft',
        catatan: map['catatan']?.toString() ?? '',
        dibuatOleh: map['dibuatOleh']?.toString() ?? '',
        items: (map['items'] as List<dynamic>? ?? [])
            .map((e) => ItemPurchaseOrder.fromMap(e as Map<String, dynamic>))
            .toList(),
      );

  static String encodeList(List<PurchaseOrderSis> list) =>
      jsonEncode(list.map((e) => e.toMap()).toList());

  static List<PurchaseOrderSis> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => PurchaseOrderSis.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}

class ItemBadStock {
  final String produkId;
  final String kodeSku;
  final String namaProduk;
  final String satuan;
  final int qty;
  final int hargaModalSatuan;
  final String kondisi;

  const ItemBadStock({
    required this.produkId,
    required this.kodeSku,
    required this.namaProduk,
    required this.satuan,
    required this.qty,
    required this.hargaModalSatuan,
    this.kondisi = 'Rusak / Pecah',
  });

  int get totalNilaiHpp => qty * hargaModalSatuan;

  Map<String, dynamic> toMap() => {
        'produkId': produkId,
        'kodeSku': kodeSku,
        'namaProduk': namaProduk,
        'satuan': satuan,
        'qty': qty,
        'hargaModalSatuan': hargaModalSatuan,
        'kondisi': kondisi,
      };

  factory ItemBadStock.fromMap(Map<String, dynamic> map) => ItemBadStock(
        produkId: map['produkId']?.toString() ?? '',
        kodeSku: map['kodeSku']?.toString() ?? '',
        namaProduk: map['namaProduk']?.toString() ?? '',
        satuan: map['satuan']?.toString() ?? 'pcs',
        qty: (map['qty'] as num?)?.toInt() ?? 0,
        hargaModalSatuan: (map['hargaModalSatuan'] as num?)?.toInt() ?? 0,
        kondisi: map['kondisi']?.toString() ?? 'Rusak / Pecah',
      );
}

class DokumenBadStock {
  final String id;
  final String nomorDokumen;
  final String jenis; // Retur Supplier | Pemusnahan Bad Stock
  final String namaSupplier;
  final String alasanUtama;
  final DateTime tanggal;
  final String operatorNama;
  final String catatan;
  final List<ItemBadStock> items;

  const DokumenBadStock({
    required this.id,
    required this.nomorDokumen,
    required this.jenis,
    this.namaSupplier = '',
    required this.alasanUtama,
    required this.tanggal,
    required this.operatorNama,
    this.catatan = '',
    required this.items,
  });

  int get totalUnit => items.fold<int>(0, (s, e) => s + e.qty);
  int get totalKerugianHpp => items.fold<int>(0, (s, e) => s + e.totalNilaiHpp);

  Map<String, dynamic> toMap() => {
        'id': id,
        'nomorDokumen': nomorDokumen,
        'jenis': jenis,
        'namaSupplier': namaSupplier,
        'alasanUtama': alasanUtama,
        'tanggal': tanggal.toIso8601String(),
        'operatorNama': operatorNama,
        'catatan': catatan,
        'items': items.map((e) => e.toMap()).toList(),
      };

  factory DokumenBadStock.fromMap(Map<String, dynamic> map) => DokumenBadStock(
        id: map['id']?.toString() ?? '',
        nomorDokumen: map['nomorDokumen']?.toString() ?? '',
        jenis: map['jenis']?.toString() ?? 'Pemusnahan Bad Stock',
        namaSupplier: map['namaSupplier']?.toString() ?? '',
        alasanUtama: map['alasanUtama']?.toString() ?? 'Rusak / Pecah',
        tanggal: DateTime.tryParse(map['tanggal']?.toString() ?? '') ??
            DateTime.now(),
        operatorNama: map['operatorNama']?.toString() ?? '',
        catatan: map['catatan']?.toString() ?? '',
        items: (map['items'] as List<dynamic>? ?? [])
            .map((e) => ItemBadStock.fromMap(e as Map<String, dynamic>))
            .toList(),
      );

  static String encodeList(List<DokumenBadStock> list) =>
      jsonEncode(list.map((e) => e.toMap()).toList());

  static List<DokumenBadStock> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => DokumenBadStock.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}

class BatchKedaluwarsa {
  final String id;
  final String produkId;
  final String kodeSku;
  final String namaProduk;
  final String satuan;
  final int qtyBatch;
  final DateTime tanggalExpired;
  final String nomorBatch;
  final String catatan;

  const BatchKedaluwarsa({
    required this.id,
    required this.produkId,
    required this.kodeSku,
    required this.namaProduk,
    required this.satuan,
    required this.qtyBatch,
    required this.tanggalExpired,
    this.nomorBatch = '',
    this.catatan = '',
  });

  int get sisaHari {
    final now = DateTime.now();
    final hariIni = DateTime(now.year, now.month, now.day);
    final target = DateTime(
      tanggalExpired.year,
      tanggalExpired.month,
      tanggalExpired.day,
    );
    return target.difference(hariIni).inDays;
  }

  bool get sudahExpired => sisaHari < 0;
  bool get kritis7Hari => sisaHari >= 0 && sisaHari <= 7;
  bool get waspada30Hari => sisaHari > 7 && sisaHari <= 30;

  Map<String, dynamic> toMap() => {
        'id': id,
        'produkId': produkId,
        'kodeSku': kodeSku,
        'namaProduk': namaProduk,
        'satuan': satuan,
        'qtyBatch': qtyBatch,
        'tanggalExpired': tanggalExpired.toIso8601String(),
        'nomorBatch': nomorBatch,
        'catatan': catatan,
      };

  factory BatchKedaluwarsa.fromMap(Map<String, dynamic> map) =>
      BatchKedaluwarsa(
        id: map['id']?.toString() ?? '',
        produkId: map['produkId']?.toString() ?? '',
        kodeSku: map['kodeSku']?.toString() ?? '',
        namaProduk: map['namaProduk']?.toString() ?? '',
        satuan: map['satuan']?.toString() ?? 'pcs',
        qtyBatch: (map['qtyBatch'] as num?)?.toInt() ?? 0,
        tanggalExpired:
            DateTime.tryParse(map['tanggalExpired']?.toString() ?? '') ??
                DateTime.now().add(const Duration(days: 30)),
        nomorBatch: map['nomorBatch']?.toString() ?? '',
        catatan: map['catatan']?.toString() ?? '',
      );

  static String encodeList(List<BatchKedaluwarsa> list) =>
      jsonEncode(list.map((e) => e.toMap()).toList());

  static List<BatchKedaluwarsa> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => BatchKedaluwarsa.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
