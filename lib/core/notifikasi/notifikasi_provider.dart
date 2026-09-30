import 'dart:async';

import 'package:flutter/foundation.dart';

import '../storage/secure_store.dart';
import 'notifikasi_lokal.dart';
import 'notifikasi_repository.dart';
import 'push_client.dart';

/// Mengatur notifikasi push untuk login pelanggan di komputer warnet.
///
/// Tiga hal yang dijaga di sini, semuanya terkait satu keputusan: notifikasi
/// hanya untuk akun **admin**.
///
///  1. Daftar token saat login sebagai admin.
///  2. Cabut token saat login sebagai kasir, dan saat logout.
///  3. Cabut token saat sakelar dimatikan.
///
/// Poin 2 tidak boleh dilewat. Kalau tidak, HP yang pernah dipakai admin lalu
/// logout akan tetap menerima notifikasi admin hanya karena token-nya masih
/// tersimpan di server. Itu kebocoran informasi ke perangkat yang salah, jadi
/// lebih baik gagal diam-diam daripada menerima notifikasi yang tidak
/// seharusnya.
class NotifikasiProvider extends ChangeNotifier {
  NotifikasiProvider({
    required NotifikasiRepository repository,
    required SecureStore store,
    PushClient? push,
    NotifikasiLokal lokal = const NotifikasiLokal(),
  })  : _repo = repository,
        _store = store,
        _push = push,
        _lokal = lokal;

  final NotifikasiRepository _repo;
  final SecureStore _store;
  final PushClient? _push;
  final NotifikasiLokal _lokal;

  /// Pesan yang masuk saat aplikasi terbuka. Ditonton `AppShell` untuk
  /// menampilkan banner di dalam aplikasi.
  final StreamController<PushPesan> _banner =
      StreamController<PushPesan>.broadcast();

  Stream<PushPesan> get banner => _banner.stream;

  Future<void>? _siapFuture;
  bool _aktif = true;
  bool _izinDimintaSudah = false;
  bool _izinDiberikan = false;
  bool _diaturUntukSesiIni = false;
  String? _tokenTerdaftar;

  /// Sakelar dari halaman Profile. Default true: yang baru dipasang harus
  /// langsung bekerja, dan tidak ada yang harus mencari pengaturan dulu.
  bool get aktif => _aktif;

  /// True kalau izin notifikasi sistem sudah diberikan.
  ///
  /// Penting untuk ditampilkan ke kasir: sakelar yang nyala tapi izinnya
  /// belum diberikan akan terlihat berfungsi padahal tidak pernah ada
  /// notifikasi yang muncul.
  bool get izinDiberikan => _izinDiberikan;

  /// True kalau ini sesi milik admin. Kasir tidak pernah didaftarkan.
  bool get untukAdmin => _diaturUntukSesiIni;

  /// Baca sakelar dari penyimpanan dan siapkan channel notifikasi.
  ///
  /// Aman dipanggil berulang, dan TIDAK melempar error kalau Firebase belum
  /// terinisialisasi: aplikasi harus tetap bisa dipakai untuk berjualan.
  ///
  /// Yang dikembalikan adalah Future, bukan void, dan itu bukan kebetulan.
  /// Pembacaan penyimpanan itu async, jadi kalau `setAktif` jalan sebelum
  /// selesai, nilai dari storage akan menimpa pilihan pengguna. Semua pemanggil
  /// yang mengubah sakelar harus `await muat()` lebih dulu.
  Future<void> muat() {
    if (_siapFuture != null) return _siapFuture!;
    final proses = _muatSekali();
    _siapFuture = proses;
    return proses;
  }

  Future<void> _muatSekali() async {
    _aktif = await _bacaAktif();
    notifyListeners();
    try {
      await _lokal.siapkanChannel();
    } catch (_) {
      // Channel gagal dibuat: notifikasi tetap terkirim, hanya tanpa suara.
    }
    _dengarTokenBerubah();
    _dengarPesan();
  }

  Future<bool> _bacaAktif() async {
    try {
      return await _store.readNotifikasiSesi() ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setAktif(bool nilai) async {
    // Wajib: kalau belum, nilai dari penyimpanan akan menimpa pilihan ini.
    await muat();
    if (_aktif == nilai) return;
    _aktif = nilai;
    notifyListeners();
    try {
      await _store.saveNotifikasiSesi(nilai);
    } catch (_) {
      // Sakelar tetap berlaku di sesi ini walau gagal disimpan.
    }
  }

  /// Dipanggil setelah login berhasil.
  ///
  /// [role] diambil dari session yang tersimpan, bukan dari argumen bebas,
  /// supaya tidak ada jalur yang bisa membuat kasir terdaftar sebagai admin.
  Future<void> setelahLogin({required bool admin}) async {
    await muat();
    if (!admin || !_aktif) {
      await cabutToken();
      return;
    }
    final izin = await _mintaIzin();
    if (!izin) {
      await cabutToken();
      return;
    }
    await daftarToken();
  }

  /// Dipanggil sebelum atau sesudah logout.
  Future<void> sebelumLogout() async {
    await cabutToken();
  }

  /// Minta izin notifikasi, tapi hanya sekali per pemakaian aplikasi.
  ///
  /// Android hanya menampilkan dialog izin itu sendiri-sendiri, jadi meminta
  /// ulang setelah dijawab tidak ada gunanya.
  Future<bool> _mintaIzin() async {
    if (_izinDimintaSudah) return _izinDiberikan;
    final push = _push;
    if (push == null) {
      _izinDiberikan = true;
      return true;
    }
    _izinDimintaSudah = true;
    try {
      _izinDiberikan = await push.mintaIzin();
    } catch (_) {
      _izinDiberikan = false;
    }
    notifyListeners();
    return _izinDiberikan;
  }

  Future<void> daftarToken() async {
    final push = _push;
    if (push == null) return;
    try {
      final token = await push.token();
      if (token == null || token.isEmpty) return;
      await _repo.daftar(token);
      _tokenTerdaftar = token;
      _diaturUntukSesiIni = true;
      notifyListeners();
    } catch (_) {
      // Tidak menggagalkan apa pun. Notifikasi hilang, aplikasi tetap jalan.
    }
  }

  /// Cabut token dari server dan dari perangkat.
  Future<void> cabutToken() async {
    _diaturUntukSesiIni = false;
    notifyListeners();
    final push = _push;
    if (push == null) return;
    try {
      await _repo.hapus(_tokenTerdaftar ?? await push.token() ?? '');
    } catch (_) {
      // Diabaikan dengan sengaja.
    }
    try {
      await push.hapusToken();
    } catch (_) {
      // Menghapus token di perangkat adalah pembersihan, bukan keharusan.
    }
  }

  void _dengarTokenBerubah() {
    _push?.tokenBerubah().listen((token) async {
      // Token berubah berarti token lama sudah tidak berlaku. Daftarkan yang
      // baru, dan hanya kalau sesi ini memang milik admin.
      if (!_diaturUntukSesiIni || !_aktif) return;
      _tokenTerdaftar = null;
      try {
        await _repo.daftar(token);
        _tokenTerdaftar = token;
      } catch (_) {
        // Diabaikan dengan sengaja.
      }
    });
  }

  void _dengarPesan() {
    _push?.pesanMasuk().listen((pesan) {
      if (!_aktif) return;
      // Jangan kirim ke stream yang sudah ditutup saat aplikasi ditutup.
      if (_banner.isClosed) return;
      _banner.add(pesan);
    });
  }

  @override
  void dispose() {
    _banner.close();
    super.dispose();
  }
}
