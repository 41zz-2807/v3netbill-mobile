import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../config/api_config.dart';
import '../network/api_client.dart';
import 'info_apk.dart';

/// Sumber data pembaruan aplikasi: cek versi di server, unduh APK, verifikasi.
///
/// Kenapa hash dihitung ulang di dalam aplikasi: berkas 54 MB yang terpotong di
/// tengah jalan tetap punya bentuk APK, dan installer Android bisa menerimanya
/// lalu meninggalkan aplikasi yang tidak bisa jalan. Hash dari server membuat
/// unduhan rusak terdeteksi sebelum diserahkan ke installer.
class ApkRepository {
  ApkRepository(this._api);

  final ApiClient _api;

  Future<InfoApk> cekInfo() async {
    final data = await _api.get(ApiConfig.apkInfo);
    if (data is! Map) {
      throw StateError('Format jawaban info APK tidak dikenali.');
    }
    return InfoApk.fromJson(Map<String, dynamic>.from(data));
  }

  /// Unduh APK ke folder cache aplikasi dan pastikan utuh.
  ///
  /// Berkas ditulis sebagai `.part` lalu di-`rename` hanya setelah ukuran dan
  /// hash cocok. Kalau prosesnya mati di tengah jalan, berkas sisa tidak akan
  /// pernah terbaca sebagai "APK yang siap dipasang".
  Future<File> unduh(
    InfoApk info, {
    void Function(int diterima, int total)? onProgress,
  }) async {
    if (!info.ada) {
      throw StateError('Server belum memiliki berkas APK.');
    }
    final dir = await getTemporaryDirectory();
    final sementara = File('${dir.path}/v3netbill-unduhan.part');
    final jadi = File('${dir.path}/v3netbill-terbaru.apk');

    for (final sisa in [jadi, sementara]) {
      if (sisa.existsSync()) await sisa.delete();
    }

    try {
      // `raw` dipakai supaya interceptor token di ApiClient ikut bekerja.
      // Timeout bawaannya hanya 20 detik, tidak cukup untuk 54 MB di WiFi jelek.
      await _api.raw.download(
        '${ApiConfig.baseUrl}${ApiConfig.apk}',
        sementara.path,
        onReceiveProgress: (diterima, total) =>
            onProgress?.call(diterima, total == 0 ? 0 : total),
        options: Options(
          receiveTimeout: const Duration(minutes: 15),
          sendTimeout: const Duration(minutes: 2),
          followRedirects: true,
        ),
        deleteOnError: true,
      );
    } on DioException catch (e) {
      if (sementara.existsSync()) await sementara.delete();
      throw StateError(_pesanDio(e));
    }

    // Unduhan yang tidak sampai 100% belum tentu melempar error, jadi ukuran
    // dicek sendiri sebelum hash.
    final ukuran = await sementara.length();
    if (info.ukuranBytes != null && ukuran != info.ukuranBytes) {
      await sementara.delete();
      throw StateError(
        'Unduhan tidak lengkap, $ukuran dari ${info.ukuranBytes} byte.',
      );
    }

    if (info.sha256 != null) {
      final hash = await _sha256(sementara);
      if (hash != info.sha256) {
        await sementara.delete();
        throw StateError('Unduhan tidak cocok dengan berkas di server.');
      }
    }

    await sementara.rename(jadi.path);
    return jadi;
  }

  /// Hapus APK hasil unduhan. Dipanggil setelah installer selesai, supaya
  /// cache tidak menumpuk 54 MB setiap kali ada pembaruan.
  Future<void> bersihkan() async {
    try {
      final dir = await getTemporaryDirectory();
      for (final nama in [
        'v3netbill-terbaru.apk',
        'v3netbill-unduhan.part',
      ]) {
        final f = File('${dir.path}/$nama');
        if (f.existsSync()) await f.delete();
      }
    } catch (_) {
      // Membersihkan cache bukan hal penting. Kalau gagal, tidak boleh
      // menggagalkan alur pemasangan yang baru saja berhasil.
    }
  }

  Future<String> _sha256(File berkas) async {
    final digest = await sha256.bind(berkas.openRead()).first;
    return digest.toString();
  }

  String _pesanDio(DioException e) => switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'Koneksi terlalu lambat, unduhan dibatalkan.',
        DioExceptionType.connectionError =>
          'Tidak bisa menghubungi server. Periksa koneksi internet.',
        _ => e.message ?? 'Unduhan gagal.',
      };
}
