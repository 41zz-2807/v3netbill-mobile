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
  static const _kPassword = 'v3netbill_password';
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
    String? password,
  }) async {
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kRole, value: role);
    await _storage.write(key: _kUsername, value: username);
    // ⚠️ Password ikut disimpan supaya login bisa diperpanjang sendiri saat
    // token JWT kedaluwarsa (umur token 24 jam, lihat auth.module.ts di
    // backend). Tanpa ini kasir harus mengetik username dan password setiap
    // hari aunque HP-nya tidak pernah disentuh.
    //
    // ⚠️ Ini menyimpan password apa adanya. Yang membuatnya tidak langsung
    // terbaca adalah `FlutterSecureStorage` (EncryptedSharedPreferences di
    // Android), jadi isinya terenkripsi di HP. Tapi ini tetap elevate risiko
    // dibanding menyimpan token saja: HP yang di-root atau diambil orang bisa
    // membacanya, dan password ini juga sah untuk login dari mana pun.
    //
    // Password yang sudah TERSIMPAN dari versi lama tidak dihapus kalau
    // `password` null — yang terjadi cuma tidak ada pembaruan.
    if (password != null && password.isNotEmpty) {
      await _storage.write(key: _kPassword, value: password);
    }
  }

  Future<String?> readToken() => _storage.read(key: _kToken);
  Future<String?> readRole() => _storage.read(key: _kRole);
  Future<String?> readUsername() => _storage.read(key: _kUsername);

  /// Password untuk login ulang otomatis. Null kalau belum pernah disimpan,
  /// dan itu berarti aplikasi harus menampilkan layar login seperti biasa.
  Future<String?> readPassword() => _storage.read(key: _kPassword);

  /// True kalau username DAN password tersimpan, jadi login ulang otomatis
  /// mungkin dilakukan. Dipakai [AuthProvider] untuk memutuskan.
  Future<bool> bisaLoginUlang() async {
    final u = (await readUsername())?.trim() ?? '';
    final p = await readPassword();
    return u.isNotEmpty && p != null && p.isNotEmpty;
  }

  Future<bool> hasSession() async {
    final t = await readToken();
    return t != null && t.isNotEmpty;
  }

  Future<void> clear() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kRole);
    await _storage.delete(key: _kUsername);
    // ⚠️ Password ikut dihapus. Meninggalkannya berarti siapa pun yang
    // berhasil membuka aplikasi setelah kasir logout masih punya kredensial
    // untuk login ulang otomatis — persis yang harus hilang saat logout.
    await _storage.delete(key: _kPassword);
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
