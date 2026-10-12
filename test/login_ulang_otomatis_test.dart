import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v3netbill_mobile/core/network/api_client.dart';
import 'package:v3netbill_mobile/core/storage/secure_store.dart';
import 'package:v3netbill_mobile/features/auth/data/auth_repository.dart';

/// Respons untuk satu pemanggilan.
class _Resp {
  _Resp(this.status, this.body);

  final int status;
  final Object body;
}

/// Adapter yang bisa membalas BERBEDA untuk path yang berbeda.
///
/// Diperlukan karena uji ini soal *dua* request berbeda dalam satu alur:
/// request aslinya yang kena 401, lalu `POST /auth/login` untuk perpanjang
/// sesi. Adapter yang selalu balas status sama (seperti yang dipakai uji
/// sebelumnya) tidak bisa membuktikannya.
class _AdapterPeta implements HttpClientAdapter {
  _AdapterPeta(this.peta);

  final Map<String, List<_Resp>> peta;
  final List<String> pathDipanggil = [];

  /// Berapa kali path tertentu dipanggil.
  int hitung(String path) => pathDipanggil.where((p) => p == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    pathDipanggil.add(options.path);
    final antre = peta[options.path];
    if (antre == null || antre.isEmpty) {
      return _balas(404, {'message': 'path tidak terdaftar di adapter uji'});
    }
    final r = antre.removeAt(0);
    return _balas(r.status, r.body);
  }

  ResponseBody _balas(int status, Object body) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

/// Tiruan [SecureStore] yang isinya bisa dilihat dari luar.
class _StorePalsu extends SecureStore {
  final isi = <String, String>{};
  int jumlahClear = 0;
  int jumlahSimpan = 0;

  @override
  Future<String?> readToken() async => isi['token'];

  @override
  Future<String?> readUsername() async => isi['username'];

  @override
  Future<String?> readPassword() async => isi['password'];

  @override
  Future<bool> bisaLoginUlang() async =>
      (isi['username'] ?? '').isNotEmpty && (isi['password'] ?? '').isNotEmpty;

  @override
  Future<void> saveSession({
    required String token,
    required String role,
    required String username,
    String? password,
  }) async {
    jumlahSimpan++;
    isi['token'] = token;
    isi['role'] = role;
    isi['username'] = username;
    if (password != null) isi['password'] = password;
  }

  @override
  Future<void> clear() async {
    isi.clear();
    jumlahClear++;
  }
}

ApiClient _client(_StorePalsu store, _AdapterPeta adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://uji.lokal',
      // Sama dengan ApiClient produksi: status < 500 dikembalikan, bukan
      // dilempar, supaya angka 401 bisa dibaca sendiri.
      validateStatus: (s) => s != null && s < 500,
    ),
  )..httpClientAdapter = adapter;
  return ApiClient(secureStore: store, dio: dio);
}

void main() {
  const loginSukses = {
    'access_token': 'token-baru',
    'role': 'ADMIN',
    'username': 'aziz',
  };

  test('token kedaluwarsa: sesi diperpanjang sendiri lalu request diulang',
      () async {
    final store = _StorePalsu()
      ..isi['token'] = 'token-lama'
      ..isi['username'] = 'aziz'
      ..isi['password'] = 'rahasia';

    final adapter = _AdapterPeta({
      '/pcs': [
        _Resp(401, {'message': 'Unauthorized'}),
        _Resp(200, [
          {'namaPc': 'PC001'}
        ]),
      ],
      '/auth/login': [_Resp(200, loginSukses)],
    });
    final client = _client(store, adapter);
    var unauthorizedDipanggil = false;
    client.onUnauthorized = () => unauthorizedDipanggil = true;

    final hasil = await client.get('/pcs');

    expect(hasil, isA<List<dynamic>>());
    expect(store.isi['token'], 'token-baru',
        reason: 'token baru harus menggantikan yang kedaluwarsa');
    expect(unauthorizedDipanggil, isFalse,
        reason: 'sesi berhasil diperpanjang, jadi tidak boleh dicabut');
    expect(store.jumlahClear, 0);
    expect(adapter.hitung('/auth/login'), 1);
  });

  test('password tersimpan salah: sesi dicabut dan logout dipanggil', () async {
    final store = _StorePalsu()
      ..isi['token'] = 'token-lama'
      ..isi['username'] = 'aziz'
      ..isi['password'] = 'salah';

    final adapter = _AdapterPeta({
      '/pcs': [
        _Resp(401, {'message': 'Unauthorized'})
      ],
      '/auth/login': [
        _Resp(401, {'message': 'Invalid credentials'}),
      ],
    });
    final client = _client(store, adapter);
    var unauthorizedDipanggil = false;
    client.onUnauthorized = () => unauthorizedDipanggil = true;

    await expectLater(client.get('/pcs'), throwsA(isA<Object>()));

    expect(unauthorizedDipanggil, isTrue);
    expect(store.jumlahClear, 1);
    expect(store.isi.containsKey('password'), isFalse,
        reason:
            'password salah harus dibuang, bukan disimpan untuk dicoba lagi');
  });

  test('tidak ada kredensial tersimpan: tidak mencoba login ulang', () async {
    final store = _StorePalsu()..isi['token'] = 'token-lama';

    final adapter = _AdapterPeta({
      '/pcs': [
        _Resp(401, {'message': 'Unauthorized'})
      ],
    });
    final client = _client(store, adapter);
    var unauthorizedDipanggil = false;
    client.onUnauthorized = () => unauthorizedDipanggil = true;

    await expectLater(client.get('/pcs'), throwsA(isA<Object>()));

    expect(adapter.hitung('/auth/login'), 0,
        reason: 'tanpa kredensial tidak ada yang bisa dicoba');
    expect(unauthorizedDipanggil, isTrue);
  });

  test('login gagal tidak mengulang request tanpa batas', () async {
    final store = _StorePalsu()
      ..isi['token'] = 'token-lama'
      ..isi['username'] = 'aziz'
      ..isi['password'] = 'salah';

    final adapter = _AdapterPeta({
      '/pcs': [
        _Resp(401, {'message': 'Unauthorized'}),
        //Kalau ada loop, request kedua ini akan tercipta.
        _Resp(200, ['tidak seharusnya tercapai']),
      ],
      // Server yang selalu menolak -> harus berhenti pada percobaan pertama.
      '/auth/login': [
        _Resp(401, {'message': 'Invalid credentials'}),
        _Resp(401, {'message': 'Invalid credentials'}),
      ],
    });
    final client = _client(store, adapter);

    await expectLater(client.get('/pcs'), throwsA(isA<Object>()));

    expect(adapter.hitung('/auth/login'), 1,
        reason: 'percobaan login ulang harus tepat satu');
    expect(adapter.hitung('/pcs'), 1,
        reason: 'request asal tidak boleh diulang kalau login ulang gagal');
  });

  test('login yang berhasil menyimpan password untuk perpanjangan', () async {
    final store = _StorePalsu();
    final adapter = _AdapterPeta({
      '/auth/login': [_Resp(200, loginSukses)],
    });
    // ⚠️ Penyimpanan sesi itu tugas [AuthRepository], BUKAN [ApiClient].
    // Tes pertama-tama sempat salah meletakkannya di sini dan gagal —
    // gejalanya "token tidak tersimpan", padahal tiap lapisan memang
    // benar: ApiClient cuma mengambil dan melempar, baru repository yang
    // menyimpan. MenAssert lapisan yang salah bikin tes hijau saat
    // fiturnya benar-benar tidak ada.
    final repo = AuthRepository(_client(store, adapter), store);

    final sesi = await repo.login(username: 'aziz', password: 'rahasia');

    expect(sesi.token, 'token-baru');
    expect(store.isi['token'], 'token-baru');
    expect(store.isi['username'], 'aziz');
    expect(store.isi['password'], 'rahasia',
        reason: 'tanpa ini sesi tidak bisa diperpanjang sendiri nanti');
    expect(await store.bisaLoginUlang(), isTrue);
  });

  test('logout menghapus password, bukan cuma token', () async {
    final store = _StorePalsu()
      ..isi['token'] = 't'
      ..isi['role'] = 'ADMIN'
      ..isi['username'] = 'aziz'
      ..isi['password'] = 'rahasia';
    final repo = AuthRepository(_client(store, _AdapterPeta({})), store);

    await repo.logout();

    expect(store.isi.containsKey('password'), isFalse,
        reason: 'meninggalkannya berarti login ulang otomatis masih bisa jalan '
            'untuk siapa pun yang memakai HP itu');
    expect(store.isi.containsKey('token'), isFalse);
  });
}
