import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/pdf_clerek_report.dart';
import '../models/clerek_model.dart';
import '../models/pos_models.dart';

LaporanClerekShift buatDraftClerekDariShift({
  required ShiftKasir shift,
  String namaOtorisasiTutup = '',
  List<TransaksiPos> daftarTransaksi = const [],
  List<PengeluaranToko> daftarPengeluaran = const [],
  DateTime? waktuTutup,
  String? namaKasir,
}) {
  final now = waktuTutup ?? DateTime.now();
  final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  final kasirNama = namaKasir ?? shift.namaStaff;
  final otorisasiNama = namaOtorisasiTutup.trim().isNotEmpty ? namaOtorisasiTutup.trim() : kasirNama;
  final trxShift = daftarTransaksi.where((t) => t.shiftId == shift.id).toList();
  final totalItem = trxShift.fold<int>(
    0,
    (acc, t) => acc + t.items.fold<int>(0, (s, it) => s + it.qty.toInt()),
  );
  final kasbonBaru = trxShift
      .where((t) => !t.statusLunas || t.metodeBayar.toLowerCase().contains('kasbon'))
      .fold<int>(0, (acc, t) => acc + (t.totalBelanja - t.bayar).clamp(0, 999999999));
  final pengeluaranShift = daftarPengeluaran.isNotEmpty
      ? daftarPengeluaran
          .where((p) => p.shiftId == shift.id && p.ambilDariLaciKas)
          .fold<int>(0, (acc, p) => acc + p.nominal)
      : shift.pengeluaranKas;

  return LaporanClerekShift(
    shiftId: shift.id,
    nomorClerek: 'CLK-$stamp',
    namaKasir: kasirNama,
    namaOtorisasiTutup: otorisasiNama,
    waktuBuka: shift.waktuBuka,
    waktuClerek: now,
    statusClerek: 'MENUNGGU_INPUT_SIS',
    modalAwalSistem: shift.modalAwal,
    penjualanTunaiSistem: shift.penjualanTunai,
    penjualanNonTunaiSistem: shift.penjualanNonTunai,
    pengeluaranLaciSistem: pengeluaranShift,
    kasbonBaruSistem: kasbonBaru,
    jumlahStrukSukses: trxShift.length,
    totalItemTerjual: totalItem,
    modalDitinggalLaci: shift.modalAwal,
  );
}

Future<String?> tampilkanDialogTutupShiftKasir({
  required BuildContext context,
  required AppThemeConfig tema,
  required ShiftKasir shift,
  List<AkunStaff> daftarStaff = const [],
  PengaturanToko? toko,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Tutup Shift Kasir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      content: Text(
        'Kasir: ${shift.namaStaff}\n'
        'Shift akan ditutup dan diteruskan ke antrean SIS Clerek untuk input fisik tunai.',
        style: const TextStyle(fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(shift.namaStaff),
          child: const Text('Proses Clerek'),
        ),
      ],
    ),
  );
}

String _fmtRpClerek(int nilai) {
  final neg = nilai < 0;
  final s = nilai.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${neg ? '-Rp' : 'Rp'}${buf.toString()}';
}

Future<LaporanClerekShift?> tampilkanDialogInputSetoranButaSis({
  required BuildContext context,
  required AppThemeConfig tema,
  required LaporanClerekShift draft,
  PengaturanToko? toko,
  AkunStaff? currentStaff,
}) {
  return showModalBottomSheet<LaporanClerekShift>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ModalInputSetoranAntiFraud(
      draft: draft,
      toko: toko,
      currentStaff: currentStaff,
    ),
  );
}

class _ModalInputSetoranAntiFraud extends StatefulWidget {
  final LaporanClerekShift draft;
  final PengaturanToko? toko;
  final AkunStaff? currentStaff;

  const _ModalInputSetoranAntiFraud({
    required this.draft,
    this.toko,
    this.currentStaff,
  });

  @override
  State<_ModalInputSetoranAntiFraud> createState() => _ModalInputSetoranAntiFraudState();
}

class _ModalInputSetoranAntiFraudState extends State<_ModalInputSetoranAntiFraud> {
  late String _digits;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _digits = widget.draft.totalFisikTunai > 0 ? widget.draft.totalFisikTunai.toString() : '786500';
  }

  int get _nominalFisik => int.tryParse(_digits) ?? 0;

  void _pressDigit(String d) {
    if (_saving) return;
    setState(() {
      if (_digits == '0') {
        _digits = d;
      } else if (_digits.length < 11) {
        _digits += d;
      }
    });
  }

  void _pressBackspace() {
    if (_saving) return;
    setState(() {
      if (_digits.length <= 1) {
        _digits = '0';
      } else {
        _digits = _digits.substring(0, _digits.length - 1);
      }
    });
  }

  Future<void> _submitSetoran() async {
    if (_saving) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final petugas = (widget.currentStaff?.nama.trim().isNotEmpty ?? false)
        ? widget.currentStaff!.nama.trim()
        : (widget.draft.namaPejabatRekonsiliasi.trim().isNotEmpty)
            ? widget.draft.namaPejabatRekonsiliasi.trim()
            : 'Kasir • Clerk';

    final locked = widget.draft.salinDenganRekonsiliasi(
      pejabat: petugas,
      waktu: now,
      fisikTunai: _nominalFisik,
      modalTinggal: widget.draft.modalDitinggalLaci,
      qrisFisik: widget.draft.penjualanNonTunaiSistem,
      edcFisik: 0,
      kasbonFisik: widget.draft.kasbonBaruSistem,
      catatan: 'Setoran fisik tunai diinput melalui Mode Anti-Fraud SIS Clerek',
    );
    await ClerekStorageService.simpan(locked);
    if (mounted) {
      Navigator.of(context).pop(locked);
    }
  }

  Widget _lockedRow(String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, size: 15, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
            ),
          ),
          const Text(
            '***',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.lock_rounded, size: 13, color: Color(0xFF64748B)),
          const SizedBox(width: 4),
          const Text(
            'Tersembunyi',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _keyTile(String label, {VoidCallback? onTap, Widget? child}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              child: child ??
                  Text(
                    label,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Container(
        margin: EdgeInsets.only(top: 32, bottom: bottomInset),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                      ),
                      const Expanded(
                        child: Text(
                          'SIS Clerek • Step 2 dari 2',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_rounded, size: 13, color: Color(0xFF1D4ED8)),
                            SizedBox(width: 4),
                            Text(
                              'Blovy POS Anti-Fraud',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text(
                      'Mode Anti-Fraud Aktif — Supervisor tidak dapat melihat total sistem & selisih',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF93C5FD)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.verified_user_rounded, size: 20, color: Color(0xFF1D4ED8)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Data sistem dikunci',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Hanya input manual "Total Fisik Tunai" yang dapat diisi untuk keamanan. Total sistem, QRIS, EDC, Kas, dan Selisih disembunyikan.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF), height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Icon(Icons.lock_rounded, size: 15, color: Color(0xFF334155)),
                      SizedBox(width: 6),
                      Text(
                        'Rincian Setoran (Terkunci)',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _lockedRow('QRIS'),
                  _lockedRow('EDC'),
                  _lockedRow('Kas / Sistem'),
                  _lockedRow('Total Setoran Sistem'),
                  _lockedRow('Selisih'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF16A34A), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFF4ADE80),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.sync_rounded, size: 15, color: Color(0xFF052E16)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Total Fisik Tunai (Manual Input)',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF052E16)),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF052E16)),
                                ],
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Masukkan jumlah fisik tunai yang dihitung secara manual',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF052E16)),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _fmtRpClerek(_nominalFisik),
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                  ),
                                ),
                                const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF64748B)),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  _keyTile('1', onTap: () => _pressDigit('1')),
                                  _keyTile('2', onTap: () => _pressDigit('2')),
                                  _keyTile('3', onTap: () => _pressDigit('3')),
                                ],
                              ),
                              Row(
                                children: [
                                  _keyTile('4', onTap: () => _pressDigit('4')),
                                  _keyTile('5', onTap: () => _pressDigit('5')),
                                  _keyTile('6', onTap: () => _pressDigit('6')),
                                ],
                              ),
                              Row(
                                children: [
                                  _keyTile('7', onTap: () => _pressDigit('7')),
                                  _keyTile('8', onTap: () => _pressDigit('8')),
                                  _keyTile('9', onTap: () => _pressDigit('9')),
                                ],
                              ),
                              Row(
                                children: [
                                  _keyTile('.', onTap: () => _pressDigit('00')),
                                  _keyTile('0', onTap: () => _pressDigit('0')),
                                  _keyTile(
                                    'DEL',
                                    onTap: _pressBackspace,
                                    child: const Icon(Icons.backspace_outlined, size: 18, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _saving ? null : _submitSetoran,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Kirim & Selesaikan Setoran',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_rounded, size: 13, color: Color(0xFF64748B)),
                      SizedBox(width: 6),
                      Text(
                        'PIN Supervisor tidak ditampilkan — dienkripsi & disembunyikan',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> tampilkanHasilZReportClerek({
  required BuildContext context,
  required AppThemeConfig tema,
  required LaporanClerekShift laporan,
  PengaturanToko? toko,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ModalZReportFinal(laporan: laporan, toko: toko),
  );
}

class _ModalZReportFinal extends StatelessWidget {
  final LaporanClerekShift laporan;
  final PengaturanToko? toko;

  const _ModalZReportFinal({required this.laporan, this.toko});

  @override
  Widget build(BuildContext context) {
    final selisih = laporan.selisihTunai;
    final selisihLabel = selisih >= 0 ? '+${_fmtRpClerek(selisih)}' : _fmtRpClerek(selisih);
    final statusLabel = selisih == 0 ? 'Seimbang' : (selisih > 0 ? 'Lebih Kasir' : 'Kurang Kasir');
    final wib = laporan.waktuRekonsiliasi ?? laporan.waktuClerek;
    final tglStr = '${wib.day.toString().padLeft(2, '0')}/${wib.month.toString().padLeft(2, '0')}/${wib.year}, ${wib.hour.toString().padLeft(2, '0')}:${wib.minute.toString().padLeft(2, '0')} WIB';
    final penandatangan = laporan.namaPejabatRekonsiliasi.trim().isNotEmpty
        ? laporan.namaPejabatRekonsiliasi.trim()
        : laporan.namaKasir;
    final totalSistemSetoran = laporan.penjualanTunaiSistem + laporan.penjualanNonTunaiSistem;
    final tokoAktif = toko ?? PengaturanToko.defaultAwal();

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: 32),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.chevron_left_rounded, size: 28, color: Color(0xFF0F172A)),
                  ),
                  const Expanded(
                    child: Column(
                      children: [
                        Text(
                          'SIS Clerek',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Langkah 3 dari 3',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        '3/3 Final',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 48,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            value: 1.0,
                            minHeight: 4,
                            backgroundColor: Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF15803D)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF15803D),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_rounded, color: Colors.white, size: 28),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Z-Report Final',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              'Terkunci & Terposting',
                              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Ringkasan Setoran — Final',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.qr_code_2_rounded, size: 18, color: Color(0xFF1E3A8A)),
                                SizedBox(width: 8),
                                Text('QRIS QPC', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            Text(_fmtRpClerek(laporan.penjualanNonTunaiSistem), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.credit_card_rounded, size: 18, color: Color(0xFF2563EB)),
                                SizedBox(width: 8),
                                Text('EDC', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            Text(_fmtRpClerek(laporan.fisikSettlementEdcTransfer), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.payments_outlined, size: 18, color: Color(0xFF0D9488)),
                                SizedBox(width: 8),
                                Text('Kas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            Text(_fmtRpClerek(laporan.totalFisikTunai), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Sistem Total Setoran', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                            Text(
                              _fmtRpClerek(totalSistemSetoran),
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF15803D)),
                                      SizedBox(width: 6),
                                      Text('Selisih', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                                    ],
                                  ),
                                  Text(
                                    '$selisihLabel • $statusLabel',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF15803D)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Selisih $selisihLabel telah disesuaikan. Status: $statusLabel',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Verifikasi QR', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: 96,
                          height: 96,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Icon(Icons.qr_code_2_rounded, size: 76, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pindai untuk verifikasi Z-Report • ID: ${laporan.nomorClerek}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.verified_user_outlined, size: 17, color: Color(0xFF0F172A)),
                            SizedBox(width: 6),
                            Text('Tanda Tangan Digital', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('Ditandatangani secara digital', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                        const SizedBox(height: 4),
                        Text(
                          'Penandatangan: Kasir • Clerk ID: ${laporan.shiftId.toUpperCase()}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                        ),
                        Text(
                          'Waktu: $tglStr',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Ttd: "$penandatangan"',
                            style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        await unduhPdfLaporanClerek(laporan: laporan, toko: tokoAktif);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 19),
                      label: const Text('Selesai & Unduh Z-Report PDF', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final ringkasan = 'Z-REPORT ${laporan.nomorClerek} • Status: $statusLabel • Kasir: $penandatangan • Waktu: $tglStr';
                        await Clipboard.setData(ClipboardData(text: ringkasan));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bukti setoran disalin ke clipboard.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('Bagikan Bukti Setoran', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
