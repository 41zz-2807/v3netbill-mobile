import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_store.dart';
import '../models/user_session.dart';

/// Sumber data autentikasi.
class AuthRepository {
  AuthRepository(this._api, this._store);

  final ApiClient _api;
  final SecureStore _store;

  /// Login dan simpan token.
  ///
  /// Bentuk jawaban backend sudah dipastikan:
  /// `{ "access_token": "...", "role": "ADMIN" }`.
  ///
  /// Catatan: field-nya `access_token` (snake_case), bukan `accessToken`.
  /// Ini sumber kesalahan yang mudah terjadi.
  Future<UserSession> login({
    required String username,
    required String password,
  }) async {
    final data = await _api.post(
      ApiConfig.login,
      data: {
        'username': username,
        'password': password,
      },
    );

    if (data is! Map) {
      throw Exception('Format jawaban login tidak dikenali.');
    }

    final token = (data['access_token'] ?? data['accessToken'])?.toString();
    final role = (data['role'] ?? 'KASIR').toString();

    if (token == null || token.isEmpty) {
      throw Exception('Server tidak mengembalikan token.');
    }

    final session = UserSession(
      token: token,
      role: role,
      username: username,
    );

    await _store.saveSession(
      token: session.token,
      role: session.role,
      username: session.username,
    );

    return session;
  }

  /// Ambil sesi tersimpan, kalau masih ada.
  Future<UserSession?> restore() async {
    final token = await _store.readToken();
    final role = await _store.readRole();
    final username = await _store.readUsername();
    if (token == null || token.isEmpty) return null;
    return UserSession(
      token: token,
      role: role ?? 'KASIR',
      username: username ?? '-',
    );
  }

  Future<void> logout() => _store.clear();
}
