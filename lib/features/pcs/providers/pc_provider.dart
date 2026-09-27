import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/socket_service.dart';
import '../data/pc_repository.dart';
import '../models/pc.dart';

/// Menyimpan daftar PC beserta aksi yang sedang berjalan.
///
/// Status PC dikirim backend lewat event Socket.IO `dashboard:pc_update`,
/// jadi tidak perlu polling. Socket otomatis menyambung ulang bila
/// koneksi putus.
class PcProvider extends ChangeNotifier {
  PcProvider(this._repo, this._socket);

  final PcRepository _repo;
  final SocketService _socket;

  List<Pc> _pcs = const [];
  bool _loading = false;
  bool _socketUp = false;
  String? _error;
  bool _started = false;

  /// Id PC yang sedang menjalankan aksi, supaya tombolnya bisa dinonaktifkan.
  final Set<String> _busy = <String>{};

  List<Pc> get pcs => _pcs;
  bool get loading => _loading;
  String? get error => _error;

  /// True kalau koneksi Socket.IO sedang hidup.
  bool get realtime => _socketUp;

  int get totalAktif => _pcs.where((p) => p.status == PcStatus.active).length;
  int get totalIdle => _pcs.where((p) => p.status == PcStatus.idle).length;
  int get totalOffline =>
      _pcs.where((p) => p.status == PcStatus.offline).length;

  bool isBusy(String pcId) => _busy.contains(pcId);

  /// Muat sekali dari REST lalu nyalakan realtime. Aman dipanggil ulang.
  Future<void> init() async {
    if (_started) return;
    _started = true;

    _socket.onConnectionChange = (up) {
      _socketUp = up;
      notifyListeners();
    };

    _socket.onPcUpdate = (list) {
      _pcs = list.map(Pc.fromJson).toList(growable: false);
      notifyListeners();
    };

    await load();
    await _socket.connect();
  }

  /// Muat ulang dari REST. Dipakai saat pull-to-refresh.
  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      _pcs = await _repo.fetchAll();
      _error = null;
    } on ApiException catch (e) {
      _error = e.displayMessage;
    } catch (e) {
      _error = 'Gagal memuat daftar PC.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Mulai sesi di PC dengan kode voucher atau member.
  Future<String?> startSession({
    required String pcId,
    required String kode,
  }) async {
    final err = await _run(
      pcId,
      () => _repo.startSession(pcId: pcId, kode: kode),
      'Gagal memulai sesi.',
    );
    return err;
  }

  Future<String?> lock(String pcId) =>
      _run(pcId, () => _repo.lock(pcId), 'Gagal mengunci PC.');

  Future<String?> shutdown(String pcId) =>
      _run(pcId, () => _repo.shutdown(pcId), 'Gagal mematikan PC.');

  Future<String?> endSession(String pcId) => _run(
        pcId,
        () => _repo.endSession(pcId),
        'Gagal mengakhiri sesi.',
      );

  /// Jalankan satu aksi. Mengembalikan null kalau berhasil, atau pesan error
  /// kalau gagal. Dipanggil sekali saja per aksi.
  Future<String?> _run(
    String pcId,
    Future<SocketResult> Function() action,
    String fallback,
  ) async {
    if (_busy.contains(pcId)) return 'Aksi masih berjalan.';
    _busy.add(pcId);
    _error = null;
    notifyListeners();

    try {
      final r = await action();
      if (!r.success) {
        return r.message ?? fallback;
      }
      // Status berubah di server, jadi segarkan daftar dari REST.
      await load(silent: true);
      return null;
    } catch (e) {
      if (e is ApiException) return e.displayMessage;
      return fallback;
    } finally {
      _busy.remove(pcId);
      notifyListeners();
    }
  }

  /// Bersihkan daftar dan putuskan socket saat pengguna keluar.
  void clear() {
    _socket.disconnect();
    _pcs = const [];
    _error = null;
    _busy.clear();
    _socketUp = false;
    _started = false;
    notifyListeners();
  }
}
