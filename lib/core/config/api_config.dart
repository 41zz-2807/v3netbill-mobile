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

  /// Asal WebSocket untuk status realtime.
  static const wsOrigin = String.fromEnvironment(
    'API_WS_URL',
    defaultValue: 'wss://v3netbill.bilmary.my.id/socket.io',
  );

  // --- Endpoint auth ---
  static const login = '/auth/login';

  // --- Endpoint PC ---
  static const pcs = '/pcs';

  // --- Endpoint akun (voucher & member) ---
  static const accounts = '/accounts';

  // --- Endpoint transaksi ---
  static const transactions = '/transactions';

  // --- Endpoint laporan ---
  static const reportsToday = '/reports/today';
}
