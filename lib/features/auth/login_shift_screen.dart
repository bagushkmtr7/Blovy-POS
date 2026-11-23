import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_mode.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../widgets/pos_components.dart';
import '../../widgets/server_sync_badge.dart';

class LoginShiftScreen extends StatefulWidget {
  final AppTargetMode mode;
  final AppThemeConfig tema;
  final PengaturanToko toko;
  final List<AkunStaff> daftarStaff;
  final ShiftKasir? shiftAktif;
  final void Function(AkunStaff staff, int? modalAwalShift) onMasukTerminal;

  const LoginShiftScreen({
    super.key,
    this.mode = AppTargetMode.all,
    required this.tema,
    required this.toko,
    required this.daftarStaff,
    required this.shiftAktif,
    required this.onMasukTerminal,
  });

  @override
  State<LoginShiftScreen> createState() => _LoginShiftScreenState();
}

class _LoginShiftScreenState extends State<LoginShiftScreen> {
  late AkunStaff _staffDipilih;
  final FocusNode _keyboardFocus = FocusNode();
  final TextEditingController _nikCtrl = TextEditingController();
  String _pin = '';
  String? _pesanError;
  late DateTime _sekarang;
  Timer? _clockTimer;

  List<AkunStaff> get _staffTersaring {
    final list = widget.daftarStaff.where((s) {
      if (!s.aktif) return false;
      if (widget.mode == AppTargetMode.posOnly) {
        return s.role == RoleStaff.kasir;
      }
      if (widget.mode == AppTargetMode.sisOnly) {
        return s.role == RoleStaff.storeSystem;
      }
      return true;
    }).toList();
    if (list.isNotEmpty) return list;
    if (widget.mode == AppTargetMode.posOnly) {
      final nonSis = widget.daftarStaff.where((s) => !s.isStoreSystem).toList();
      if (nonSis.isNotEmpty) return nonSis;
    }
    return widget.daftarStaff;
  }

  String _formatNik(AkunStaff s) {
    final clean = s.id.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length >= 5) return clean;
    return s.id.toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    final tersedia = _staffTersaring;
    _staffDipilih = tersedia.first;
    _sekarang = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _sekarang = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _keyboardFocus.canRequestFocus) {
        _keyboardFocus.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(covariant LoginShiftScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final tersedia = _staffTersaring;
    if (!tersedia.any((s) => s.id == _staffDipilih.id) && tersedia.isNotEmpty) {
      _staffDipilih = tersedia.first;
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _keyboardFocus.dispose();
    _nikCtrl.dispose();
    super.dispose();
  }

  void _cariByNik(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return;
    final cocok = _staffTersaring.where(
      (s) => s.id.toLowerCase().contains(q) || s.nama.toLowerCase().contains(q),
    );
    if (cocok.isNotEmpty) {
      setState(() {
        _staffDipilih = cocok.first;
        _pin = '';
        _pesanError = null;
      });
    }
  }

  void _tekanDigit(String d) {
    if (_pin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _pesanError = null;
    });
    if (_pin.length == 4) {
      _verifikasiPin();
    }
  }

  void _hapusSatuDigit() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _pesanError = null;
    });
  }

  void _verifikasiPin() {
    if (_pin != _staffDipilih.pin) {
      HapticFeedback.heavyImpact();
      setState(() {
        _pin = '';
        _pesanError = 'Otorisasi ditolak: PIN salah untuk ${_staffDipilih.nama}';
      });
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _pin = '');

    if (widget.shiftAktif != null) {
      widget.onMasukTerminal(_staffDipilih, null);
      return;
    }

    _dialogBukaShift(_staffDipilih);
  }

  String _rekomendasiShiftOtomatis() {
    final jam = DateTime.now().hour;
    if (jam >= 6 && jam < 14) return 'Shift 1 (Pagi)';
    if (jam >= 14 && jam < 22) return 'Shift 2 (Siang)';
    return 'Shift 3 (Malam)';
  }

  void _dialogBukaShift(AkunStaff staff) {
    if (staff.isStoreSystem ||
        staff.role.name.toLowerCase().contains('owner') ||
        staff.role.name.toLowerCase().contains('super') ||
        staff.role.name.toLowerCase().contains('admin')) {
      widget.onMasukTerminal(staff, null);
      return;
    }

    final t = widget.tema;
    final modalCtrl = TextEditingController(text: '200000');
    String kassaTerpilih = 'KASSA-01';
    String shiftTerpilih = _rekomendasiShiftOtomatis();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final nominalPreview = int.tryParse(
                modalCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
              ) ??
              0;

          return AlertDialog(
            backgroundColor: t.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(t.radius + 6),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: t.primaryColor.withAlpha(24),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.point_of_sale_rounded,
                    color: t.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registrasi Shift & Kassa',
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Buka laci kasir sebelum transaksi ritel',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: t.inputColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: t.borderColor),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: t.primaryColor.withAlpha(28),
                          child: Text(
                            staff.nama.isNotEmpty ? staff.nama[0].toUpperCase() : 'K',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: t.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                staff.nama,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'NIK: ${_formatNik(staff)} • Kasir Terminal',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: t.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'PILIH TERMINAL KASSA',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: t.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final kassa in ['KASSA-01', 'KASSA-02', 'KASSA-03'])
                        ChoiceChip(
                          label: Text(
                            kassa,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                          ),
                          selected: kassaTerpilih == kassa,
                          onSelected: (_) => setDlg(() => kassaTerpilih = kassa),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'JADWAL SHIFT KERJA',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: t.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final sh in ['Shift 1 (Pagi)', 'Shift 2 (Siang)', 'Shift 3 (Malam)'])
                        ChoiceChip(
                          label: Text(
                            sh,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                          selected: shiftTerpilih == sh,
                          onSelected: (_) => setDlg(() => shiftTerpilih = sh),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: modalCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    onChanged: (_) => setDlg(() {}),
                    style: gayaAngka(
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Modal Awal Laci Kas (Petty Cash)',
                      prefixText: 'Rp ',
                      helperText: 'Terbaca: ${formatRupiah(nominalPreview)}',
                      filled: true,
                      fillColor: t.inputColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final preset in [0, 100000, 200000, 300000, 500000])
                        ActionChip(
                          label: Text(
                            formatRupiah(preset),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () {
                            modalCtrl.text = preset.toString();
                            setDlg(() {});
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: t.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                ),
                onPressed: () {
                  final modal = int.tryParse(
                        modalCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
                      ) ??
                      0;
                  final labelShiftSingkat = shiftTerpilih.split(' ').take(2).join(' ');
                  final staffDenganKassa = staff.copyWith(
                    nama: '${staff.nama} ($kassaTerpilih • $labelShiftSingkat)',
                  );
                  Navigator.pop(ctx);
                  widget.onMasukTerminal(staffDenganKassa, modal);
                },
                icon: const Icon(Icons.lock_open_rounded, size: 17),
                label: const Text(
                  'Buka Laci & Mulai',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tema;
    final staffAktif = _staffTersaring;
    final isSis = widget.mode != AppTargetMode.posOnly && (widget.mode == AppTargetMode.sisOnly || _staffDipilih.isStoreSystem);
    final jamStr =
        '${_sekarang.hour.toString().padLeft(2, '0')}:${_sekarang.minute.toString().padLeft(2, '0')}:${_sekarang.second.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: t.bgColor,
      body: SafeArea(
        child: KeyboardListener(
          focusNode: _keyboardFocus,
          autofocus: false,
          onKeyEvent: (event) {
            if (event is! KeyDownEvent) return;
            final keyLabel = event.character;
            if (keyLabel != null && RegExp(r'^[0-9]$').hasMatch(keyLabel)) {
              _tekanDigit(keyLabel);
            } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
              _hapusSatuDigit();
            }
          },
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ServerSyncBadge(tema: t),
                    const SizedBox(height: 10),
                    // Header Terminal Retail Komersial
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: dekorasiKartu(t),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: t.primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isSis
                                  ? Icons.admin_panel_settings_rounded
                                  : Icons.point_of_sale_rounded,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.toko.namaToko,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: t.primaryColor.withAlpha(22),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isSis ? 'SIS' : 'POS',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          color: t.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.toko.alamatToko.isNotEmpty
                                      ? widget.toko.alamatToko
                                      : (isSis
                                          ? 'Store Information System • Back-Office'
                                          : 'Commercial Retail Point of Sale'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: t.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: t.inputColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: t.borderColor),
                            ),
                            child: Text(
                              jamStr,
                              style: gayaAngka(
                                TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: t.primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Banner Status Shift & Kassa
                    if (widget.shiftAktif != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: dekorasiKartu(
                          t,
                          borderOverride: t.successColor.withAlpha(110),
                          colorOverride: t.successColor.withAlpha(18),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_open_rounded,
                              size: 18,
                              color: t.successColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Shift Aktif: ${widget.shiftAktif!.namaStaff}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: t.successColor,
                                    ),
                                  ),
                                  Text(
                                    'Buka ${formatTanggalWaktu(widget.shiftAktif!.waktuBuka)} • Modal ${formatRupiah(widget.shiftAktif!.modalAwal)}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: t.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: dekorasiKartu(
                          t,
                          borderOverride: t.warningColor.withAlpha(90),
                          colorOverride: t.warningColor.withAlpha(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.point_of_sale_outlined,
                              size: 17,
                              color: t.warningColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isSis
                                    ? 'Mode Back-Office SIS • Login dengan NIK & PIN Supervisor'
                                    : 'Terminal Siap • Pilih NIK Karyawan & masukkan PIN untuk buka shift',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: t.warningColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Pencarian Cepat NIK / Nama Karyawan
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isSis
                                ? 'SUPERVISOR / ADMIN (${staffAktif.length})'
                                : 'PERSONEL KASIR (${staffAktif.length} TERDAFTAR)',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: t.textSecondary,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 155,
                          height: 30,
                          child: TextField(
                            controller: _nikCtrl,
                            onChanged: _cariByNik,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                            decoration: InputDecoration(
                              hintText: 'Cari NIK / Nama...',
                              hintStyle: TextStyle(fontSize: 11, color: t.textSecondary),
                              prefixIcon: const Icon(Icons.badge_outlined, size: 15),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              filled: true,
                              fillColor: t.surfaceColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: t.borderColor),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Kartu Identitas Karyawan (NIK + Nama + Jabatan)
                    SizedBox(
                      height: 92,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: staffAktif.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (ctx, idx) {
                          final st = staffAktif[idx];
                          final selected = st.id == _staffDipilih.id;
                          final roleColor = st.isStoreSystem
                              ? t.primaryColor
                              : t.accentColor;

                          return TactilePress(
                            onTap: () => setState(() {
                              _staffDipilih = st;
                              _pin = '';
                              _pesanError = null;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 186,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 9,
                              ),
                              decoration: dekorasiKartu(
                                t,
                                borderOverride:
                                    selected ? t.primaryColor : t.borderColor,
                                colorOverride: selected
                                    ? t.primaryColor.withAlpha(14)
                                    : t.surfaceColor,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: StatusBadge(
                                            label: 'NIK ${_formatNik(st)}',
                                            color: roleColor,
                                          ),
                                        ),
                                      ),
                                      if (selected)
                                        Icon(
                                          Icons.check_circle_rounded,
                                          size: 17,
                                          color: t.primaryColor,
                                        ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        st.nama,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      Text(
                                        st.isStoreSystem
                                            ? 'Store Manager / SIS'
                                            : 'Cashier Operations',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: t.textSecondary,
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
                    const SizedBox(height: 14),

                    // Panel Input PIN Keamanan
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: dekorasiKartu(t),
                      child: Column(
                        children: [
                          Text(
                            _staffDipilih.nama,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'NIK ${_formatNik(_staffDipilih)} • Masukkan 4 Digit PIN Keamanan',
                            style: TextStyle(
                              fontSize: 11,
                              color: t.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Indikator 4 Digit PIN
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (i) {
                              final filled = i < _pin.length;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                width: 38,
                                height: 42,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                  color: filled
                                      ? t.primaryColor.withAlpha(20)
                                      : t.inputColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _pesanError != null
                                        ? t.dangerColor
                                        : (filled
                                            ? t.primaryColor
                                            : t.borderColor),
                                    width: filled ? 2 : 1.2,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: filled
                                    ? Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: t.primaryColor,
                                        ),
                                      )
                                    : null,
                              );
                            }),
                          ),
                          if (_pesanError != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: t.dangerColor.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _pesanError!,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: t.dangerColor,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Keypad Angka 3x4
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 3,
                            mainAxisSpacing: 9,
                            crossAxisSpacing: 9,
                            childAspectRatio: 1.75,
                            children: [
                              for (final d in [
                                '1',
                                '2',
                                '3',
                                '4',
                                '5',
                                '6',
                                '7',
                                '8',
                                '9',
                              ])
                                _KeyPadItem(
                                  tema: t,
                                  label: d,
                                  onTap: () => _tekanDigit(d),
                                ),
                              _KeyPadItem(
                                tema: t,
                                label: 'CLEAR',
                                isAction: true,
                                onTap: () => setState(() {
                                  _pin = '';
                                  _pesanError = null;
                                }),
                              ),
                              _KeyPadItem(
                                tema: t,
                                label: '0',
                                onTap: () => _tekanDigit('0'),
                              ),
                              _KeyPadItem(
                                tema: t,
                                icon: Icons.backspace_outlined,
                                isAction: true,
                                onTap: _hapusSatuDigit,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyPadItem extends StatelessWidget {
  final AppThemeConfig tema;
  final String? label;
  final IconData? icon;
  final bool isAction;
  final VoidCallback onTap;

  const _KeyPadItem({
    required this.tema,
    this.label,
    this.icon,
    this.isAction = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TactilePress(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isAction ? tema.bgColor : tema.inputColor,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: tema.borderColor),
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, size: 21, color: tema.textSecondary)
            : Text(
                label ?? '',
                style: gayaAngka(
                  TextStyle(
                    fontSize: isAction ? 11.5 : 21,
                    fontWeight: FontWeight.w900,
                    color: isAction ? tema.textSecondary : tema.textPrimary,
                  ),
                ),
              ),
      ),
    );
  }
}
