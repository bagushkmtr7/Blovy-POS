import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../widgets/pos_components.dart';
import '../../widgets/server_sync_badge.dart';

class LoginShiftScreen extends StatefulWidget {
  final AppThemeConfig tema;
  final PengaturanToko toko;
  final List<AkunStaff> daftarStaff;
  final ShiftKasir? shiftAktif;
  final void Function(AkunStaff staff, int? modalAwalShift) onMasukTerminal;

  const LoginShiftScreen({
    super.key,
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
  String _pin = '';
  String? _pesanError;
  late DateTime _sekarang;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    final aktifList = widget.daftarStaff.where((s) => s.aktif).toList();
    _staffDipilih =
        aktifList.isNotEmpty ? aktifList.first : widget.daftarStaff.first;
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
  void dispose() {
    _clockTimer?.cancel();
    _keyboardFocus.dispose();
    super.dispose();
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
        _pesanError = 'PIN tidak sesuai untuk akun ${_staffDipilih.nama}';
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
                  child: Text(
                    'Buka Shift & Laci Kas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: t.inputColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kasir Bertugas: ${staff.nama}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hitung uang tunai modal kembalian di laci sebelum transaksi dimulai.',
                          style: TextStyle(
                            fontSize: 11,
                            color: t.textSecondary,
                          ),
                        ),
                      ],
                    ),
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
                      labelText: 'Modal Awal Laci Kas',
                      prefixText: 'Rp ',
                      helperText: 'Terbaca: ${formatRupiah(nominalPreview)}',
                      filled: true,
                      fillColor: t.inputColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final preset in [0, 100000, 200000, 500000])
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
                  Navigator.pop(ctx);
                  widget.onMasukTerminal(staff, modal);
                },
                icon: const Icon(Icons.lock_open_rounded, size: 17),
                label: const Text(
                  'Buka Shift Sekarang',
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
    final staffAktif = widget.daftarStaff.where((s) => s.aktif).toList();
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
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ServerSyncBadge(tema: t),
                    const SizedBox(height: 10),
                    // Header Terminal POS Komersial + Jam Real-Time
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
                            child: const Icon(
                              Icons.point_of_sale_rounded,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.toko.namaToko,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.toko.alamatToko.isNotEmpty
                                      ? widget.toko.alamatToko
                                      : 'Retail Point of Sale Terminal',
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

                    // Indikator Status Shift & Laci Kasir
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
                                    'Shift Berjalan: ${widget.shiftAktif!.namaStaff}',
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
                              Icons.lock_outline_rounded,
                              size: 17,
                              color: t.warningColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Laci Kasir Tertutup • Login Kasir akan membuka shift baru',
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

                    // Label Pilih Operator
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 2),
                      child: Text(
                        'PILIH AKUN OPERATOR (${staffAktif.length} AKTIF)',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: t.textSecondary,
                        ),
                      ),
                    ),

                    // Kartu Pemilihan Operator (Bebas Overflow)
                    SizedBox(
                      height: 88,
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
                              width: 178,
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
                                            label: st.isStoreSystem
                                                ? 'SIS BACK-OFFICE'
                                                : 'KASIR POS',
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
                                            ? 'Akses Penuh & Audit'
                                            : 'Terminal Penjualan',
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

                    // Panel Input PIN & Numpad Terminal
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: dekorasiKartu(t),
                      child: Column(
                        children: [
                          Text(
                            'Otorisasi PIN • ${_staffDipilih.nama}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _staffDipilih.isStoreSystem
                                ? 'Masuk ke Store Information System (Default: 1234)'
                                : 'Masuk ke Terminal Kasir POS (Default: 1111)',
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
