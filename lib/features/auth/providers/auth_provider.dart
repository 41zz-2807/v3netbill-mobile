import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../models/user_session.dart';

/// Status autentikasi untuk seluruh aplikasi.
enum AuthStatus {
  /// Belum tahu ada sesi tersimpan atau tidak, masih membaca storage.
  checking,

  /// Belum login.
  unauthenticated,

  /// Sedang mengirim permintaan login.
  submitting,

  /// Sudah login.
  authenticated,
}

/// Mengatur seluruh siklus hidup sesi.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repo);

  final AuthRepository _repo;

  AuthStatus _status = AuthStatus.checking;
  UserSession? _session;
  String? _error;

  AuthStatus get status => _status;
  UserSession? get session => _session;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Dipanggil sekali saat aplikasi dibuka.
  Future<void> bootstrap() async {
    final s = await _repo.restore();
    _session = s;
    _status = s == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;
    notifyListeners();
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _status = AuthStatus.submitting;
    _error = null;
    notifyListeners();

    try {
      _session = await _repo.login(
        username: username.trim(),
        password: password,
      );
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _error = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    _session = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Dipanggil ApiClient ketika server membalas 401.
  void handleUnauthorized() {
    if (_status == AuthStatus.unauthenticated) return;
    _session = null;
    _status = AuthStatus.unauthenticated;
    _error = 'Sesi berakhir. Silakan login kembali.';
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  String _friendly(Object e) {
    final text = e.toString();
    if (text.contains('ApiException')) {
      return text.split('): ').last;
    }
    return 'Login gagal. Periksa username dan password.';
  }
}
