import 'package:firebase_messaging/firebase_messaging.dart';

/// Pembungkus tipis di atas `FirebaseMessaging`.
///
/// Tujuannya satu: supaya [NotifikasiProvider] bisa diuji tanpa Firebase.
/// Semua Firebase dipindah ke sini, jadi test cukup memakai implementasi
/// palsu dan tidak pernah menyentuh plugin native.
abstract class PushClient {
  /// Token perangkat, atau null kalau belum bisa dibaca.
  Future<String?> token();

  /// Dipanggil kalau token berubah, mis. setelah aplikasi di-uninstall lalu
  /// dipasang lagi.
  Stream<String> tokenBerubah();

  /// Pesan yang tiba saat aplikasi sedang dibuka.
  ///
  /// FCM TIDAK menampilkan notifikasi otomatis untuk pesan saat aplikasi
  /// terbuka, jadi inilah yang harus ditangani. Notifikasi sistem
  /// yang muncul menutupi layar yang sedang dibaca kasir.
  Stream<PushPesan> pesanMasuk();

  /// Minta izin notifikasi. Mengembalikan true kalau sudah diberi.
  Future<bool> mintaIzin();

  /// Buang token dari perangkat ini.
  Future<void> hapusToken();
}

/// Notifikasi yang masuk ke aplikasi.
class PushPesan {
  const PushPesan(
      {required this.judul, required this.isi, this.data = const {}});

  final String judul;
  final String isi;
  final Map<String, dynamic> data;
}

class FirebasePushClient implements PushClient {
  FirebasePushClient({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Future<String?> token() => _messaging.getToken();

  @override
  Stream<String> tokenBerubah() => _messaging.onTokenRefresh;

  @override
  Stream<PushPesan> pesanMasuk() => FirebaseMessaging.onMessage.map(
        (m) => PushPesan(
          judul: m.notification?.title ?? 'v3Netbill',
          isi: m.notification?.body ?? '',
          data: m.data,
        ),
      );

  @override
  Future<bool> mintaIzin() async {
    final izin = await _messaging.requestPermission();
    return izin.authorizationStatus == AuthorizationStatus.authorized ||
        izin.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<void> hapusToken() => _messaging.deleteToken();
}
