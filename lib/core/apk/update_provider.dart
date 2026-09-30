import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'apk_installer.dart';
import 'apk_repository.dart';
import 'info_apk.dart';

/// Tahap dari proses pembaruan, untuk menentukan tombol mana yang tampil.
enum TahapPembaruan {
  /// Belum ada yang diketahui. Indikator disembunyikan sampai cek pertama selesai.
  belumDicek,

  /// Sedang menghubungi server.
  memeriksa,

  /// Versi di server sama dengan yang terpasang, jadi tidak ada yang perlu
  /// diunduh. Ini juga keadaan saat pengecekan gagal, supaya aplikasi tidak
  /// pernah menampilkan "pembaruan tersedia" tanpa bukti.
  tidakAda,

  /// Ada versi baru, belum ada yang diunduh.
  tersedia,

  /// Sedang mengunduh.
  mengunduh,

  /// Sudah terunduh dan hash cocok, siap diserahkan ke installer.
  siapPasang,

  /// Installer Android terbuka.
  memasang,
}

/// Menyimpan status pembaruan aplikasi.
///
/// Nomor versi yang terpasang dibaca sekali dari [PackageInfo], lalu
/// dibandingkan dengan angka yang dibaca backend dari dalam berkas APK. Kalau
/// salah satu tidak terbaca, [adaPembaruan] bernilai false dan
/// [alasanTidakBisaDicek] berisi penjelasannya. Lebih baik diam daripada
/// menampilkan "pembaruan tersedia" yang tidak pernah bisa dibersihkan.
class UpdateProvider extends ChangeNotifier {
  UpdateProvider(this._repo, {ApkInstaller? installer})
      : _installer = installer ?? const ApkInstaller();

  final ApkRepository _repo;
  final ApkInstaller _installer;

  TahapPembaruan _tahap = TahapPembaruan.belumDicek;
  InfoApk? _info;
  String? _buildTerpasang;
  String? _versiTerpasang;
  String? _galat;
  int _diterima = 0;
  int _total = 0;
  bool _sudahCek = false;

  TahapPembaruan get tahap => _tahap;
  InfoApk? get info => _info;

  /// Pesan singkat untuk ditampilkan ke pengguna.
  String? get galat => _galat;

  /// True kalau ada versi baru yang belum diunduh.
  ///
  /// Sengaja false saat sedang mengunduh atau memasang: penanda "ada
  /// pembaruan" akan membuat orang mengira belum ada yang sedang terjadi.
  bool get adaPembaruan => _tahap == TahapPembaruan.tersedia;

  /// True kalau sedang ada proses yang berjalan, untuk mengunci tombol.
  bool get sibuk =>
      _tahap == TahapPembaruan.memeriksa ||
      _tahap == TahapPembaruan.mengunduh ||
      _tahap == TahapPembaruan.memasang;

  /// Kemajuan unduhan 0..1. Nol kalau server tidak mengirim ukuran.
  double get persen {
    if (_total <= 0) return 0;
    return (_diterima / _total).clamp(0, 1);
  }

  /// Versi yang sedang terpasang di HP ini, mis. "1.0.12".
  String get versiTerpasang => _versiTerpasang ?? '?';

  int? get buildTerpasang => int.tryParse(_buildTerpasang ?? '');

  /// Penjelasan kalau versi tidak bisa dibandingkan. Null kalau normal.
  String? get alasanTidakBisaDicek {
    if (_galat != null) return _galat;
    final info = _info;
    if (info == null || !info.ada) return null;
    if (info.versionCode == null) {
      return 'Nomor versi APK di server tidak terbaca, jadi perbaruan tidak '
          'bisa dibandingkan. Unduh manual lewat browser bila perlu.';
    }
    if (buildTerpasang == null) {
      return 'Nomor versi aplikasi ini tidak terbaca, perbaruan tidak bisa '
          'dibandingkan.';
    }
    return null;
  }

  /// Cek versi di server. Aman dipanggil berulang.
  Future<void> cek({bool paksa = false}) async {
    if (_sudahCek && !paksa) return;
    _sudahCek = true;
    _tahap = TahapPembaruan.memeriksa;
    _galat = null;
    notifyListeners();

    try {
      final info = await _repo.cekInfo();
      if (_buildTerpasang == null) {
        // Sekali saja: `fromPlatform()` membaca metadata paket dari sistem,
        // dan dipanggil dua kali hanya untuk membuang waktu saat startup.
        final paket = await PackageInfo.fromPlatform();
        _buildTerpasang = paket.buildNumber;
        _versiTerpasang = paket.version;
      }
      _info = info;
      _tahap = _hitungTahap(info);
    } catch (e) {
      // Kegagalan cek TIDAK boleh disamarkan jadi "ada pembaruan". Operator
      // tidak boleh dikejar dengan pesan yang tidak benar.
      _galat = _pesanRingkas(e);
      _tahap = TahapPembaruan.tidakAda;
    }
    notifyListeners();
  }

  TahapPembaruan _hitungTahap(InfoApk info) {
    if (!info.ada || info.versionCode == null) return TahapPembaruan.tidakAda;
    final terpasang = buildTerpasang;
    if (terpasang == null) return TahapPembaruan.tidakAda;
    return info.versionCode! > terpasang
        ? TahapPembaruan.tersedia
        : TahapPembaruan.tidakAda;
  }

  /// Unduh APK, verifikasi hash, lalu serahkan ke installer Android.
  ///
  /// Setiap jalur kegagalan mengembalikan kendali ke pengguna lewat [galat]
  /// dan mengembalikan `false`. Tidak boleh menggantung di layar unduhan.
  Future<bool> unduhDanPasang() async {
    final info = _info;
    if (info == null) return false;

    _tahap = TahapPembaruan.mengunduh;
    _diterima = 0;
    _total = info.ukuranBytes ?? 0;
    _galat = null;
    notifyListeners();

    final String path;
    try {
      final berkas = await _repo.unduh(
        info,
        onProgress: (diterima, total) {
          _diterima = diterima;
          if (total > 0) _total = total;
          notifyListeners();
        },
      );
      path = berkas.path;
    } catch (e) {
      _galat = _pesanRingkas(e);
      _tahap = TahapPembaruan.tersedia;
      notifyListeners();
      return false;
    }

    return _pasang(path, izinDitolakBersihkanBerkas: true);
  }

  /// Pasang lagi berkas yang sudah terunduh, tanpa mengunduh ulang 54 MB.
  Future<bool> pasangSaja() async {
    if (_tahap != TahapPembaruan.siapPasang) return false;
    String? path;
    try {
      path = '${(await getTemporaryDirectory()).path}/v3netbill-terbaru.apk';
    } catch (e) {
      _galat = 'Folder unduhan tidak ditemukan, unduh ulang.';
      _tahap = TahapPembaruan.tersedia;
      notifyListeners();
      return false;
    }
    if (!File(path).existsSync()) {
      _galat = 'Berkas APK sudah tidak ada, unduh ulang.';
      _tahap = TahapPembaruan.tersedia;
      notifyListeners();
      return false;
    }
    return _pasang(path, izinDitolakBersihkanBerkas: true);
  }

  Future<bool> _pasang(String path,
      {required bool izinDitolakBersihkanBerkas}) async {
    _tahap = TahapPembaruan.memasang;
    notifyListeners();

    final hasil = await _installer.pasang(path);

    switch (hasil.status) {
      case StatusPasang.diterima:
        await _repo.bersihkan();
        _tahap = TahapPembaruan.belumDicek;
        _sudahCek = false;
        _galat = null;
        break;
      case StatusPasang.dibatalkan:
        // Installer ditutup. Berkas sengaja dibiarkan supaya menekan "Pasang"
        // lagi tidak mengunduh 54 MB dari nol.
        _tahap = TahapPembaruan.siapPasang;
        break;
      case StatusPasang.izinDitolak:
        if (izinDitolakBersihkanBerkas) await _repo.bersihkan();
        _galat = 'Izin memasang aplikasi belum diberikan. Buka Pengaturan > '
            'Aplikasi > v3Netbill > Izin, nyalakan "Pasang aplikasi tidak '
            'diketahui", lalu tekan Perbarui sekali lagi.';
        _tahap = TahapPembaruan.tersedia;
        break;
      case StatusPasang.gagal:
        _galat = hasil.pesan ?? 'Pemasangan gagal.';
        _tahap = TahapPembaruan.siapPasang;
        break;
    }
    notifyListeners();
    return true;
  }

  String _pesanRingkas(Object e) {
    var teks = e.toString();
    for (final awalan in [
      'Exception: ',
      'Bad state: ',
      'StateError: ',
      'Invalid state: ',
      'FormatException: ',
    ]) {
      if (teks.startsWith(awalan)) teks = teks.substring(awalan.length);
    }
    return teks.trim();
  }
}
