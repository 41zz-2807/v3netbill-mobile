import 'package:flutter/services.dart';

/// Pembatas digit untuk kolom nominal.
///
/// Disimpan di sini supaya form "buat akun", "topup", dan "tarik" memakai
/// angka yang sama. Batas 8 digit berarti nilai tertinggi 99.999.999; Android
/// sendiri membatasi input nominal jadi 10 digit, jadi 8 masih jauh di bawah.
const int maksDigitNominal = 8;

/// Batas panjang nama member.
///
/// ⚠️ Ini **penjaga tampilan, bukan aturan server**. Backend hanya memeriksa
/// `@IsString() @IsNotEmpty()` dan kolomnya bertipe `text`, jadi nama sepanjang
/// apa pun akan diterima kalau dikirim lewat API. Batas ini ada supaya nama
/// masih muat di kartu daftar dan tidak terpotong di tengah.
///
/// PENTING: nama member adalah kredensial sesi — pelanggan mengetik nama itu
/// untuk mulai sesi (`session.service.ts` mencocokkan `nama`). Karena itu
/// batasnya dipasang di level input (melarang mengetik), **bukan** dipotong
/// diam-diam saat dikirim. Memotong nama akan membuat pelanggan gagal login
/// dengan nama yang mereka lihat sendiri di kartunya.
const int maksKarakterNama = 40;

/// Ambil digit saja dari teks, buang pemisah ribuan dan spasi.
String digitSaja(String teks) => teks.replaceAll(RegExp(r'[^0-9]'), '');

/// Baca nominal dari teks yang mungkin sudah berformat ribuan.
///
/// Mengembalikan `null` kalau bukan angka, supaya pemanggil bisa membedakan
/// "kosong" dengan "salah ketik".
int? parseNominal(String teks) {
  final d = digitSaja(teks);
  if (d.isEmpty) return null;
  return int.tryParse(d);
}

/// Format ribuan gaya Indonesia: 10000 menjadi "10.000".
String formatRibuan(int nilai) {
  final s = nilai.abs().toString();
  final hasil = s.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]}.',
  );
  return nilai < 0 ? '-$hasil' : hasil;
}

/// Pemformat input nominal: hanya menerima digit, memisahkan ribuan saat
/// diketik, dan menolak digit yang membuat angka melebihi [maksDigit].
///
/// Kenapa `maxLength` pada `TextField` **tidak** bisa dipakai di sini:
/// `maxLength` menghitung karakter di dalam field, sedangkan "10.000.000"
/// berisi 10 karakter tapi hanya 8 digit. Memakai `maxLength: 8` akan membuat
/// kasir berhenti mengetik di "10.000", padahal angka itu belum selesai.
///
/// Posisi kursor selalu ditarik ke akhir. Untuk kolom angka yang biasanya
/// diketik dari awal, ini perilaku yang diharapkan; memcursor di tengah angka
/// belum tentu berarti kasir sedang menyunting bagian itu.
class FormatRibuan extends TextInputFormatter {
  const FormatRibuan({this.maksDigit = maksDigitNominal});

  final int maksDigit;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Seleksi saja yang berubah (mis. panah), bukan teks.
    if (oldValue.text == newValue.text) return newValue;

    final digit = digitSaja(newValue.text);
    if (digit.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    if (digit.length > maksDigit) return oldValue;

    final teks = formatRibuan(int.parse(digit));
    return TextEditingValue(
      text: teks,
      selection: TextSelection.collapsed(offset: teks.length),
      composing: TextRange.empty,
    );
  }
}
