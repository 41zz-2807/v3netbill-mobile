import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/socket_service.dart';
import '../models/pc.dart';

/// Sumber data PC.
///
/// Pembagian tanggung jawabnya penting dan sudah mengikuti backend:
///
/// - **Daftar PC** diambil lewat REST `GET /pcs`, karena itu endpoint-nya
///   benar-benar ada.
/// - **Aksi PC** (mulai sesi, kunci, matikan) dan **status realtime** lewat
///   Socket.IO, karena backend hanya menyediakan perintah itu lewat socket
///   (`dashboard:start_pc`, `dashboard:lock_pc`, `dashboard:shutdown_pc`).
///   Dicoba lewat REST lebih dulu dan memang tidak ada, jadi tidak dikarang.
class PcRepository {
  PcRepository(this._api, this._socket);

  final ApiClient _api;
  final SocketService _socket;

  /// Ambil daftar semua PC lewat REST.
  Future<List<Pc>> fetchAll() async {
    final data = await _api.get(ApiConfig.pcs);
    if (data is! List) {
      throw ApiException('Format jawaban PC tidak dikenali.');
    }
    return data
        .whereType<Map>()
        .map((e) => Pc.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  /// Mulai sesi di PC dengan kode voucher atau member.
  ///
  /// Backend hanya meminta kode, tanpa password, karena proses ini dilakukan
  /// dari sisi operator dan bukan dari layar PC.
  Future<SocketResult> startSession({
    required String pcId,
    required String kode,
  }) {
    return _socket.startPc(pcId: pcId, kode: kode);
  }

  /// Akhiri sesi yang sedang berjalan.
  ///
  /// Backend tidak menyediakan perintah stop khusus untuk operator. Yang
  /// dipakai adalah `dashboard:lock_pc`, yang di server memanggil
  /// `unlockPc`, jadi sesi berakhir dan layar PC ikut terkunci.
  ///
  /// Perintah `client:stop_session` yang terdengar lebih umum sebenarnya
  /// hanya untuk agent di dalam PC, karena brutally memerlukan pcId dan
  /// agentToken pada handshake.
  Future<SocketResult> endSession(String pcId) => _socket.lockPc(pcId);

  /// Kunci layar PC.
  Future<SocketResult> lock(String pcId) => _socket.lockPc(pcId);

  /// Matikan atau shutdown PC.
  Future<SocketResult> shutdown(String pcId) => _socket.shutdownPc(pcId);
}
