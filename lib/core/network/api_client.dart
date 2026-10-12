import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../storage/secure_store.dart';
import 'api_exception.dart';

/// Klien HTTP tunggal untuk seluruh aplikasi.
///
/// Token disimpan di [SecureStore] dan otomatis dipasang sebagai header
/// `Authorization: Bearer`. Saat backend membalas 401, [onUnauthorized]
/// dipanggil supaya aplikasi bisa mengarahkan pengguna ke halaman login.
class ApiClient {
  ApiClient({Dio? dio, SecureStore? secureStore})
      : _secureStore = secureStore ?? SecureStore(),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 20),
                contentType: Headers.jsonContentType,
                responseType: ResponseType.json,
                // Kita tangani status code sendiri supaya pesan error bisa
                // diterjemahkan. Jangan biarkan Dio lempar untuk semua kode.
                validateStatus: (status) => status != null && status < 500,
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStore.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final SecureStore _secureStore;

  /// Dipanggil ketika server membalas 401.
  void Function()? onUnauthorized;

  Dio get raw => _dio;

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    return _guard(() => _dio.get<dynamic>(path, queryParameters: query));
  }

  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    return _guard(() => _dio.post<dynamic>(
          path,
          data: data,
          queryParameters: query,
        ));
  }

  Future<dynamic> patch(
    String path, {
    Object? data,
  }) async {
    return _guard(() => _dio.patch<dynamic>(path, data: data));
  }

  Future<dynamic> delete(
    String path, {
    Object? data,
  }) async {
    return _guard(() => _dio.delete<dynamic>(path, data: data));
  }

  /// Cegah login ulang berulang.
  ///
  /// ⚠️ Tanpa ini, kalau password tersimpan ternyata sudah tidak berlaku,
  /// setiap request akan mencoba login ulang lagi — dan setiap percobaan itu
  /// juga dibalas 401, sehingga satu taps bisa memicu puluhan request ke
  /// server. Sekali sudah gagal, berhenti.
  bool _sedangLoginUlang = false;

  /// Login ulang diam-diam memakai username + password yang tersimpan.
  ///
  /// Dipanggil hanya saat server membalas 401 padahal request-nya membawa
  /// token — artinya token JWT-nya kedaluwarsa, bukan kredensial yang salah.
  ///
  /// Mengembalikan true kalau token baru berhasil disimpan, sehingga
  /// pemanggil boleh mengulang request aslinya.
  Future<bool> _loginUlangOtomatis() async {
    if (_sedangLoginUlang) return false;
    _sedangLoginUlang = true;
    try {
      final bisa = await _secureStore.bisaLoginUlang();
      if (!bisa) return false;

      final username = (await _secureStore.readUsername())?.trim() ?? '';
      final password = await _secureStore.readPassword() ?? '';

      // ⚠️ Pakai `_dio` langsung, BUKAN `post()`. `post()` melewati `_guard`
      // lagi, dan itu akan membuat 401 dari endpoint login ikut memicu
      // login ulang lagi — tanpa akhir.
      final res = await _dio.post<dynamic>(
        ApiConfig.login,
        data: {'username': username, 'password': password},
      );
      final data = res.data;
      if (res.statusCode != 200 || data is! Map) return false;

      final token = (data['access_token'] ?? data['accessToken'])?.toString();
      if (token == null || token.isEmpty) return false;

      final role =
          (data['role'] ?? await _secureStore.readRole() ?? 'KASIR').toString();

      await _secureStore.saveSession(
        token: token,
        role: role,
        username: username,
      );
      return true;
    } catch (_) {
      // Kegagalan apa pun di sini berarti "tidak bisa login ulang", dan itu
      // ditangani pemanggil. Jangan lempar: yang penting tidak crash.
      return false;
    } finally {
      _sedangLoginUlang = false;
    }
  }

  /// Membungkus pemanggilan dan mengubah error menjadi [ApiException].
  Future<dynamic> _guard(
    Future<Response<dynamic>> Function() call, {
    bool sudahCobaLoginUlang = false,
  }) async {
    // PENTING: 401 HANYA bermakna "token tidak valid" kalau permintaan ini
    // benar-benar membawa token. `POST /auth/login` tidak butuh token, jadi
    // 401 dari sana berarti username atau password salah.
    //
    // Versi lama menganggap semua 401 itu masalah token. Akibatnya password
    // salah menampilkan "Token tidak valid atau sudah kedaluwarsa" — kalimat
    // yang tidak ada hubungannya dengan yang diketik pengguna — DAN ikut
    // menghapus sesi, jadi login gagal yang sah bisa membuat pengguna yang
    // tadinya sudah masuk kehilangan sesinya.
    final adaToken =
        (await _secureStore.readToken())?.trim().isNotEmpty ?? false;

    try {
      final res = await call();
      final code = res.statusCode ?? 0;

      if (code >= 200 && code < 300) {
        return res.data;
      }
      if (code == 401) {
        if (!adaToken) {
          // Kredensial ditolak. Pesan dari server yang ditampilkan, dan sesi
          // tidak disentuh.
          throw ApiException(
            _extractMessage(res),
            statusCode: 401,
          );
        }

        // ⚠️ Tokennya kedaluwarsa (umur JWT 24 jam). Coba perpanjang sesi
        // sendiri dulu sebelum buang apa pun — versi lama langsung menghapus
        // sesi di sini, jadi kasir harus mengetik username dan password lagi
        // setiap hari walaupun HP-nya tidak pernah disentuh.
        if (!sudahCobaLoginUlang && await _loginUlangOtomatis()) {
          // Token baru sudah tersimpan, jadi header Authorization pada
          // interceptor akan memakainya. Ulang request ASLINYA — tepat satu
          // kali, ditandai flag supaya tidak menjadi loop.
          return _guard(call, sudahCobaLoginUlang: true);
        }

        await _secureStore.clear();
        onUnauthorized?.call();
        throw ApiException(
          'Token tidak valid atau sudah kedaluwarsa.',
          statusCode: 401,
        );
      }
      throw ApiException(
        _extractMessage(res),
        statusCode: code,
      );
    } on DioException catch (e) {
      // DioException dengan response berarti server memang menjawab; error
      // jaringan murni tidak punya response.
      final res = e.response;
      if (res != null) {
        if (res.statusCode == 401 && !adaToken) {
          throw ApiException(_extractMessage(res), statusCode: 401);
        }
        throw ApiException(
          _extractMessage(res),
          statusCode: res.statusCode,
        );
      }
      throw ApiException(
        'Tidak bisa terhubung ke server. Periksa koneksi internet.',
      );
    }
  }

  /// Mencoba mengambil pesan dari body error backend.
  ///
  /// Backend NestJS biasanya mengembalikan `{ "message": "..." }` atau
  /// `{ "message": ["...", "..."] }` untuk validasi.
  String _extractMessage(Response<dynamic> res) {
    final data = res.data;
    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.trim().isNotEmpty) return msg;
      if (msg is List && msg.isNotEmpty) return msg.join('\n');
    }
    if (data is String && data.trim().isNotEmpty && data.length < 300) {
      return data;
    }
    return 'Terjadi kesalahan (HTTP ${res.statusCode}).';
  }
}
