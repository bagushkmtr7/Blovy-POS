import 'dart:convert';
import '../core/utils/formatters.dart';

const List<String> kAlasanSelisihSO = [
  'Hilang / Shrinkage',
  'Barang Rusak',
  'Kadaluarsa (Expired)',
  'Salah Input / Admin',
  'Lebih Kirim Supplier',
  'Belum Terinput Transaksi',
  'Lainnya',
];

const List<String> kKondisiFisikSO = [
  'Normal',
  'Mendekati ED',
  'Kemasan Rusak',
];

class ItemHitunganSO {
  final String produkId;
  final String kodeSku;
  final String namaProduk;
  final String kategori;
  final String satuan;
  final int stokSistem;
  final int? qtyToko;
  final int? qtyGudang;
  final int? hitunganPertama;
  final bool sudahRecount;
  final int hargaModal;
  final int hargaJual;
  final String alasanSelisih;
  final String kondisiFisik;
  final String catatan;
  final DateTime? waktuHitung;

  const ItemHitunganSO({
    required this.produkId,
    required this.kodeSku,
    required this.namaProduk,
    required this.kategori,
    required this.satuan,
    required this.stokSistem,
    this.qtyToko,
    this.qtyGudang,
    this.hitunganPertama,
    this.sudahRecount = false,
    required this.hargaModal,
    required this.hargaJual,
    this.alasanSelisih = 'Hilang / Shrinkage',
    this.kondisiFisik = 'Normal',
    this.catatan = '',
    this.waktuHitung,
  });

  bool get sudahDihitung => qtyToko != null || qtyGudang != null;

  int? get stokFisik =>
      sudahDihitung ? ((qtyToko ?? 0) + (qtyGudang ?? 0)) : null;

  int get selisihQty => (stokFisik ?? stokSistem) - stokSistem;
  bool get adaSelisih => sudahDihitung && selisihQty != 0;
  int get selisihNilaiHpp => selisihQty * hargaModal;
  int get selisihNilaiJual => selisihQty * hargaJual;

  ItemHitunganSO copyWith({
    int? qtyToko,
    int? qtyGudang,
    bool resetFisik = false,
    int? hitunganPertama,
    bool? sudahRecount,
    String? alasanSelisih,
    String? kondisiFisik,
    String? catatan,
    DateTime? waktuHitung,
  }) {
    return ItemHitunganSO(
      produkId: produkId,
      kodeSku: kodeSku,
      namaProduk: namaProduk,
      kategori: kategori,
      satuan: satuan,
      stokSistem: stokSistem,
      qtyToko: resetFisik ? null : (qtyToko ?? this.qtyToko),
      qtyGudang: resetFisik ? null : (qtyGudang ?? this.qtyGudang),
      hitunganPertama:
          resetFisik ? null : (hitunganPertama ?? this.hitunganPertama),
      sudahRecount: resetFisik ? false : (sudahRecount ?? this.sudahRecount),
      hargaModal: hargaModal,
      hargaJual: hargaJual,
      alasanSelisih: alasanSelisih ?? this.alasanSelisih,
      kondisiFisik: kondisiFisik ?? this.kondisiFisik,
      catatan: catatan ?? this.catatan,
      waktuHitung: resetFisik ? null : (waktuHitung ?? this.waktuHitung),
    );
  }

  Map<String, dynamic> toMap() => {
        'produkId': produkId,
        'kodeSku': kodeSku,
        'namaProduk': namaProduk,
        'kategori': kategori,
        'satuan': satuan,
        'stokSistem': stokSistem,
        'qtyToko': qtyToko,
        'qtyGudang': qtyGudang,
        'hitunganPertama': hitunganPertama,
        'sudahRecount': sudahRecount,
        'hargaModal': hargaModal,
        'hargaJual': hargaJual,
        'alasanSelisih': alasanSelisih,
        'kondisiFisik': kondisiFisik,
        'catatan': catatan,
        'waktuHitung': waktuHitung?.toIso8601String(),
      };

  factory ItemHitunganSO.fromMap(Map<String, dynamic> map) {
    return ItemHitunganSO(
      produkId: map['produkId'] as String? ?? '',
      kodeSku: map['kodeSku'] as String? ?? '',
      namaProduk: map['namaProduk'] as String? ?? '',
      kategori: map['kategori'] as String? ?? 'Lainnya',
      satuan: map['satuan'] as String? ?? 'pcs',
      stokSistem: (map['stokSistem'] as num?)?.toInt() ?? 0,
      qtyToko: (map['qtyToko'] as num?)?.toInt(),
      qtyGudang: (map['qtyGudang'] as num?)?.toInt(),
      hitunganPertama: (map['hitunganPertama'] as num?)?.toInt(),
      sudahRecount: map['sudahRecount'] as bool? ?? false,
      hargaModal: (map['hargaModal'] as num?)?.toInt() ?? 0,
      hargaJual: (map['hargaJual'] as num?)?.toInt() ?? 0,
      alasanSelisih: map['alasanSelisih'] as String? ?? 'Hilang / Shrinkage',
      kondisiFisik: map['kondisiFisik'] as String? ?? 'Normal',
      catatan: map['catatan'] as String? ?? '',
      waktuHitung: map['waktuHitung'] != null
          ? DateTime.tryParse(map['waktuHitung'] as String)
          : null,
    );
  }
}

class SesiStockOpname {
  final String id;
  final String nomorDokumen;
  final String cakupan;
  final String operatorNama;
  final String approverNama;
  final DateTime waktuMulai;
  final DateTime? waktuSelesai;
  final bool terkunciUntukAudit;
  final bool selesai;
  final String catatanUmum;
  final List<ItemHitunganSO> items;

  const SesiStockOpname({
    required this.id,
    required this.nomorDokumen,
    required this.cakupan,
    required this.operatorNama,
    this.approverNama = '',
    required this.waktuMulai,
    this.waktuSelesai,
    this.terkunciUntukAudit = false,
    this.selesai = false,
    this.catatanUmum = '',
    required this.items,
  });

  int get totalSku => items.length;
  int get jumlahDihitung => items.where((e) => e.sudahDihitung).length;
  int get totalUnitFisik =>
      items.fold(0, (s, e) => s + (e.stokFisik ?? 0));
  int get jumlahKondisiKhusus =>
      items.where((e) => e.sudahDihitung && e.kondisiFisik != 'Normal').length;

  int get jumlahCocok =>
      items.where((e) => e.sudahDihitung && e.selisihQty == 0).length;
  int get jumlahSelisih => items.where((e) => e.adaSelisih).length;

  double get persentaseAkurasi {
    if (jumlahDihitung == 0) return 100.0;
    return (jumlahCocok / jumlahDihitung) * 100.0;
  }

  int get totalPlusQty => items
      .where((e) => e.adaSelisih && e.selisihQty > 0)
      .fold(0, (s, e) => s + e.selisihQty);

  int get totalMinusQty => items
      .where((e) => e.adaSelisih && e.selisihQty < 0)
      .fold(0, (s, e) => s + e.selisihQty.abs());

  int get totalPlusHpp => items
      .where((e) => e.adaSelisih && e.selisihQty > 0)
      .fold(0, (s, e) => s + e.selisihNilaiHpp);

  int get totalMinusHpp => items
      .where((e) => e.adaSelisih && e.selisihQty < 0)
      .fold(0, (s, e) => s + e.selisihNilaiHpp.abs());

  int get totalMinusJual => items
      .where((e) => e.adaSelisih && e.selisihQty < 0)
      .fold(0, (s, e) => s + e.selisihNilaiJual.abs());

  int get netSelisihHpp =>
      items.where((e) => e.adaSelisih).fold(0, (s, e) => s + e.selisihNilaiHpp);

  SesiStockOpname copyWith({
    String? approverNama,
    DateTime? waktuSelesai,
    bool? terkunciUntukAudit,
    bool? selesai,
    String? catatanUmum,
    List<ItemHitunganSO>? items,
  }) {
    return SesiStockOpname(
      id: id,
      nomorDokumen: nomorDokumen,
      cakupan: cakupan,
      operatorNama: operatorNama,
      approverNama: approverNama ?? this.approverNama,
      waktuMulai: waktuMulai,
      waktuSelesai: waktuSelesai ?? this.waktuSelesai,
      terkunciUntukAudit: terkunciUntukAudit ?? this.terkunciUntukAudit,
      selesai: selesai ?? this.selesai,
      catatanUmum: catatanUmum ?? this.catatanUmum,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nomorDokumen': nomorDokumen,
        'cakupan': cakupan,
        'operatorNama': operatorNama,
        'approverNama': approverNama,
        'waktuMulai': waktuMulai.toIso8601String(),
        'waktuSelesai': waktuSelesai?.toIso8601String(),
        'terkunciUntukAudit': terkunciUntukAudit,
        'selesai': selesai,
        'catatanUmum': catatanUmum,
        'items': items.map((e) => e.toMap()).toList(),
      };

  factory SesiStockOpname.fromMap(Map<String, dynamic> map) {
    return SesiStockOpname(
      id: map['id'] as String? ?? '',
      nomorDokumen: map['nomorDokumen'] as String? ?? '',
      cakupan: map['cakupan'] as String? ?? 'Full SO Toko',
      operatorNama: map['operatorNama'] as String? ?? '',
      approverNama: map['approverNama'] as String? ?? '',
      waktuMulai: DateTime.tryParse(map['waktuMulai'] as String? ?? '') ??
          DateTime.now(),
      waktuSelesai: map['waktuSelesai'] != null
          ? DateTime.tryParse(map['waktuSelesai'] as String)
          : null,
      terkunciUntukAudit: map['terkunciUntukAudit'] as bool? ?? false,
      selesai: map['selesai'] as bool? ?? false,
      catatanUmum: map['catatanUmum'] as String? ?? '',
      items: (map['items'] as List<dynamic>? ?? [])
          .map((e) => ItemHitunganSO.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String buatTeksBeritaAcara({required bool tampilkanHpp}) {
    final buf = StringBuffer();
    buf.writeln('====================================');
    buf.writeln('  BERITA ACARA STOCK OPNAME (SO)    ');
    buf.writeln('====================================');
    buf.writeln('No. Dokumen  : $nomorDokumen');
    buf.writeln('Cakupan SO   : $cakupan');
    buf.writeln('Metode       : 100% Physical Count');
    buf.writeln('Operator     : $operatorNama');
    if (approverNama.isNotEmpty) {
      buf.writeln('Disahkan     : $approverNama');
    }
    buf.writeln('Mulai        : ${formatTanggalWaktu(waktuMulai)}');
    buf.writeln('Selesai      : ${formatTanggalWaktu(waktuSelesai ?? waktuMulai)}');
    if (catatanUmum.isNotEmpty) {
      buf.writeln('Catatan      : $catatanUmum');
    }
    buf.writeln('------------------------------------');
    buf.writeln('Akurasi SO   : ${persentaseAkurasi.toStringAsFixed(1)}%');
    buf.writeln('SKU Dihitung : $jumlahDihitung / $totalSku SKU');
    buf.writeln('SKU Cocok    : $jumlahCocok SKU');
    buf.writeln('SKU Selisih  : $jumlahSelisih SKU');
    buf.writeln('Total Fisik  : $totalUnitFisik unit');
    if (tampilkanHpp) {
      buf.writeln('------------------------------------');
      buf.writeln('Surplus (+) HPP   : +${formatRupiah(totalPlusHpp)}');
      buf.writeln('Shrinkage (-) HPP : -${formatRupiah(totalMinusHpp)}');
      buf.writeln(
        'Net Selisih Aset  : ${netSelisihHpp >= 0 ? '+' : ''}${formatRupiah(netSelisihHpp)}',
      );
    }
    final listSelisih = items.where((e) => e.adaSelisih).toList();
    if (listSelisih.isNotEmpty) {
      buf.writeln('------------------------------------');
      buf.writeln('RINCIAN SELISIH STOK:');
      for (final item in listSelisih) {
        final tanda = item.selisihQty > 0 ? '+' : '';
        buf.writeln(
          '• ${item.namaProduk} (${item.kodeSku})',
        );
        buf.writeln(
          '  Sistem: ${item.stokSistem} | Fisik: ${item.stokFisik} (Toko:${item.qtyToko ?? 0}, Gdg:${item.qtyGudang ?? 0}) -> $tanda${item.selisihQty} ${item.satuan}',
        );
        buf.writeln(
          '  Alasan: ${item.alasanSelisih}${item.sudahRecount ? ' [Recount]' : ''}',
        );
      }
    }
    buf.writeln('====================================');
    return buf.toString();
  }

  String buatCsvBeritaAcara() {
    final buf = StringBuffer();
    buf.writeln(
      'No_Dokumen,SKU,Nama_Produk,Kategori,Satuan,Stok_Sistem,Fisik_Toko,Fisik_Gudang,Total_Fisik,Hitungan_Awal,Recount,Selisih_Qty,HPP_Satuan,Selisih_Nilai_HPP,Kondisi_Fisik,Alasan_Selisih,Catatan',
    );
    for (final item in items.where((e) => e.sudahDihitung)) {
      final namaAman = '"${item.namaProduk.replaceAll('"', '""')}"';
      final alasanAman = '"${item.alasanSelisih.replaceAll('"', '""')}"';
      final catatanAman = '"${item.catatan.replaceAll('"', '""')}"';
      buf.writeln(
        '$nomorDokumen,${item.kodeSku},$namaAman,${item.kategori},${item.satuan},${item.stokSistem},${item.qtyToko ?? 0},${item.qtyGudang ?? 0},${item.stokFisik ?? 0},${item.hitunganPertama ?? item.stokFisik ?? 0},${item.sudahRecount ? 'Ya' : 'Tidak'},${item.selisihQty},${item.hargaModal},${item.selisihNilaiHpp},${item.kondisiFisik},$alasanAman,$catatanAman',
      );
    }
    return buf.toString();
  }

  static String encodeList(List<SesiStockOpname> list) =>
      jsonEncode(list.map((e) => e.toMap()).toList());

  static List<SesiStockOpname> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => SesiStockOpname.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
