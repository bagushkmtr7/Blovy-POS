import 'package:flutter/material.dart';

class AppThemeConfig {
  final String id;
  final String nama;
  final String deskripsi;
  final bool isDark;
  final Color bgColor;
  final Color surfaceColor;
  final Color inputColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color primaryColor;
  final Color accentColor;
  final Color successColor;
  final Color warningColor;
  final Color dangerColor;
  final double radius;

  const AppThemeConfig({
    required this.id,
    required this.nama,
    required this.deskripsi,
    required this.isDark,
    required this.bgColor,
    required this.surfaceColor,
    required this.inputColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.primaryColor,
    required this.accentColor,
    required this.successColor,
    required this.warningColor,
    required this.dangerColor,
    required this.radius,
  });
}

const List<AppThemeConfig> kDaftarTema = [
  AppThemeConfig(
    id: 'clean_slate',
    nama: 'Clean Slate POS',
    deskripsi: 'Tampilan kasir terang kontras tinggi ala ritel modern',
    isDark: false,
    bgColor: Color(0xFFEEF2F6),
    surfaceColor: Color(0xFFFFFFFF),
    inputColor: Color(0xFFF8FAFC),
    borderColor: Color(0xFFCBD5E1),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    primaryColor: Color(0xFF0F766E),
    accentColor: Color(0xFF1D4ED8),
    successColor: Color(0xFF15803D),
    warningColor: Color(0xFFB45309),
    dangerColor: Color(0xFFB91C1C),
    radius: 8,
  ),
  AppThemeConfig(
    id: 'corporate_navy',
    nama: 'Corporate Navy',
    deskripsi: 'Biru profesional tegas untuk operasional minimarket',
    isDark: false,
    bgColor: Color(0xFFEDF2F7),
    surfaceColor: Color(0xFFFFFFFF),
    inputColor: Color(0xFFF8FAFC),
    borderColor: Color(0xFFCBD5E1),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    primaryColor: Color(0xFF1E3A8A),
    accentColor: Color(0xFF0369A1),
    successColor: Color(0xFF15803D),
    warningColor: Color(0xFFB45309),
    dangerColor: Color(0xFFB91C1C),
    radius: 6,
  ),
  AppThemeConfig(
    id: 'charcoal_pro',
    nama: 'Charcoal Terminal',
    deskripsi: 'Mode gelap redup silau untuk kasir shift malam',
    isDark: true,
    bgColor: Color(0xFF0B0F14),
    surfaceColor: Color(0xFF151C24),
    inputColor: Color(0xFF0F141A),
    borderColor: Color(0xFF263240),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    primaryColor: Color(0xFF10B981),
    accentColor: Color(0xFF38BDF8),
    successColor: Color(0xFF22C55E),
    warningColor: Color(0xFFF59E0B),
    dangerColor: Color(0xFFEF4444),
    radius: 8,
  ),
];

AppThemeConfig cariTemaById(String? id) {
  return kDaftarTema.firstWhere(
    (t) => t.id == id,
    orElse: () => kDaftarTema.first,
  );
}

Color warnaKategori(String kategori) {
  switch (kategori.toLowerCase()) {
    case 'makanan':
      return const Color(0xFFD97706);
    case 'minuman':
      return const Color(0xFF0284C7);
    case 'sembako':
      return const Color(0xFF059669);
    case 'snack':
      return const Color(0xFF7C3AED);
    case 'produk segar':
      return const Color(0xFF16A34A);
    default:
      return const Color(0xFF475569);
  }
}

String inisialProduk(String nama) {
  final bagian = nama
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  if (bagian.isEmpty) return 'PR';
  if (bagian.length == 1) {
    final kata = bagian.first.toUpperCase();
    return kata.length >= 2 ? kata.substring(0, 2) : kata;
  }
  return '${bagian[0][0]}${bagian[1][0]}'.toUpperCase();
}

BoxDecoration dekorasiKartu(
  AppThemeConfig t, {
  Color? borderOverride,
  Color? colorOverride,
}) {
  return BoxDecoration(
    color: colorOverride ?? t.surfaceColor,
    borderRadius: BorderRadius.circular(t.radius),
    border: Border.all(
      color: borderOverride ?? t.borderColor,
      width: 1,
    ),
    boxShadow: t.isDark
        ? null
        : [
            BoxShadow(
              color: const Color(0xFF0F172A).withAlpha(10),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
  );
}

TextStyle gayaAngka(TextStyle base) {
  return base.copyWith(
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
