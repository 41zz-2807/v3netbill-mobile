import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/pc.dart';

/// Sumber data PC.
///
/// Catatan penting: di aplikasi web, aksi PC (kunci, matikan) dikirim lewat
/// WebSocket (`dashboard:lock_pc` dan `dashboard:shutdown_pc`), bukan REST.
/// Peta ini ditulis memakai REST lebih dulu karena jauh lebih sederhana.
/// Kalau ternyata backend web menyediakan REST-nya, cukup ganti isi method
/// di bawah tanpa menyentuh widget sama sekali.
class PcRepository {
  PcRepository(this._api);

  final ApiClient _api;

  /// Ambil daftar semua PC.
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
  /// PERLU DIKONFIRMASI: nama endpoint dan bentuk body belum dipastikan.
  /// Aplikasi web memakai socket `client:login_request` dengan
  /// `{ pcId, agentToken, kode, password }`. Yang mana yang benar untuk REST
  /// harus dicek ke backend sebelum fitur ini dipakai.
  Future<void> startSession({
    required String pcId,
    required String kode,
    required String password,
  }) async {
    await _api.post(
      '${ApiConfig.pcs}/$pcId/session',
      data: {'kode': kode, 'password': password},
    );
  }

  /// Hentikan sesi yang sedang berjalan.
  ///
  /// PERLU DIKONFIRMASI: lihat catatan di [startSession].
  Future<void> stopSession(String pcId) async {
    await _api.post('${ApiConfig.pcs}/$pcId/session/stop');
  }

  /// Kunci layar PC.
  ///
  /// PERLU DIKONFIRMASI: aplikasi web memakai socket `dashboard:lock_pc`.
  Future<void> lock(String pcId) async {
    await _api.post('${ApiConfig.pcs}/$pcId/lock');
  }

  /// Matikan atau shutdown PC.
  ///
  /// PERLU DIKONFIRMASI: aplikasi web memakai socket `dashboard:shutdown_pc`.
  Future<void> shutdown(String pcId) async {
    await _api.post('${ApiConfig.pcs}/$pcId/shutdown');
  }
}
