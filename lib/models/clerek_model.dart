import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

typedef PetaClerekShift = Map<String, LaporanClerekShift>;

class LaporanClerekShift {
  final String shiftId;
  final String nomorClerek;
  final String namaKasir;
  final String namaOtorisasiTutup;
  final String namaPejabatRekonsiliasi;
  final DateTime waktuBuka;
  final DateTime waktuClerek;
  final DateTime? waktuRekonsiliasi;

  final String statusClerek;

  final int totalFisikTunai;
  final int modalDitinggalLaci;
  final int fisikSettlementQris;
  final int fisikSettlementEdcTransfer;
  final int fisikNotaKasbon;
  final String catatanRekonsiliasi;

  final int modalAwalSistem;
  final int penjualanTunaiSistem;
  final int penjualanNonTunaiSistem;
  final int pengeluaranLaciSistem;
  final int kasbonBaruSistem;
  final int jumlahStrukSukses;
  final int totalItemTerjual;

  const LaporanClerekShift({
    required this.shiftId,
    required this.nomorClerek,
    required this.namaKasir,
    required this.namaOtorisasiTutup,
    this.namaPejabatRekonsiliasi = '',
    required this.waktuBuka,
    required this.waktuClerek,
    this.waktuRekonsiliasi,
    this.statusClerek = 'MENUNGGU_INPUT_SIS',
    this.totalFisikTunai = 0,
    this.modalDitinggalLaci = 0,
    this.fisikSettlementQris = 0,
    this.fisikSettlementEdcTransfer = 0,
    this.fisikNotaKasbon = 0,
    this.catatanRekonsiliasi = '',
    required this.modalAwalSistem,
    required this.penjualanTunaiSistem,
    required this.penjualanNonTunaiSistem,
    required this.pengeluaranLaciSistem,
    required this.kasbonBaruSistem,
    required this.jumlahStrukSukses,
    required this.totalItemTerjual,
  });

  bool get sudahDirekonsiliasi => statusClerek == 'TERKUNCI_ZREPORT';

  int get kasSeharusnyaSistem =>
      modalAwalSistem + penjualanTunaiSistem - pengeluaranLaciSistem;

  int get selisihTunai => totalFisikTunai - kasSeharusnyaSistem;

  int get totalFisikNonTunai =>
      fisikSettlementQris + fisikSettlementEdcTransfer;

  int get selisihNonTunai => totalFisikNonTunai - penjualanNonTunaiSistem;

  int get selisihKasbon => fisikNotaKasbon - kasbonBaruSistem;

  int get totalSelisihGabungan => selisihTunai + selisihNonTunai;

  int get netSetoranBrankas =>
      (totalFisikTunai - modalDitinggalLaci).clamp(0, 999999999);

  int get rataRataKeranjang => jumlahStrukSukses == 0
      ? 0
      : ((penjualanTunaiSistem + penjualanNonTunaiSistem + kasbonBaruSistem) ~/
          jumlahStrukSukses);

  String get statusRekonsiliasi {
    if (!sudahDirekonsiliasi) return 'MENUNGGU INPUT SIS';
    if (selisihTunai == 0 && selisihNonTunai == 0) return 'KLOP / BALANCE';
    if (selisihTunai < 0 || selisihNonTunai < 0) return 'KURANG SETOR (SHORT)';
    return 'LEBIH SETOR (OVER)';
  }

  LaporanClerekShift salinDenganRekonsiliasi({
    required String pejabat,
    required DateTime waktu,
    required int fisikTunai,
    required int modalTinggal,
    required int qrisFisik,
    required int edcFisik,
    required int kasbonFisik,
    String catatan = '',
  }) =>
      LaporanClerekShift(
        shiftId: shiftId,
        nomorClerek: nomorClerek,
        namaKasir: namaKasir,
        namaOtorisasiTutup: namaOtorisasiTutup,
        namaPejabatRekonsiliasi: pejabat,
        waktuBuka: waktuBuka,
        waktuClerek: waktuClerek,
        waktuRekonsiliasi: waktu,
        statusClerek: 'TERKUNCI_ZREPORT',
        totalFisikTunai: fisikTunai,
        modalDitinggalLaci: modalTinggal,
        fisikSettlementQris: qrisFisik,
        fisikSettlementEdcTransfer: edcFisik,
        fisikNotaKasbon: kasbonFisik,
        catatanRekonsiliasi: catatan,
        modalAwalSistem: modalAwalSistem,
        penjualanTunaiSistem: penjualanTunaiSistem,
        penjualanNonTunaiSistem: penjualanNonTunaiSistem,
        pengeluaranLaciSistem: pengeluaranLaciSistem,
        kasbonBaruSistem: kasbonBaruSistem,
        jumlahStrukSukses: jumlahStrukSukses,
        totalItemTerjual: totalItemTerjual,
      );

  Map<String, dynamic> toMap() => {
        'shiftId': shiftId,
        'nomorClerek': nomorClerek,
        'namaKasir': namaKasir,
        'namaOtorisasiTutup': namaOtorisasiTutup,
        'namaPejabatRekonsiliasi': namaPejabatRekonsiliasi,
        'waktuBuka': waktuBuka.toIso8601String(),
        'waktuClerek': waktuClerek.toIso8601String(),
        'waktuRekonsiliasi': waktuRekonsiliasi?.toIso8601String(),
        'statusClerek': statusClerek,
        'totalFisikTunai': totalFisikTunai,
        'modalDitinggalLaci': modalDitinggalLaci,
        'fisikSettlementQris': fisikSettlementQris,
        'fisikSettlementEdcTransfer': fisikSettlementEdcTransfer,
        'fisikNotaKasbon': fisikNotaKasbon,
        'catatanRekonsiliasi': catatanRekonsiliasi,
        'modalAwalSistem': modalAwalSistem,
        'penjualanTunaiSistem': penjualanTunaiSistem,
        'penjualanNonTunaiSistem': penjualanNonTunaiSistem,
        'pengeluaranLaciSistem': pengeluaranLaciSistem,
        'kasbonBaruSistem': kasbonBaruSistem,
        'jumlahStrukSukses': jumlahStrukSukses,
        'totalItemTerjual': totalItemTerjual,
      };

  factory LaporanClerekShift.fromMap(Map<String, dynamic> map) =>
      LaporanClerekShift(
        shiftId: map['shiftId']?.toString() ?? '',
        nomorClerek: map['nomorClerek']?.toString() ?? '',
        namaKasir: map['namaKasir']?.toString() ?? '',
        namaOtorisasiTutup: map['namaOtorisasiTutup']?.toString() ?? '',
        namaPejabatRekonsiliasi:
            map['namaPejabatRekonsiliasi']?.toString() ?? '',
        waktuBuka: DateTime.tryParse(map['waktuBuka']?.toString() ?? '') ??
            DateTime.now(),
        waktuClerek: DateTime.tryParse(map['waktuClerek']?.toString() ?? '') ??
            DateTime.now(),
        waktuRekonsiliasi: map['waktuRekonsiliasi'] == null
            ? null
            : DateTime.tryParse(map['waktuRekonsiliasi'].toString()),
        statusClerek: map['statusClerek']?.toString() ?? 'TERKUNCI_ZREPORT',
        totalFisikTunai: (map['totalFisikTunai'] as num?)?.toInt() ?? 0,
        modalDitinggalLaci: (map['modalDitinggalLaci'] as num?)?.toInt() ?? 0,
        fisikSettlementQris: (map['fisikSettlementQris'] as num?)?.toInt() ?? 0,
        fisikSettlementEdcTransfer:
            (map['fisikSettlementEdcTransfer'] as num?)?.toInt() ?? 0,
        fisikNotaKasbon: (map['fisikNotaKasbon'] as num?)?.toInt() ?? 0,
        catatanRekonsiliasi: map['catatanRekonsiliasi']?.toString() ?? '',
        modalAwalSistem: (map['modalAwalSistem'] as num?)?.toInt() ?? 0,
        penjualanTunaiSistem:
            (map['penjualanTunaiSistem'] as num?)?.toInt() ?? 0,
        penjualanNonTunaiSistem:
            (map['penjualanNonTunaiSistem'] as num?)?.toInt() ?? 0,
        pengeluaranLaciSistem:
            (map['pengeluaranLaciSistem'] as num?)?.toInt() ?? 0,
        kasbonBaruSistem: (map['kasbonBaruSistem'] as num?)?.toInt() ?? 0,
        jumlahStrukSukses: (map['jumlahStrukSukses'] as num?)?.toInt() ?? 0,
        totalItemTerjual: (map['totalItemTerjual'] as num?)?.toInt() ?? 0,
      );
}

class ClerekStorageService {
  static const String _keyClerekMap = 'sis_clerek_zreport_v2';

  static Future<PetaClerekShift> muatSemua() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyClerekMap);
    if (raw == null || raw.isEmpty) return <String, LaporanClerekShift>{};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final hasil = <String, LaporanClerekShift>{};
    for (final entry in decoded.entries) {
      if (entry.value is Map<String, dynamic>) {
        hasil[entry.key] = LaporanClerekShift.fromMap(
          entry.value as Map<String, dynamic>,
        );
      }
    }
    return hasil;
  }

  static Future<void> simpan(LaporanClerekShift laporan) async {
    final prefs = await SharedPreferences.getInstance();
    final semua = await muatSemua();
    semua[laporan.shiftId] = laporan;
    final rawMap = <String, dynamic>{};
    for (final entry in semua.entries) {
      rawMap[entry.key] = entry.value.toMap();
    }
    await prefs.setString(_keyClerekMap, jsonEncode(rawMap));
  }
}
