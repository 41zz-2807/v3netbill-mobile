import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/pc_repository.dart';
import '../models/pc.dart';

/// Menyimpan daftar PC beserta aksi yang sedang berjalan.
///
/// Status PC dimuat ulang otomatis setiap [pollInterval] supaya angka di
/// dashboard tidak basi. Dipakai polling REST, bukan WebSocket, karena
/// protocol Socket.IO di backend belum diverifikasi. Kalau nanti sudah jelas,
/// bagian [_startPolling] tinggal diganti dengan listener socket tanpa
/// menyentuh widget.
class PcProvider extends ChangeNotifier {
  PcProvider(this._repo);

  final PcRepository _repo;

  /// Jeda antar pemuatan ulang status.
  static const pollInterval = Duration(seconds: 10);

  List<Pc> _pcs = const [];
  bool _loading = false;
  bool _polling = false;
  String? _error;
  Timer? _timer;

  /// Id PC yang sedang menjalankan aksi, supaya tombolnya bisa dinonaktifkan.
  final Set<String> _busy = <String>{};

  List<Pc> get pcs => _pcs;
  bool get loading => _loading;
  String? get error => _error;

  int get totalAktif => _pcs.where((p) => p.status == PcStatus.active).length;
  int get totalIdle => _pcs.where((p) => p.status == PcStatus.idle).length;
  int get totalOffline =>
      _pcs.where((p) => p.status == PcStatus.offline).length;

  bool isBusy(String pcId) => _busy.contains(pcId);

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

  /// Nyalakan pemuatan berkala. Aman dipanggil berkali-kali.
  void startPolling() {
    if (_polling) return;
    _polling = true;
    _timer = Timer.periodic(pollInterval, (_) => load(silent: true));
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
    _polling = false;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }

  /// Mulai sesi di PC dengan kode voucher atau member.
  Future<bool> startSession({
    required String pcId,
    required String kode,
    required String password,
  }) {
    return _run(
      pcId,
      () => _repo.startSession(pcId: pcId, kode: kode, password: password),
      'Gagal memulai sesi.',
    );
  }

  Future<bool> lock(String pcId) =>
      _run(pcId, () => _repo.lock(pcId), 'Gagal mengunci PC.');

  Future<bool> shutdown(String pcId) => _run(
        pcId,
        () => _repo.shutdown(pcId),
        'Gagal mematikan PC.',
      );

  Future<bool> stopSession(String pcId) => _run(
        pcId,
        () => _repo.stopSession(pcId),
        'Gagal menghentikan sesi.',
      );

  /// Membungkus satu aksi: tandai sibuk, jalankan, lalu muat ulang daftar
  /// supaya status di layar ikut berubah.
  Future<bool> _run(
    String pcId,
    Future<void> Function() action,
    String failureMessage,
  ) async {
    if (_busy.contains(pcId)) return false;
    _busy.add(pcId);
    _error = null;
    notifyListeners();

    try {
      await action();
      await load(silent: true);
      return true;
    } on ApiException catch (e) {
      _error = e.displayMessage;
      return false;
    } catch (e) {
      _error = failureMessage;
      return false;
    } finally {
      _busy.remove(pcId);
      notifyListeners();
    }
  }

  /// Bersihkan daftar saat pengguna keluar.
  void clear() {
    stopPolling();
    _pcs = const [];
    _error = null;
    _busy.clear();
    notifyListeners();
  }
}
