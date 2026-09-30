import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/notifikasi/notifikasi_provider.dart';
import '../../../core/network/api_exception.dart';
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
  AuthProvider(this._repo, [this._notifikasi]);

  final AuthRepository _repo;

  /// Opsional supaya halaman yang hanya butuh state login tidak harus membuat
  /// notifikasi. Kalau null, tidak ada token yang didaftarkan.
  final NotifikasiProvider? _notifikasi;

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
    // Sesi yang dipulihkan dari penyimpanan HARUS lewat sini juga, bukan cuma
    // lewat `login()`.
    //
    // Alasannya: begitu aplikasi di-update, data aplikasi tidak hilang, jadi
    // sesi lama masih tersimpan dan aplikasi membuka lewat `bootstrap()` —
    // `login()` tidak pernah dipanggil. Kalau token push hanya didaftarkan di
    // `login()`, tokennya tidak akan pernah terkirim sampai kasir logout dulu.
    // Itu persis yang terjadi: HP sudah terpasang, izin sudah diberikan, tapi
    // tabel `Perangkat` tetap kosong.
    if (s != null) {
      unawaited(_notifikasi?.setelahLogin(admin: s.isAdmin));
    }
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
      // Jangan ditunggu: login sudah berhasil dan kasir tidak boleh menunggu
      // proses jaringan notifikasi sebelum bisa mulai berjualan.
      unawaited(_notifikasi?.setelahLogin(admin: _session!.isAdmin));
      return true;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _error = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    // WAJIB sebelum `_repo.logout()`: penghapusan token memakai JWT, dan
    // `logout()` membersihkan token itu dari penyimpanan. Kalau urutannya
    // dibalik, permintaannya terkirim tanpa autentikasi dan server membalas
    // 401, sehingga token push tertinggal untuk akun yang sudah logout.
    await _notifikasi?.sebelumLogout();
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
    if (e is ApiException) {
      // 401 di sini PASTI kredensial ditolak, karena kita masih di layar
      // login dan belum ada token yang dikirim. Pesan bawaan server
      // ("Invalid credentials") berbahasa Inggris dan tidak menyebut apa yang
      // harus diperbaiki.
      if (e.statusCode == 401) {
        return 'Username atau password salah.';
      }
      return e.message;
    }
    return 'Login gagal. Periksa username dan password.';
  }
}
