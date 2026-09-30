import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:v3netbill_mobile/core/notifikasi/notifikasi_provider.dart';
import 'package:v3netbill_mobile/features/auth/data/auth_repository.dart';
import 'package:v3netbill_mobile/features/auth/models/user_session.dart';
import 'package:v3netbill_mobile/features/auth/providers/auth_provider.dart';
import 'package:v3netbill_mobile/core/notifikasi/notifikasi_repository.dart';
import 'package:v3netbill_mobile/core/notifikasi/push_client.dart';
import 'package:v3netbill_mobile/core/storage/secure_store.dart';

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository();

  @override
  Future<UserSession> login({
    required String username,
    required String password,
  }) async =>
      const UserSession(token: 't', role: 'ADMIN', username: 'admin');

  @override
  Future<UserSession?> restore() async => const UserSession(
        token: 't',
        role: 'ADMIN',
        username: 'admin',
      );

  @override
  Future<void> logout() async {}
}

class _FakeAuthRepositoryKasir implements AuthRepository {
  const _FakeAuthRepositoryKasir();

  @override
  Future<UserSession> login({
    required String username,
    required String password,
  }) async =>
      const UserSession(token: 't', role: 'KASIR', username: 'kasir');

  @override
  Future<UserSession?> restore() async => const UserSession(
        token: 't',
        role: 'KASIR',
        username: 'kasir',
      );

  @override
  Future<void> logout() async {}
}

class _FakeRepository implements NotifikasiRepository {
  final List<String> terdaftar = [];
  final List<String> dihapus = [];

  @override
  Future<bool> daftar(String token) async {
    terdaftar.add(token);
    return true;
  }

  @override
  Future<void> hapus(String token) async {
    dihapus.add(token);
  }
}

class _FakePush implements PushClient {
  _FakePush({this.izin = true});

  String? tokenAwal = 'token-1';
  bool izin;
  bool tokenDihapus = false;

  final StreamController<String> _tokenBerubah = StreamController.broadcast();
  final StreamController<PushPesan> _pesan = StreamController.broadcast();

  @override
  Future<String?> token() async => tokenAwal;

  @override
  Stream<String> tokenBerubah() => _tokenBerubah.stream;

  @override
  Stream<PushPesan> pesanMasuk() => _pesan.stream;

  @override
  Future<bool> mintaIzin() async => izin;

  @override
  Future<void> hapusToken() async {
    tokenDihapus = true;
    tokenAwal = null;
  }

  Future<void> tutup() async {
    await _tokenBerubah.close();
    await _pesan.close();
  }
}

/// Tunggu sampai sebuah Future selesai.
///
/// Rantai pendaftaran token punya beberapa lapis `await` (baca storage ->
/// minta izin -> ambil token -> daftar), jadi `delayed(Duration.zero)` satu
/// atau dua kali belum tentu cukup. Menunggu waktu nyata pendek lebih jujur
/// dan tidak rapuh kalau nanti ada lapis async yang bertambah.
Future<void> _tunggu({Duration? maksimal}) async {
  final batas =
      DateTime.now().add(maksimal ?? const Duration(milliseconds: 200));
  while (DateTime.now().isBefore(batas)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

NotifikasiProvider _buat({
  required _FakeRepository repo,
  required _FakePush push,
  SecureStore? store,
}) {
  return NotifikasiProvider(
    repository: repo,
    store: store ?? SecureStore(),
    push: push,
  );
}

/// Aturan main dari fitur ini: notifikasi hanya untuk akun ADMIN.
///
/// Kalau ini bocor, kasir di HP miliknya akan menerima informasiEMPIL
/// internal warnet. Itu sebabnya setiap jalur di bawah diuji terpisah.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('admin: token didaftarkan setelah login', () async {
    final repo = _FakeRepository();
    final push = _FakePush();
    final p = _buat(repo: repo, push: push);

    await p.setelahLogin(admin: true);

    expect(repo.terdaftar, ['token-1']);
    expect(p.untukAdmin, isTrue);
    p.dispose();
    await push.tutup();
  });

  test('kasir: token TIDAK didaftarkan, dan yang tertinggal dicabut', () async {
    final repo = _FakeRepository();
    final push = _FakePush();
    final p = _buat(repo: repo, push: push);

    // Skenario: HP pernah dipakai admin, lalu dipakai kasir.
    repo.terdaftar.add('token-lama');
    await p.setelahLogin(admin: false);

    expect(p.untukAdmin, isFalse);
    // Daftar tidak bertambah. Kalau ini iya, kasir jadi penerima notifikasi.
    expect(repo.terdaftar, ['token-lama']);
    expect(repo.dihapus, ['token-1']);
    p.dispose();
    await push.tutup();
  });

  test('sakelar mati: token tidak didaftarkan', () async {
    final repo = _FakeRepository();
    final push = _FakePush();
    final p = _buat(repo: repo, push: push);

    await p.setAktif(false);
    await p.setelahLogin(admin: true);

    expect(repo.terdaftar, isEmpty);
    p.dispose();
    await push.tutup();
  });

  test('izin ditolak: token tidak didaftarkan dan status dilaporkan', () async {
    final repo = _FakeRepository();
    final push = _FakePush(izin: false);
    final p = _buat(repo: repo, push: push);

    await p.setelahLogin(admin: true);

    expect(repo.terdaftar, isEmpty);
    // Penting: tanpa ini, sakelarnya terlihat menyala padahal tidak pernah
    // ada notifikasi yang muncul.
    expect(p.izinDiberikan, isFalse);
    p.dispose();
    await push.tutup();
  });

  test('token berubah didaftarkan ulang hanya untuk sesi admin', () async {
    final repo = _FakeRepository();
    final push = _FakePush();
    final p = _buat(repo: repo, push: push);
    await p.setelahLogin(admin: true);

    push._tokenBerubah.add('token-2');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(repo.terdaftar, ['token-1', 'token-2']);
    p.dispose();
    await push.tutup();
  });

  test('token berubah saat sesi kasir tidak mendaftarkan apa pun', () async {
    final repo = _FakeRepository();
    final push = _FakePush();
    final p = _buat(repo: repo, push: push);
    await p.setelahLogin(admin: false);

    push._tokenBerubah.add('token-2');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(repo.terdaftar, isEmpty);
    p.dispose();
    await push.tutup();
  });

  test('sebelumLogout mencabut token', () async {
    final repo = _FakeRepository();
    final push = _FakePush();
    final p = _buat(repo: repo, push: push);
    await p.setelahLogin(admin: true);

    await p.sebelumLogout();

    expect(repo.dihapus, ['token-1']);
    expect(push.tokenDihapus, isTrue);
    p.dispose();
    await push.tutup();
  });

  test('pesan hanya diteruskan ke banner saat sakelar nyala', () async {
    final repo = _FakeRepository();
    final push = _FakePush();
    final p = _buat(repo: repo, push: push);
    await p.setelahLogin(admin: true);

    final termo = <PushPesan>[];
    final langganan = p.banner.listen(termo.add);

    push._pesan
        .add(const PushPesan(judul: 'Sesi dimulai', isi: 'Member · PC-01'));
    await Future<void>.delayed(Duration.zero);
    expect(termo, hasLength(1));
    expect(termo.first.isi, 'Member · PC-01');

    await p.setAktif(false);
    push._pesan
        .add(const PushPesan(judul: 'Sesi dimulai', isi: 'Voucher · PC-02'));
    await Future<void>.delayed(Duration.zero);
    expect(termo, hasLength(1), reason: 'sakelar mati harus menahan banner');
    await langganan.cancel();
    p.dispose();
    await push.tutup();
  });

  group('AuthProvider memicu pendaftaran token', () {
    AuthProvider buatAuth(NotifikasiProvider? notifikasi) =>
        AuthProvider(const _FakeAuthRepository(), notifikasi);

    test('login sebagai admin mendaftarkan token', () async {
      final repo = _FakeRepository();
      final push = _FakePush();
      final p = _buat(repo: repo, push: push);
      final auth = buatAuth(p);

      await auth.login(username: 'admin', password: 'admin123');
      // `login()` melepas panggilannya supaya kasir tidak menunggu proses
      // jaringan notifikasi sebelum bisa mulai berjualan.
      await _tunggu();

      expect(repo.terdaftar, ['token-1']);
      p.dispose();
      await push.tutup();
    });

    test('sesi yang dipulihkan dari penyimpanan juga mendaftarkan token',
        () async {
      // Ini jalur yang TERLEWAT kalau hanya `login()` yang memanggil
      // pendaftaran. Setelah aplikasi di-update, data aplikasi tidak hilang,
      // jadi aplikasi membuka lewat `bootstrap()` dan `login()` tidak pernah
      // dipanggil. Gejalanya: izin notifikasi sudah diberikan, sakelar sudah
      // nyala, tapi tabel `Perangkat` tetap kosong.
      final repo = _FakeRepository();
      final push = _FakePush();
      final p = _buat(repo: repo, push: push);
      final auth = buatAuth(p);

      await auth.bootstrap();
      await _tunggu();

      expect(repo.terdaftar, ['token-1']);
      p.dispose();
      await push.tutup();
    });

    test('sesi kasir yang dipulihkan tidak mendaftarkan apa pun', () async {
      final repo = _FakeRepository();
      final push = _FakePush();
      final p = _buat(repo: repo, push: push);
      final auth = AuthProvider(const _FakeAuthRepositoryKasir(), p);

      await auth.bootstrap();
      await _tunggu();

      expect(repo.terdaftar, isEmpty);
      p.dispose();
      await push.tutup();
    });
  });
}
