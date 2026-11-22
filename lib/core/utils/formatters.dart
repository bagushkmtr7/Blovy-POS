import '../../models/pos_models.dart';

const List<String> kBulanSingkat = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

const List<String> kKategoriProduk = [
  'Semua',
  'Makanan',
  'Minuman',
  'Sembako',
  'Snack',
  'Produk Segar',
  'Lainnya',
];

const List<String> kSatuanProduk = [
  'pcs',
  'bungkus',
  'botol',
  'cup',
  'kg',
  'liter',
  'dus',
  'renteng',
];

const List<String> kMetodePembayaran = [
  'Tunai',
  'QRIS',
  'Transfer / Debit',
  'Kasbon',
];

const List<String> kKategoriPengeluaran = [
  'Kulakan Stok',
  'Listrik & Air',
  'Plastik & Kemasan',
  'Transportasi',
  'Gaji & Bonus',
  'Operasional',
];

String formatRupiah(int nominal) {
  final negatif = nominal < 0;
  final angka = nominal.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < angka.length; i++) {
    final posisiDariKanan = angka.length - i;
    if (i > 0 && posisiDariKanan % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(angka[i]);
  }
  return '${negatif ? '-Rp ' : 'Rp '}${buffer.toString()}';
}

String formatTanggalWaktu(DateTime dt) {
  final jam = dt.hour.toString().padLeft(2, '0');
  final menit = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} ${kBulanSingkat[dt.month - 1]} ${dt.year}, $jam:$menit';
}

String formatTanggalSaja(DateTime dt) {
  return '${dt.day} ${kBulanSingkat[dt.month - 1]} ${dt.year}';
}

bool isHariIni(DateTime dt) {
  final now = DateTime.now();
  return dt.year == now.year && dt.month == now.month && dt.day == now.day;
}

bool isDalamHariTerakhir(DateTime dt, int hari) {
  final now = DateTime.now();
  final batas = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: hari - 1));
  return !dt.isBefore(batas);
}

bool isBulanIni(DateTime dt) {
  final now = DateTime.now();
  return dt.year == now.year && dt.month == now.month;
}

String buatNomorStruk(int urutan) {
  final now = DateTime.now();
  final kodeTanggal =
      '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  final nomor = (urutan + 1).toString().padLeft(4, '0');
  return 'TRX-$kodeTanggal-$nomor';
}

String buatTeksStruk(TransaksiPos trx, PengaturanToko toko) {
  const garis = '================================';
  const garisTipis = '--------------------------------';
  final buffer = StringBuffer();
  buffer.writeln(toko.namaToko.toUpperCase());
  if (toko.alamatToko.isNotEmpty) buffer.writeln(toko.alamatToko);
  if (toko.teleponToko.isNotEmpty) buffer.writeln('Telp: ${toko.teleponToko}');
  buffer.writeln(garis);
  buffer.writeln('No Struk : ${trx.nomorStruk}');
  buffer.writeln('Tanggal  : ${formatTanggalWaktu(trx.tanggal)}');
  buffer.writeln('Kasir    : ${trx.namaKasir}');
  buffer.writeln('Pelanggan: ${trx.namaPelanggan}');
  buffer.writeln(garisTipis);
  for (final item in trx.items) {
    final tagGrosir = item.hargaGrosirTerpakai ? ' [GROSIR]' : '';
    buffer.writeln('${item.namaProduk}$tagGrosir');
    buffer.writeln(
      '  ${item.qty} ${item.satuan} x ${formatRupiah(item.hargaJual)} = ${formatRupiah(item.subtotal)}',
    );
  }
  buffer.writeln(garisTipis);
  buffer.writeln('Subtotal : ${formatRupiah(trx.subtotal)}');
  if (trx.diskon > 0) {
    final labelPromo =
        trx.kodePromo.isNotEmpty ? ' (${trx.kodePromo})' : '';
    buffer.writeln('Diskon$labelPromo : -${formatRupiah(trx.diskon)}');
  }
  if (trx.poinDipakai > 0) {
    buffer.writeln('Tukar Poin: ${trx.poinDipakai} pts');
  }
  if (trx.serviceCharge > 0) {
    buffer.writeln('Service  : +${formatRupiah(trx.serviceCharge)}');
  }
  if (trx.pajak > 0) {
    buffer.writeln('Pajak    : +${formatRupiah(trx.pajak)}');
  }
  buffer.writeln('TOTAL    : ${formatRupiah(trx.totalBelanja)}');
  buffer.writeln('Metode   : ${trx.metodeBayar}');
  buffer.writeln('Dibayar  : ${formatRupiah(trx.bayar)}');
  if (trx.statusLunas) {
    buffer.writeln('Kembali  : ${formatRupiah(trx.kembalian)}');
    buffer.writeln('Status   : LUNAS');
  } else {
    buffer.writeln('Sisa Hutang: ${formatRupiah(trx.sisaPiutang)}');
    buffer.writeln('Status   : BELUM LUNAS (KASBON)');
  }
  if (trx.poinDidapat > 0) {
    buffer.writeln('Poin Didapat: +${trx.poinDidapat} pts');
  }
  buffer.writeln(garis);
  if (toko.catatanStruk.isNotEmpty) {
    buffer.writeln(toko.catatanStruk);
  }
  return buffer.toString();
}

String buatCsvLaporan(List<TransaksiPos> daftar) {
  final buffer = StringBuffer();
  buffer.writeln(
    'No_Struk,Tanggal,Kasir,Pelanggan,Metode,Status,Subtotal,Diskon,Service,Pajak,Total_Belanja,Modal,Laba_Kotor',
  );
  for (final t in daftar) {
    final pelangganBersih = t.namaPelanggan.replaceAll(',', ' ');
    final kasirBersih = t.namaKasir.replaceAll(',', ' ');
    final status = t.statusLunas ? 'Lunas' : 'Kasbon';
    buffer.writeln(
      '${t.nomorStruk},"${formatTanggalWaktu(t.tanggal)}","$kasirBersih","$pelangganBersih",${t.metodeBayar},$status,${t.subtotal},${t.diskon},${t.serviceCharge},${t.pajak},${t.totalBelanja},${t.totalModal},${t.estimasiLabaKotor}',
    );
  }
  return buffer.toString();
}
