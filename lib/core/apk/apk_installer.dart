import 'package:flutter/services.dart';

/// Hasil pemasangan di Android.
///
/// Status ini diurai [MainActivity.kt] di sisi Android
/// (`android/app/src/main/kotlin/com/v3netbill/v3netbill_mobile/MainActivity.kt`).
/// Kalau nama statusnya diubah di sana, ubah juga di sini.
enum StatusPasang {
  /// Installer Android terbuka dan pengguna menekan "Pasang".
  diterima,

  /// Pengguna menekan Batal atau tombol back di layar installer. Itu pilihan,
  /// bukan kegagalan, dan dialog unduhan harus tetap punya jalan keluar.
  dibatalkan,

  /// Izin "pasang aplikasi tidak dikenal" tidak diberikan. Android hanya
  /// meminta izin ini sekali; kalau ditolak, pengguna perlu langkah manual.
  izinDitolak,

  /// Gagal teknis: berkas hilang, lokasi tidak diizinkan, dan sejenisnya.
  gagal,
}

/// Hasil satu percobaan memasang APK.
class HasilPasang {
  const HasilPasang(this.status, [this.pesan]);

  final StatusPasang status;
  final String? pesan;

  bool get berhasil => status == StatusPasang.diterima;
}

/// Menerahkan berkas APK ke installer Android.
///
/// Memakai MethodChannel, bukan paket pihak ketiga, karena `install_plugin`
/// yang paling sering dipakai tidak bisa dikompilasi di sini: manifest-nya
/// masih memakai atribut `package=` yang error keras sejak AGP 8, sementara
/// project ini memakai AGP 9.0.1. Lihat komentar di `MainActivity.kt`.
class ApkInstaller {
  const ApkInstaller();

  static const MethodChannel _channel = MethodChannel('v3netbill/install');

  Future<HasilPasang> pasang(String pathApk) async {
    try {
      final balasan =
          await _channel.invokeMapMethod<String, dynamic>('pasang', {
        'path': pathApk,
      });
      if (balasan == null) {
        return const HasilPasang(
          StatusPasang.gagal,
          'Android tidak menjawab permintaan pemasangan.',
        );
      }
      final status = switch (balasan['status']) {
        'diterima' => StatusPasang.diterima,
        'dibatalkan' => StatusPasang.dibatalkan,
        'izin_ditolak' => StatusPasang.izinDitolak,
        _ => StatusPasang.gagal,
      };
      return HasilPasang(status, balasan['pesan'] as String?);
    } on PlatformException catch (e) {
      return HasilPasang(StatusPasang.gagal, e.message ?? e.code);
    } on MissingPluginException {
      return const HasilPasang(
        StatusPasang.gagal,
        'Modul pemasangan tidak tersedia di versi aplikasi ini.',
      );
    }
  }
}
