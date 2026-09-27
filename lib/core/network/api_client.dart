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

  /// Membungkus pemanggilan dan mengubah error menjadi [ApiException].
  Future<dynamic> _guard(
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      final res = await call();
      final code = res.statusCode ?? 0;

      if (code >= 200 && code < 300) {
        return res.data;
      }
      if (code == 401) {
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
