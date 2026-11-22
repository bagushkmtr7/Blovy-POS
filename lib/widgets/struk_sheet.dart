import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/pos_models.dart';
import 'pos_components.dart';

void tampilkanStrukDigital({
  required BuildContext context,
  required AppThemeConfig tema,
  required TransaksiPos transaksi,
  required PengaturanToko toko,
  required AkunStaff currentStaff,
  required List<AkunStaff> daftarStaff,
  VoidCallback? onVoidTransaksi,
}) {
  const kertasThermal = Color(0xFFFCFBF7);
  const tintaHitam = Color(0xFF111827);
  const tintaAbu = Color(0xFF4B5563);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: tema.surfaceColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(tema.radius + 4)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(110),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: tema.primaryColor),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Preview Struk Thermal',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                StatusBadge(
                  label: transaksi.statusLunas ? 'LUNAS' : 'KASBON',
                  color: transaksi.statusLunas
                      ? tema.successColor
                      : tema.warningColor,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Kertas Struk Thermal Bergerigi Atas-Bawah
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(35),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipPath(
                    clipper: _SerratedReceiptClipper(toothWidth: 10, toothHeight: 5),
                    child: Container(
                      color: kertasThermal,
                      padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
                      child: DefaultTextStyle(
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: tintaHitam,
                          fontSize: 12,
                          height: 1.35,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              toko.namaToko.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 0.8,
                              ),
                            ),
                            if (toko.alamatToko.isNotEmpty)
                              Text(
                                toko.alamatToko,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: tintaAbu,
                                ),
                              ),
                            if (toko.teleponToko.isNotEmpty)
                              Text(
                                'TELP: ${toko.teleponToko}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: tintaAbu,
                                ),
                              ),
                            const _GarisPutusThermal(),
                            _BarisThermal('NO.STRUK', transaksi.nomorStruk),
                            _BarisThermal(
                              'TANGGAL',
                              formatTanggalWaktu(transaksi.tanggal),
                            ),
                            _BarisThermal('KASIR', transaksi.namaKasir),
                            _BarisThermal('PELANGGAN', transaksi.namaPelanggan),
                            const _GarisPutusThermal(),

                            // Daftar Item
                            ...transaksi.items.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item.namaProduk}${item.hargaGrosirTerpakai ? ' [GROSIR]' : ''}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '  ${item.qty} ${item.satuan} x ${formatRupiah(item.hargaJual)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: tintaAbu,
                                          ),
                                        ),
                                        Text(
                                          formatRupiah(item.subtotal),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const _GarisPutusThermal(),

                            _BarisThermal(
                              'SUBTOTAL',
                              formatRupiah(transaksi.subtotal),
                            ),
                            if (transaksi.diskon > 0)
                              _BarisThermal(
                                transaksi.kodePromo.isNotEmpty
                                    ? 'DISKON (${transaksi.kodePromo})'
                                    : 'DISKON',
                                '-${formatRupiah(transaksi.diskon)}',
                              ),
                            if (transaksi.poinDipakai > 0)
                              _BarisThermal(
                                'TUKAR POIN',
                                '${transaksi.poinDipakai} PTS',
                              ),
                            if (transaksi.serviceCharge > 0)
                              _BarisThermal(
                                'SERVICE',
                                '+${formatRupiah(transaksi.serviceCharge)}',
                              ),
                            if (transaksi.pajak > 0)
                              _BarisThermal(
                                'PAJAK / PPN',
                                '+${formatRupiah(transaksi.pajak)}',
                              ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'TOTAL',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  formatRupiah(transaksi.totalBelanja),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const _GarisPutusThermal(),
                            _BarisThermal(
                              'METODE BAYAR',
                              transaksi.metodeBayar.toUpperCase(),
                            ),
                            _BarisThermal(
                              'DITERIMA',
                              formatRupiah(transaksi.bayar),
                            ),
                            if (transaksi.statusLunas)
                              _BarisThermal(
                                'KEMBALIAN',
                                formatRupiah(transaksi.kembalian),
                                tebal: true,
                              )
                            else
                              _BarisThermal(
                                'SISA KASBON',
                                formatRupiah(transaksi.sisaPiutang),
                                tebal: true,
                              ),
                            if (transaksi.poinDidapat > 0) ...[
                              const SizedBox(height: 4),
                              _BarisThermal(
                                'POIN DIDAPAT',
                                '+${transaksi.poinDidapat} PTS',
                              ),
                            ],
                            const _GarisPutusThermal(),
                            if (toko.catatanStruk.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  toko.catatanStruk,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: tintaAbu,
                                  ),
                                ),
                              ),

                            // Barcode Visual Nomor Struk
                            SizedBox(
                              height: 36,
                              child: CustomPaint(
                                painter: _BarcodeReceiptPainter(
                                  kode: transaksi.nomorStruk,
                                  warna: tintaHitam,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '* ${transaksi.nomorStruk} *',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.5,
                                color: tintaAbu,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tombol Aksi
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(tema.radius),
                      ),
                    ),
                    onPressed: () async {
                      final teks = buatTeksStruk(transaksi, toko);
                      await Clipboard.setData(ClipboardData(text: teks));
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Teks struk thermal disalin.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Salin Teks Struk'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: tema.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(tema.radius),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Selesai',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            if (onVoidTransaksi != null) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () async {
                  if (!currentStaff.isStoreSystem) {
                    final admin = await tampilkanOtorisasiSis(
                      context: ctx,
                      tema: tema,
                      daftarStaff: daftarStaff,
                      judul: 'Otorisasi Void Transaksi',
                      keterangan:
                          'Pembatalan transaksi oleh Kasir memerlukan PIN Store Information System.',
                    );
                    if (admin == null) return;
                  }
                  if (!ctx.mounted) return;
                  showDialog(
                    context: ctx,
                    builder: (dlgCtx) => AlertDialog(
                      title: const Text('Batalkan (Void) Transaksi?'),
                      content: Text(
                        'Transaksi ${transaksi.nomorStruk} akan dihapus dan stok barang dikembalikan otomatis.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dlgCtx),
                          child: const Text('Batal'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: tema.dangerColor,
                          ),
                          onPressed: () {
                            Navigator.pop(dlgCtx);
                            Navigator.pop(ctx);
                            onVoidTransaksi();
                          },
                          child: const Text('Ya, Void Sekarang'),
                        ),
                      ],
                    ),
                  );
                },
                icon: Icon(
                  Icons.cancel_outlined,
                  size: 17,
                  color: tema.dangerColor,
                ),
                label: Text(
                  currentStaff.isStoreSystem
                      ? 'Batalkan (Void) Transaksi'
                      : 'Void Transaksi (Perlu PIN SIS)',
                  style: TextStyle(color: tema.dangerColor, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _BarisThermal extends StatelessWidget {
  final String kiri;
  final String kanan;
  final bool tebal;

  const _BarisThermal(this.kiri, this.kanan, {this.tebal = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            kiri,
            style: TextStyle(
              fontSize: 11,
              fontWeight: tebal ? FontWeight.w800 : FontWeight.normal,
            ),
          ),
          Text(
            kanan,
            style: TextStyle(
              fontSize: 11,
              fontWeight: tebal ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GarisPutusThermal extends StatelessWidget {
  const _GarisPutusThermal();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final jumlahStrip = (constraints.maxWidth / 6).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              jumlahStrip,
              (_) => Container(
                width: 3.5,
                height: 1,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SerratedReceiptClipper extends CustomClipper<Path> {
  final double toothWidth;
  final double toothHeight;

  const _SerratedReceiptClipper({
    this.toothWidth = 10,
    this.toothHeight = 5,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, toothHeight);

    double x = 0;
    while (x < size.width) {
      path.lineTo(x + toothWidth / 2, 0);
      path.lineTo(x + toothWidth, toothHeight);
      x += toothWidth;
    }

    path.lineTo(size.width, size.height - toothHeight);

    x = size.width;
    while (x > 0) {
      path.lineTo(x - toothWidth / 2, size.height);
      path.lineTo(x - toothWidth, size.height - toothHeight);
      x -= toothWidth;
    }

    path.lineTo(0, toothHeight);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _SerratedReceiptClipper oldClipper) {
    return oldClipper.toothWidth != toothWidth ||
        oldClipper.toothHeight != toothHeight;
  }
}

class _BarcodeReceiptPainter extends CustomPainter {
  final String kode;
  final Color warna;

  const _BarcodeReceiptPainter({
    required this.kode,
    required this.warna,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = warna;
    final units = <int>[];
    for (final codeUnit in kode.codeUnits) {
      units.add((codeUnit % 3) + 1);
      units.add(((codeUnit >> 2) % 2) + 1);
      units.add(((codeUnit >> 4) % 3) + 1);
      units.add(1);
    }

    final totalUnits = units.fold<int>(0, (s, u) => s + u);
    if (totalUnits == 0) return;
    final unitWidth = (size.width * 0.78) / totalUnits;
    double cursorX = size.width * 0.11;

    for (int i = 0; i < units.length; i++) {
      final w = units[i] * unitWidth;
      if (i.isEven) {
        canvas.drawRect(
          Rect.fromLTWH(cursorX, 0, w, size.height),
          paint,
        );
      }
      cursorX += w;
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodeReceiptPainter oldDelegate) {
    return oldDelegate.kode != kode || oldDelegate.warna != warna;
  }
}
