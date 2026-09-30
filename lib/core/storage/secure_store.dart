import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Pembungkus penyimpanan token di luar [ApiClient].
///
/// Memakai [FlutterSecureStorage] (Keychain di iOS, EncryptedSharedPreferences
/// di Android) supaya token tidak tersimpan di plain text.
class SecureStore {
  SecureStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const _kToken = 'v3netbill_token';
  static const _kRole = 'v3netbill_role';
  static const _kUsername = 'v3netbill_username';
  static const _kNotifikasiSesi = 'v3netbill_notif_sesi';

  /// Kunci ini harus sama dengan yang dipakai aplikasi web, supaya saat
  /// logout dari web tidak bentrok. Lihat `src/lib/api.ts` di repo
  /// frontend.
  static const tokenKey = _kToken;
  static const roleKey = _kRole;
  static const usernameKey = _kUsername;

  Future<void> saveSession({
    required String token,
    required String role,
    required String username,
  }) async {
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kRole, value: role);
    await _storage.write(key: _kUsername, value: username);
  }

  Future<String?> readToken() => _storage.read(key: _kToken);
  Future<String?> readRole() => _storage.read(key: _kRole);
  Future<String?> readUsername() => _storage.read(key: _kUsername);

  Future<bool> hasSession() async {
    final t = await readToken();
    return t != null && t.isNotEmpty;
  }

  Future<void> clear() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kRole);
    await _storage.delete(key: _kUsername);
    // KUNCI `_kNotifikasiSesi` SENGAJA TIDAK dihapus di sini.
    //
    // Ini preferensi perangkat, bukan bagian dari sesi login. Kalau ikut
    // terhapus, setiap logout akan mengembalikan sakelarnya ke default, jadi
    // kasir yang sengaja mematikannya akan melihat sakelarnya nyala lagi
    // setelah login berikutnya.
  }

  /// Sakelar notifikasi login pelanggan. Null berarti belum pernah disimpan,
  /// dan itu diperlakukan sebagai menyala.
  Future<bool?> readNotifikasiSesi() async {
    final nilai = await _storage.read(key: _kNotifikasiSesi);
    if (nilai == null || nilai.isEmpty) return null;
    return nilai == '1';
  }

  Future<void> saveNotifikasiSesi(bool nilai) async {
    await _storage.write(key: _kNotifikasiSesi, value: nilai ? '1' : '0');
  }
}
