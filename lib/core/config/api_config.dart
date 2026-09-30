/// Konfigurasi endpoint.
///
/// Base URL sengaja hanya ada di satu tempat ini supaya tidak ada URL yang
/// ditulis langsung di dalam widget. Kalau backend pindah server, cukup
/// ubah [baseUrl] (atau set lewat `--dart-define` saat build).
class ApiConfig {
  const ApiConfig._();

  /// Semua endpoint backend memakai prefiks global `/api`.
  ///
  /// Bisa dioverride saat build:
  /// `flutter build apk --dart-define=API_BASE_URL=https://host/api`
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://v3netbill.bilmary.my.id/api',
  );

  /// Asal Socket.IO.
  ///
  /// PENTING: gateway backend memakai namespace `/session`
  /// (lihat `WebSocketGateway` di session.gateway.ts). Socket yang
  /// terhubung ke root akan connect dengan sukses, tapi semua perintah
  /// tidak akan sampai ke gateway dan tidak ada balasan apa pun.
  ///
  /// Bisa dioverride saat build:
  /// `flutter build apk --dart-define=API_WS_URL=wss://host/session`
  static const wsOrigin = String.fromEnvironment(
    'API_WS_URL',
    defaultValue: 'wss://v3netbill.bilmary.my.id/session',
  );

  // --- Endpoint auth ---
  static const login = '/auth/login';

  // --- Endpoint PC ---
  static const pcs = '/pcs';

  // --- Endpoint akun (voucher & member) ---
  static const accounts = '/accounts';

  // --- Endpoint laporan ---
  static const reportsToday = '/reports/today';

  // --- Endpoint pembaruan aplikasi ---
  /// Metadata APK saja (versi, ukuran, sha256). Dipakai aplikasi untuk cek
  /// pembaruan. Wajib JWT, dan TIDAK boleh diganti `GET /settings` karena itu
  /// mengembalikan seluruh setting termasuk token bot Telegram dan hash PIN.
  static const apkInfo = '/settings/apk/info';

  /// Berkas APK-nya sendiri (54 MB). Dipakai hanya setelah versi newer terkonfirmasi.
  static const apk = '/settings/apk';
}
