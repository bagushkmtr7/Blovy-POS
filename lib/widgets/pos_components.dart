import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../models/pos_models.dart';

class TactilePress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const TactilePress({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  State<TactilePress> createState() => _TactilePressState();
}

class _TactilePressState extends State<TactilePress> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        if (widget.onTap != null) setState(() => _pressed = true);
      },
      onTapUp: (_) {
        if (_pressed) setState(() => _pressed = false);
      },
      onTapCancel: () {
        if (_pressed) setState(() => _pressed = false);
      },
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 90),
          child: widget.child,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  final AppThemeConfig tema;
  final String label;
  final String value;
  final String? sublabel;
  final Color? valueColor;
  final IconData? icon;

  const MetricTile({
    super.key,
    required this.tema,
    required this.label,
    required this.value,
    this.sublabel,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: dekorasiKartu(tema),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tema.textSecondary,
                  ),
                ),
              ),
              if (icon != null)
                Icon(icon, size: 16, color: valueColor ?? tema.primaryColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: gayaAngka(
              TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: valueColor ?? tema.textPrimary,
              ),
            ),
          ),
          if (sublabel != null) ...[
            const SizedBox(height: 3),
            Text(
              sublabel!,
              style: TextStyle(fontSize: 11, color: tema.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

Future<AkunStaff?> tampilkanOtorisasiSis({
  required BuildContext context,
  required AppThemeConfig tema,
  required List<AkunStaff> daftarStaff,
  String judul = 'Otorisasi Store Information System',
  String keterangan = 'Masukkan 4 digit PIN Store Information System untuk melanjutkan.',
}) async {
  String pinInput = '';
  String? errorMsg;

  return showDialog<AkunStaff>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) {
        void tekanAngka(String digit) {
          if (pinInput.length >= 4) return;
          HapticFeedback.selectionClick();
          setDlg(() {
            pinInput += digit;
            errorMsg = null;
          });
          if (pinInput.length == 4) {
            final admin = daftarStaff.where(
              (s) => s.aktif && s.isStoreSystem && s.pin == pinInput,
            );
            if (admin.isNotEmpty) {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx, admin.first);
            } else {
              HapticFeedback.heavyImpact();
              setDlg(() {
                pinInput = '';
                errorMsg = 'PIN Store Information System tidak valid';
              });
            }
          }
        }

        return AlertDialog(
          backgroundColor: tema.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tema.radius + 4),
          ),
          title: Row(
            children: [
              Icon(Icons.admin_panel_settings_rounded, color: tema.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  judul,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  keterangan,
                  style: TextStyle(fontSize: 12, color: tema.textSecondary),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final terisi = i < pinInput.length;
                    return Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: terisi ? tema.primaryColor : Colors.transparent,
                        border: Border.all(
                          color: errorMsg != null
                              ? tema.dangerColor
                              : (terisi
                                  ? tema.primaryColor
                                  : tema.borderColor),
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMsg!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tema.dangerColor,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.5,
                  children: [
                    for (final n in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                      _TombolPin(
                        tema: tema,
                        label: n,
                        onTap: () => tekanAngka(n),
                      ),
                    _TombolPin(
                      tema: tema,
                      label: 'C',
                      isSecondary: true,
                      onTap: () => setDlg(() {
                        pinInput = '';
                        errorMsg = null;
                      }),
                    ),
                    _TombolPin(
                      tema: tema,
                      label: '0',
                      onTap: () => tekanAngka('0'),
                    ),
                    _TombolPin(
                      tema: tema,
                      icon: Icons.backspace_outlined,
                      isSecondary: true,
                      onTap: () {
                        if (pinInput.isNotEmpty) {
                          setDlg(() {
                            pinInput =
                                pinInput.substring(0, pinInput.length - 1);
                            errorMsg = null;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Batal'),
            ),
          ],
        );
      },
    ),
  );
}

class _TombolPin extends StatelessWidget {
  final AppThemeConfig tema;
  final String? label;
  final IconData? icon;
  final bool isSecondary;
  final VoidCallback onTap;

  const _TombolPin({
    required this.tema,
    this.label,
    this.icon,
    this.isSecondary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TactilePress(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSecondary ? tema.bgColor : tema.inputColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tema.borderColor),
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, size: 18, color: tema.textSecondary)
            : Text(
                label ?? '',
                style: gayaAngka(
                  TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: tema.textPrimary,
                  ),
                ),
              ),
      ),
    );
  }
}
