import 'package:flutter/services.dart';

/// Hasil minta izin notifikasi.
enum StatusIzinNotifikasi {
  /// Android 13+ sudah menyalakan izin notifikasi.
  diberikan,

  /// Pengguna menolak, atau belum menjawab.
  ditolak,

  /// Android 12 ke bawah: tidak ada izin runtime, notifikasi selalu boleh.
  tidakPerlu,

  /// Proses mati atau dialognya tidak pernah dijawab.
  dibatalkan,

  gagal,
}

/// Jembatan ke sisi Android untuk menyiapkan channel notifikasi dan
/// meminta izin.
///
/// Channel-nya harus dibuat sendiri dengan importance TINGGI. Kalau tidak,
/// FCM memakai channel bawaannya yang importance-nya rendah: notifikasi tetap
/// muncul tapi tanpa suara dan tanpa getaran — dan di warnet suara itulah
/// bagian yang paling dibutuhkan.
///
/// Nama channel di sini harus sama dengan `ID_CHANNEL_NOTIF` di
/// `MainActivity.kt` dan `CHANNEL_ID` di backend.
class NotifikasiLokal {
  const NotifikasiLokal();

  static const _channel = MethodChannel('v3netbill/notifikasi');

  /// Sama persis dengan `ID_CHANNEL_NOTIF` di MainActivity.kt.
  static const idChannel = 'sesi_dimulai';

  /// Bikin channel-nya. Aman dipanggil berulang.
  Future<void> siapkanChannel() async {
    try {
      await _channel.invokeMethod<bool>('siapkanChannel');
    } on PlatformException {
      // Tidak ada yang bisa dilakukan, dan tidak boleh menggagalkan proses
      // yang lebih penting.
    } on MissingPluginException {
      // Tester dan `flutter test` tidak punya channel ini.
    }
  }

  Future<StatusIzinNotifikasi> mintaIzin() async {
    try {
      final hasil = await _channel.invokeMapMethod<String, dynamic>('izin');
      return _ubahStatus(hasil?['status'] as String?);
    } on PlatformException {
      return StatusIzinNotifikasi.gagal;
    } on MissingPluginException {
      return StatusIzinNotifikasi.tidakPerlu;
    }
  }

  Future<StatusIzinNotifikasi> statusIzin() async {
    try {
      final hasil =
          await _channel.invokeMapMethod<String, dynamic>('statusIzin');
      return _ubahStatus(hasil?['status'] as String?);
    } on PlatformException {
      return StatusIzinNotifikasi.gagal;
    } on MissingPluginException {
      return StatusIzinNotifikasi.tidakPerlu;
    }
  }

  StatusIzinNotifikasi _ubahStatus(String? mentah) {
    switch (mentah) {
      case 'diberi':
        return StatusIzinNotifikasi.diberikan;
      case 'ditolak':
        return StatusIzinNotifikasi.ditolak;
      case 'belum':
        return StatusIzinNotifikasi.ditolak;
      case 'dibatalkan':
        return StatusIzinNotifikasi.dibatalkan;
      default:
        return StatusIzinNotifikasi.gagal;
    }
  }
}
