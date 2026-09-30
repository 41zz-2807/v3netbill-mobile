import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:v3netbill_mobile/core/apk/apk_installer.dart';
import 'package:v3netbill_mobile/core/apk/apk_repository.dart';
import 'package:v3netbill_mobile/core/apk/info_apk.dart';
import 'package:v3netbill_mobile/core/apk/update_provider.dart';

/// [ApkRepository] palsu supaya provider bisa diuji tanpa jaringan.
class _FakeApkRepository implements ApkRepository {
  _FakeApkRepository({this.info, this.gagal});

  final InfoApk? info;
  final Object? gagal;
  int unduhCalls = 0;
  int cekInfoCalls = 0;
  int bersihkanCalls = 0;

  @override
  Future<InfoApk> cekInfo() async {
    cekInfoCalls++;
    if (gagal != null) throw gagal!;
    return info ?? InfoApk.fromJson(const {});
  }

  @override
  Future<void> bersihkan() async {
    bersihkanCalls++;
  }

  @override
  Future<File> unduh(
    InfoApk info, {
    void Function(int diterima, int total)? onProgress,
  }) async {
    unduhCalls++;
    onProgress?.call(100, 200);
    // Hanya `.path` yang dipakai. `File(...)` tidak membaca disk, jadi aman
    // dipakai di test tanpa menyiapkan berkas sungguhan.
    return File('/tmp/v3netbill-terbaru.apk');
  }
}

/// Installer palsu: tidak menyentuh Android sama sekali.
class _FakeInstaller implements ApkInstaller {
  _FakeInstaller(this.hasil);

  final HasilPasang hasil;
  int pasangCalls = 0;

  @override
  Future<HasilPasang> pasang(String pathApk) async {
    pasangCalls++;
    return hasil;
  }
}

/// [PackageInfo.fromPlatform()] tidak bisa jalan di test, jadi build number
/// disetel lewat override statis milik package_info_plus.
const _buildTerpasang = 12;

void main() {
  setUpAll(() {
    // Nilai yang dikembalikan PackageInfo.fromPlatform(). Ditaruh di sini
    // supaya test tidak bergantung pada metadata paket proyek yang bisa berubah.
    PackageInfo.setMockInitialValues(
      appName: 'v3Netbill',
      packageName: 'com.v3netbill.v3netbill_mobile',
      version: '1.0.12',
      buildNumber: '$_buildTerpasang',
      buildSignature: '',
    );
  });

  InfoApk info(int code) => InfoApk.fromJson({
    'ada': true,
    'versionCode': code,
    'versionName': '1.0.$code',
    'ukuranBytes': 53956267,
    'sha256': 'abc',
    'tanggalUpload': '2026-09-30T02:00:00.000Z',
  });

  group('UpdateProvider cek versi', () {
    test('versi server lebih baru -> ada pembaruan', () async {
      final p = UpdateProvider(
        _FakeApkRepository(info: info(_buildTerpasang + 1)),
        installer: _FakeInstaller(
          const HasilPasang(StatusPasang.gagal, 'tidak dipakai'),
        ),
      );
      await p.cek();
      expect(p.adaPembaruan, isTrue);
      expect(p.tahap, TahapPembaruan.tersedia);
      expect(p.alasanTidakBisaDicek, isNull);
    });

    test('versi server sama -> tidak ada pembaruan', () async {
      final p = UpdateProvider(
        _FakeApkRepository(info: info(_buildTerpasang)),
        installer: _FakeInstaller(
          const HasilPasang(StatusPasang.gagal, 'tidak dipakai'),
        ),
      );
      await p.cek();
      expect(p.adaPembaruan, isFalse);
      expect(p.tahap, TahapPembaruan.tidakAda);
    });

    test('server lebih lama -> tidak ada pembaruan', () async {
      final p = UpdateProvider(
        _FakeApkRepository(info: info(_buildTerpasang - 5)),
        installer: _FakeInstaller(
          const HasilPasang(StatusPasang.gagal, 'tidak dipakai'),
        ),
      );
      await p.cek();
      expect(p.adaPembaruan, isFalse);
    });

    test('server tidak punya APK -> tidak ada pembaruan', () async {
      final p = UpdateProvider(
        _FakeApkRepository(info: InfoApk.fromJson(const {'ada': false})),
        installer: _FakeInstaller(
          const HasilPasang(StatusPasang.gagal, 'tidak dipakai'),
        ),
      );
      await p.cek();
      expect(p.adaPembaruan, isFalse);
    });

    test('nomor versi server tidak terbaca -> alasan, bukan pembaruan palsu', () async {
      final p = UpdateProvider(
        _FakeApkRepository(
          info: InfoApk.fromJson(const {'ada': true, 'versionCode': null}),
        ),
        installer: _FakeInstaller(
          const HasilPasang(StatusPasang.gagal, 'tidak dipakai'),
        ),
      );
      await p.cek();
      // Penting: TIDAK boleh menampilkan "pembaruan tersedia" hanya karena
      // server tidak memberi angka. Itu akan membuat penanda tidak pernah hilang.
      expect(p.adaPembaruan, isFalse);
      expect(p.alasanTidakBisaDicek, contains('tidak terbaca'));
    });

    test('cek gagal -> pesan galat, bukan "ada pembaruan"', () async {
      final p = UpdateProvider(
        _FakeApkRepository(gagal: Exception('jaringan mati')),
        installer: _FakeInstaller(
          const HasilPasang(StatusPasang.gagal, 'tidak dipakai'),
        ),
      );
      await p.cek();
      expect(p.adaPembaruan, isFalse);
      expect(p.galat, contains('jaringan mati'));
    });

    test('cek kedua diabaikan tanpa paksa', () async {
      final repo = _FakeApkRepository(info: info(_buildTerpasang + 1));
      final p = UpdateProvider(
        repo,
        installer: _FakeInstaller(
          const HasilPasang(StatusPasang.gagal, 'tidak dipakai'),
        ),
      );
      await p.cek();
      await p.cek();
      expect(repo.cekInfoCalls, 1);
      await p.cek(paksa: true);
      expect(repo.cekInfoCalls, 2);
    });
  });

  group('UpdateProvider alur pasang', () {
    test('diterima -> cek dibuang supaya penanda hilang setelah update', () async {
      final repo = _FakeApkRepository(info: info(_buildTerpasang + 1));
      final p = UpdateProvider(
        repo,
        installer: _FakeInstaller(const HasilPasang(StatusPasang.diterima)),
      );
      await p.cek();
      await p.unduhDanPasang();
      expect(repo.bersihkanCalls, 1);
      expect(p.tahap, TahapPembaruan.belumDicek);
      expect(p.adaPembaruan, isFalse);
    });

    test('pengguna batal -> berkas disimpan, tidak diunduh ulang', () async {
      final repo = _FakeApkRepository(info: info(_buildTerpasang + 1));
      final p = UpdateProvider(
        repo,
        installer: _FakeInstaller(const HasilPasang(StatusPasang.dibatalkan)),
      );
      await p.cek();
      await p.unduhDanPasang();
      // Berkas harus dibiarkan supaya tombol Pasang tidak mengunduh 54 MB lagi.
      expect(repo.bersihkanCalls, 0);
      expect(p.tahap, TahapPembaruan.siapPasang);
      // Dan dari tahap itu harus ada jalan keluar, yaitu pasangSaja().
      expect(p.adaPembaruan, isFalse);
    });

    test('izin ditolak -> pesan memberi langkah manual', () async {
      final p = UpdateProvider(
        _FakeApkRepository(info: info(_buildTerpasang + 1)),
        installer: _FakeInstaller(const HasilPasang(StatusPasang.izinDitolak)),
      );
      await p.cek();
      await p.unduhDanPasang();
      expect(p.galat, contains('Pengaturan'));
      expect(p.tahap, TahapPembaruan.tersedia);
    });

    test('gagal -> pesan isi dari Android, tidak dihapus diam-diam', () async {
      final p = UpdateProvider(
        _FakeApkRepository(info: info(_buildTerpasang + 1)),
        installer: _FakeInstaller(
          const HasilPasang(StatusPasang.gagal, 'berkas tidak ditemukan'),
        ),
      );
      await p.cek();
      await p.unduhDanPasang();
      expect(p.galat, 'berkas tidak ditemukan');
      expect(p.tahap, TahapPembaruan.siapPasang);
    });
  });
}
