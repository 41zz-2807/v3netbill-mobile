import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v3netbill_mobile/core/network/api_client.dart';
import 'package:v3netbill_mobile/core/network/api_exception.dart';
import 'package:v3netbill_mobile/core/storage/secure_store.dart';
import 'package:v3netbill_mobile/features/auth/data/auth_repository.dart';
import 'package:v3netbill_mobile/features/auth/providers/auth_provider.dart';

/// Menyimpan apa yang ditulis, supaya tes bisa memeriksa sesi benar-benar
/// dihapus atau benar-benar dipertahankan.
class _StorePalsu extends SecureStore {
  final Map<String, String> isi = {};
  int jumlahClear = 0;

  @override
  Future<String?> readToken() async => isi['token'];

  @override
  Future<void> saveSession({
    required String token,
    required String role,
    required String username,
  }) async =>
      isi['token'] = token;

  @override
  Future<void> clear() async {
    isi.clear();
    jumlahClear++;
  }
}

/// Adapter Dio yang membalas status dan body yang kita tentukan sendiri.
///
/// Dipakai supaya pengujian tidak pernah menyentuh jaringan sungguhan.
/// Menggantungkan diri pada server produksi di dalam test adalah cara rapuh:
/// tes jadi lambat, tidak jalan offline, dan bisa menembak server aslinya
/// dengan kredensial ngawur.
class _AdapterPalsu implements HttpClientAdapter {
  _AdapterPalsu(this.status, this.body);

  final int status;
  final Object body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );

  @override
  void close({bool force = false}) {}
}

ApiClient _clientStub(_StorePalsu store, {int status = 401, Object? body}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://uji.lokal',
      validateStatus: (s) => s != null && s < 500,
    ),
  );
  dio.httpClientAdapter =
      _AdapterPalsu(status, body ?? {'statusCode': status});
  return ApiClient(secureStore: store, dio: dio);
}

/// Bug yang diperbaiki: password salah memunculkan "Token tidak valid atau
/// sudah kedaluwarsa" dan ikut menghapus sesi.
///
/// Kalimat itu menyesatkan karena tidak ada hubungannya dengan yang diketik
/// pengguna. Dan menghapus sesi berarti login gagal yang sah bisa membuat
/// operator yang tadinya sudah masuk kehilangan sesinya.
void main() {
  test('password salah: pesan menyebut username atau password', () async {
    final store = _StorePalsu();
    final auth = AuthProvider(
      AuthRepository(_clientStub(store), store),
    );

    final ok = await auth.login(username: 'admin', password: 'salah');

    expect(ok, isFalse);
    expect(auth.error, 'Username atau password salah.');
  });

  test('password salah tidak menghapus sesi dan tidak memicu logout', () async {
    final store = _StorePalsu();
    final client = _clientStub(store, body: {
      'statusCode': 401,
      'message': 'Invalid credentials',
    });
    var unauthorizedDipanggil = false;
    client.onUnauthorized = () => unauthorizedDipanggil = true;

    final auth = AuthProvider(AuthRepository(client, store));
    await auth.login(username: 'admin', password: 'salah');

    expect(unauthorizedDipanggil, isFalse,
        reason: '401 dari login bukan berarti sesi habis');
    expect(store.jumlahClear, 0,
        reason: 'sesi tidak boleh dihapus hanya karena password salah');
  });

  test('401 dengan token yang disimpan tetap berarti sesi habis', () async {
    final store = _StorePalsu()..isi['token'] = 'token-lama';
    final client = _clientStub(store);
    var unauthorizedDipanggil = false;
    client.onUnauthorized = () => unauthorizedDipanggil = true;

    // Pengaman: kalau nanti kondisi "token ada" dihapus, proteksi logout
    // otomatis ini ikut hilang, dan tes inilah yang akan menangkapnya.
    await expectLater(
      client.get('/pcs'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('kedaluwarsa'),
        ),
      ),
    );
    expect(unauthorizedDipanggil, isTrue);
    expect(store.jumlahClear, 1);
  });
}
