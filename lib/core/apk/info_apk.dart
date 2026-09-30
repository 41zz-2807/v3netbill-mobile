/// Metadata APK yang disimpan backend, hasil `GET /api/settings/apk/info`.
///
/// Backend membacanya dari dalam berkas APK saat unggahan, bukan dari nama
/// berkas. Kalau APK-nya gagal diurai, `versionCode` dan `versionName` null dan
/// [apakahBisaDibandingkan] bernilai false — aplikasi lalu menampilkan "versi
/// tidak diketahui" alih-alih menebak bahwa pembaruan tersedia.
class InfoApk {
  const InfoApk({
    required this.ada,
    required this.versionCode,
    required this.versionName,
    required this.ukuranBytes,
    required this.sha256,
    required this.tanggalUpload,
  });

  /// False kalau server belum pernah menerima APK.
  final bool ada;

  final int? versionCode;
  final String? versionName;
  final int? ukuranBytes;

  /// Hash berkas. Aplikasi memverifikasi ulang setelah unduhan selesai, jadi
  /// unduhan yang terpotong tidak akan pernah dipasang.
  final String? sha256;
  final DateTime? tanggalUpload;

  /// Versi server ada dan berupa angka, sehingga bisa dibandingkan.
  bool get apakahBisaDibandingkan => ada && versionCode != null;

  factory InfoApk.fromJson(Map<String, dynamic> json) {
    return InfoApk(
      ada: json['ada'] == true,
      versionCode: _sebagaiInt(json['versionCode']),
      versionName: json['versionName'] as String?,
      ukuranBytes: _sebagaiInt(json['ukuranBytes']),
      sha256: json['sha256'] as String?,
      tanggalUpload: DateTime.tryParse(
        (json['tanggalUpload'] as String?) ?? '',
      ),
    );
  }

  /// Backend sudah menormalkan angkanya, tapi tetap Dijaga di sini: `null` dari
  /// JSON berarti `null` di Dart, dan angka string bukan angka.
  static int? _sebagaiInt(Object? nilai) {
    if (nilai is int) return nilai;
    if (nilai is num) return nilai.toInt();
    if (nilai is String) return int.tryParse(nilai);
    return null;
  }

  /// Versi server dalam bentuk terbaca manusia, mis. "1.0.14".
  String get versiTampil => versionName ?? (versionCode?.toString() ?? '?');
}
