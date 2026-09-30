import 'package:dio/dio.dart';

import '../network/api_client.dart';

/// Menyimpan dan menghapus token perangkat di backend.
///
/// Token hanya bermakna kalau backend tahu token itu milik siapa, jadi
/// pemanggil harus sudah login. Role tidak pernah dikirim: backend membacanya
/// dari JWT.
class NotifikasiRepository {
  NotifikasiRepository(this._api);

  final ApiClient _api;

  /// Daftarkan token. Idempoten: token yang sama dikirim ulang hanya
  /// memperbarui `lastSeenAt`.
  Future<bool> daftar(String token) async {
    final data = await _api.post('/notifikasi/token', data: {'token': token});
    return data is Map && data['success'] == true;
  }

  /// Hapus token. Dipanggil saat logout supaya notifikasi tidak lagi dikirim
  /// ke perangkat yang sudah tidak dipakai.
  ///
  /// Kegagalan di sini tidak boleh menggagalkan logout: kalau token-nya
  /// tertinggal di server, notifikasi tetap masuk ke HP ini, dan itu lebih
  /// merepotkan daripada satu baris sisa di database.
  Future<void> hapus(String token) async {
    try {
      await _api.raw.delete(
        '/notifikasi/token',
        data: {'token': token},
      );
    } on DioException {
      // Diabaikan dengan sengaja, lihat catatan di atas.
    }
  }
}
