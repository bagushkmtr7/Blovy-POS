import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../core/utils/pdf_clerek_report.dart';
import '../models/clerek_model.dart';
import '../models/pos_models.dart';
import 'pos_components.dart';

LaporanClerekShift buatDraftClerekDariShift({
  required ShiftKasir shift,
  required String namaOtorisasiTutup,
  required List<TransaksiPos> daftarTransaksi,
  required List<PengeluaranToko> daftarPengeluaran,
  DateTime? waktuTutup,
}) {
  final now = waktuTutup ?? DateTime.now();
  final trxShift = daftarTransaksi.where((trx) {
    final setelahBuka = !trx.tanggal.isBefore(shift.waktuBuka);
    final kasirCocok = trx.namaKasir.trim().toLowerCase() ==
        shift.namaStaff.trim().toLowerCase();
    return setelahBuka && kasirCocok;
  }).toList();

  int tunaiSistem = 0;
  int nonTunaiSistem = 0;
  int kasbonBaruSistem = 0;
  int totalItemTerjual = 0;

  for (final trx in trxShift) {
    for (final it in trx.items) {
      totalItemTerjual += it.qty;
    }
    if (!trx.statusLunas) {
      kasbonBaruSistem +=
          (trx.totalBelanja - trx.bayar).clamp(0, 999999999).toInt();
      if (trx.bayar > 0) {
        if (trx.metodeBayar.toLowerCase().contains('tunai')) {
          tunaiSistem += trx.bayar;
        } else {
          nonTunaiSistem += trx.bayar;
        }
      }
    } else {
      if (trx.metodeBayar.toLowerCase().contains('tunai')) {
        tunaiSistem += trx.totalBelanja;
      } else {
        nonTunaiSistem += trx.totalBelanja;
      }
    }
  }

  if (trxShift.isEmpty &&
      (shift.penjualanTunai > 0 || shift.penjualanNonTunai > 0)) {
    tunaiSistem = shift.penjualanTunai;
    nonTunaiSistem = shift.penjualanNonTunai;
  }

  final expLaciShift = daftarPengeluaran.where((e) {
    return e.ambilDariLaciKas && !e.tanggal.isBefore(shift.waktuBuka);
  }).fold<int>(0, (s, e) => s + e.nominal);

  final pengeluaranSistem =
      expLaciShift > 0 ? expLaciShift : shift.pengeluaranKas;

  final stamp =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

  return LaporanClerekShift(
    shiftId: shift.id,
    nomorClerek: 'CLK-$stamp',
    namaKasir: shift.namaStaff,
    namaOtorisasiTutup: namaOtorisasiTutup,
    waktuBuka: shift.waktuBuka,
    waktuClerek: now,
    statusClerek: 'MENUNGGU_INPUT_SIS',
    modalAwalSistem: shift.modalAwal,
    penjualanTunaiSistem: tunaiSistem,
    penjualanNonTunaiSistem: nonTunaiSistem,
    pengeluaranLaciSistem: pengeluaranSistem,
    kasbonBaruSistem: kasbonBaruSistem,
    jumlahStrukSukses: trxShift.length,
    totalItemTerjual: totalItemTerjual,
  );
}

Future<String?> tampilkanDialogTutupShiftKasir({
  required BuildContext context,
  required AppThemeConfig tema,
  required ShiftKasir shift,
  required List<AkunStaff> daftarStaff,
}) async {
  final pinCtrl = TextEditingController();
  String? pesanError;

  final hasil = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => AlertDialog(
        backgroundColor: tema.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tema.radius + 4),
        ),
        title: Row(
          children: [
            Icon(Icons.lock_clock_rounded, color: tema.dangerColor, size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'CLEREK / TUTUP SHIFT',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Kasir: ${shift.namaStaff}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Shift dibuka: ${formatTanggalWaktu(shift.waktuBuka)}',
              style: TextStyle(fontSize: 11.5, color: tema.textSecondary),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tema.inputColor,
                borderRadius: BorderRadius.circular(tema.radius),
              ),
              child: const Text(
                'Input total uang setoran clerek dilakukan di menu SIS. Di kasir cukup otorisasi PIN Owner / Super untuk mengunci shift.',
                style: TextStyle(fontSize: 11.5),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              maxLength: 4,
              obscureText: true,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'PIN Owner / Super (4 Digit)',
                counterText: '',
                border: OutlineInputBorder(),
              ),
            ),
            if (pesanError != null) ...[
              const SizedBox(height: 6),
              Text(
                pesanError!,
                style: TextStyle(
                  color: tema.dangerColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: tema.dangerColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final pin = pinCtrl.text.trim();
              final otorisasi = daftarStaff.where((s) {
                if (!s.aktif || s.pin != pin) return false;
                final role = s.role.name.toLowerCase();
                return s.isStoreSystem ||
                    role.contains('owner') ||
                    role.contains('super') ||
                    role.contains('admin') ||
                    role.contains('chief') ||
                    role.contains('kepala');
              });
              if (otorisasi.isNotEmpty) {
                Navigator.pop(ctx, otorisasi.first.nama);
                return;
              }
              if (daftarStaff.isEmpty && pin == '1234') {
                Navigator.pop(ctx, 'Owner / Store System');
                return;
              }
              setDlg(() => pesanError = 'PIN Owner / Super tidak valid!');
            },
            icon: const Icon(Icons.check_circle_outline, size: 17),
            label: const Text('Proses Clerek'),
          ),
        ],
      ),
    ),
  );

  pinCtrl.dispose();
  return hasil;
}

Future<LaporanClerekShift?> tampilkanDialogInputSetoranButaSis({
  required BuildContext context,
  required AppThemeConfig tema,
  required LaporanClerekShift draft,
  required List<AkunStaff> daftarStaff,
}) async {
  final totalTunaiCtrl = TextEditingController();
  final modalTinggalCtrl = TextEditingController(text: '0');
  final nonTunaiCtrl = TextEditingController();
  final catatanCtrl = TextEditingController();
  final pinSisCtrl = TextEditingController();
  String? pesanError;

  int parseAngka(String raw) =>
      int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  final hasil = await showModalBottomSheet<LaporanClerekShift>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: tema.surfaceColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(tema.radius + 8)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModal) {
        final fisikTunai = parseAngka(totalTunaiCtrl.text);
        final modalTinggal = parseAngka(modalTinggalCtrl.text);
        final fisikNonTunai = parseAngka(nonTunaiCtrl.text);
        final setorBrankas =
            (fisikTunai - modalTinggal).clamp(0, 999999999);

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 14,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tema.primaryColor.withAlpha(24),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.visibility_off_rounded,
                          color: tema.primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Setoran Clerek • ${draft.nomorClerek}',
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Kasir: ${draft.namaKasir} • ${formatTanggalWaktu(draft.waktuClerek)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: tema.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tema.warningColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(tema.radius),
                      border: Border.all(color: tema.warningColor.withAlpha(80)),
                    ),
                    child: const Text(
                      'VERIFIKASI SETORAN CLEREK: Hitung uang fisik di laci & struk settlement mesin EDC/QRIS lalu masukkan nominalnya di bawah.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: totalTunaiCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    onChanged: (_) => setModal(() {}),
                    style: gayaAngka(
                      const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    decoration: const InputDecoration(
                      labelText: '1. Total Uang Tunai Fisik di Laci *',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: modalTinggalCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setModal(() {}),
                          style: gayaAngka(
                            const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          decoration: const InputDecoration(
                            labelText: '2. Modal Ditinggal Laci',
                            prefixText: 'Rp ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: nonTunaiCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setModal(() {}),
                          style: gayaAngka(
                            const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          decoration: const InputDecoration(
                            labelText: '3. Settlement QRIS/EDC',
                            prefixText: 'Rp ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: tema.primaryColor.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Net Setoran Tunai ke Brankas:',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          formatRupiah(setorBrankas),
                          style: gayaAngka(
                            TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: tema.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: catatanCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Audit (Opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: pinSisCtrl,
                    maxLength: 4,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'PIN Pejabat SIS (4 Digit) *',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (pesanError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      pesanError!,
                      style: TextStyle(
                        color: tema.dangerColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: tema.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final pin = pinSisCtrl.text.trim();
                      final pejabatCocok = daftarStaff.where(
                        (s) => s.aktif && s.isStoreSystem && s.pin == pin,
                      );
                      String? namaPejabat;
                      if (pejabatCocok.isNotEmpty) {
                        namaPejabat = pejabatCocok.first.nama;
                      } else if (daftarStaff.isEmpty && pin == '1234') {
                        namaPejabat = 'Owner / Store System';
                      }
                      if (namaPejabat == null) {
                        setModal(
                          () => pesanError = 'PIN Pejabat SIS tidak valid!',
                        );
                        return;
                      }
                      final locked = draft.salinDenganRekonsiliasi(
                        pejabat: namaPejabat,
                        waktu: DateTime.now(),
                        fisikTunai: fisikTunai,
                        modalTinggal: modalTinggal,
                        qrisFisik: fisikNonTunai,
                        edcFisik: 0,
                        kasbonFisik: draft.kasbonBaruSistem,
                        catatan: catatanCtrl.text.trim(),
                      );
                      await ClerekStorageService.simpan(locked);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx, locked);
                    },
                    icon: const Icon(Icons.lock_rounded, size: 18),
                    label: const Text(
                      'KUNCI SETORAN & BUKA Z-REPORT',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  totalTunaiCtrl.dispose();
  modalTinggalCtrl.dispose();
  nonTunaiCtrl.dispose();
  catatanCtrl.dispose();
  pinSisCtrl.dispose();
  return hasil;
}

Future<void> tampilkanHasilZReportClerek({
  required BuildContext context,
  required AppThemeConfig tema,
  required PengaturanToko toko,
  required LaporanClerekShift laporan,
}) async {
  final statusKlop =
      laporan.selisihTunai == 0 && laporan.selisihNonTunai == 0;
  final statusKurang =
      laporan.selisihTunai < 0 || laporan.selisihNonTunai < 0;
  final warnaStatus = !laporan.sudahDirekonsiliasi
      ? tema.warningColor
      : (statusKlop
          ? tema.successColor
          : (statusKurang ? tema.dangerColor : tema.warningColor));

  String fmtVar(int v) {
    if (v == 0) return 'Rp 0 (KLOP)';
    return '${v > 0 ? '+' : '-'}${formatRupiah(v.abs())}';
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: tema.surfaceColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(tema.radius + 8)),
    ),
    builder: (ctx) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.86,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.fact_check_rounded, color: warnaStatus, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Z-REPORT CLEREK • ${laporan.nomorClerek}',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Kasir: ${laporan.namaKasir} • SIS: ${laporan.namaPejabatRekonsiliasi.isEmpty ? "Belum Input" : laporan.namaPejabatRekonsiliasi}',
                          style: TextStyle(
                            fontSize: 11,
                            color: tema.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(label: laporan.statusRekonsiliasi, color: warnaStatus),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: warnaStatus.withAlpha(22),
                        borderRadius: BorderRadius.circular(tema.radius),
                        border: Border.all(color: warnaStatus.withAlpha(110)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'TOTAL UANG TUNAI FISIK (HASIL CLEREK)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatRupiah(laporan.netSetoranBrankas),
                            style: gayaAngka(
                              TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: warnaStatus,
                              ),
                            ),
                          ),
                          Text(
                            'Kas Seharusnya Sistem: ${formatRupiah(laporan.kasSeharusnyaSistem)} • Selisih: ${fmtVar(laporan.selisihTunai)}',
                            style: gayaAngka(
                              TextStyle(fontSize: 11, color: tema.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: dekorasiKartu(tema),
                      child: Column(
                        children: [
                          _BarisZReport('Modal Awal Laci', formatRupiah(laporan.modalAwalSistem)),
                          _BarisZReport('Penjualan Tunai Sistem', formatRupiah(laporan.penjualanTunaiSistem)),
                          _BarisZReport('Pengeluaran Kas Laci', '-${formatRupiah(laporan.pengeluaranLaciSistem)}'),
                          const Divider(height: 12),
                          _BarisZReport('Kas Seharusnya (Sistem)', formatRupiah(laporan.kasSeharusnyaSistem), tebal: true),
                          _BarisZReport('Total Fisik Tunai (SIS)', formatRupiah(laporan.totalFisikTunai), tebal: true),
                          _BarisZReport(
                            'Selisih Kas Tunai',
                            fmtVar(laporan.selisihTunai),
                            tebal: true,
                            warna: laporan.selisihTunai == 0 ? tema.successColor : tema.dangerColor,
                          ),
                          const Divider(height: 12),
                          _BarisZReport('Settlement QRIS (Fisik)', formatRupiah(laporan.fisikSettlementQris)),
                          _BarisZReport('Settlement EDC / Transfer (Fisik)', formatRupiah(laporan.fisikSettlementEdcTransfer)),
                          _BarisZReport('Total Non-Tunai Sistem', formatRupiah(laporan.penjualanNonTunaiSistem), tebal: true),
                          _BarisZReport(
                            'Selisih Non-Tunai',
                            fmtVar(laporan.selisihNonTunai),
                            tebal: true,
                            warna: laporan.selisihNonTunai == 0 ? tema.successColor : tema.dangerColor,
                          ),
                          const Divider(height: 12),
                          _BarisZReport('Kasbon Baru (Sistem vs Fisik)', '${formatRupiah(laporan.kasbonBaruSistem)} vs ${formatRupiah(laporan.fisikNotaKasbon)}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final teks = '*Z-REPORT ${laporan.nomorClerek}*\nKasir: ${laporan.namaKasir}\nStatus: ${laporan.statusRekonsiliasi}\nKas Sistem: ${formatRupiah(laporan.kasSeharusnyaSistem)}\nFisik Tunai: ${formatRupiah(laporan.totalFisikTunai)}\nSelisih Tunai: ${fmtVar(laporan.selisihTunai)}\nNet Setor Brankas: ${formatRupiah(laporan.netSetoranBrankas)}';
                        await Clipboard.setData(ClipboardData(text: teks));
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Ringkasan Z-Report disalin.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 17),
                      label: const Text('Salin Teks'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: tema.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => unduhPdfLaporanClerek(laporan: laporan, toko: toko),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 17),
                      label: const Text('Unduh PDF'),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup Z-Report'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BarisZReport extends StatelessWidget {
  final String label;
  final String nilai;
  final bool tebal;
  final Color? warna;

  const _BarisZReport(this.label, this.nilai, {this.tebal = false, this.warna});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: tebal ? FontWeight.w800 : FontWeight.w500),
              ),
            ),
            Text(
              nilai,
              style: gayaAngka(
                TextStyle(fontSize: 12, fontWeight: tebal ? FontWeight.w900 : FontWeight.w700, color: warna),
              ),
            ),
          ],
        ),
      );
}
