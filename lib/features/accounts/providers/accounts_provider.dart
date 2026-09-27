import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/account_repository.dart';
import '../models/account.dart';

/// Menyimpan daftar akun, tab aktif, pencarian, dan pilihan untuk aksi massal.
class AccountsProvider extends ChangeNotifier {
  AccountsProvider(this._repo);

  final AccountRepository _repo;

  List<Account> _all = const [];
  bool _loading = false;
  String? _error;

  AccountType _tab = AccountType.voucher;
  String _search = '';
  final Set<String> _selected = <String>{};

  List<Account> get all => _all;
  bool get loading => _loading;
  String? get error => _error;
  AccountType get tab => _tab;
  String get search => _search;
  Set<String> get selected => _selected;
  int get selectedCount => _selected.length;

  /// Hanya akun milik tab yang sedang aktif.
  List<Account> get visible => AccountRepository.filterLocally(
      _all.where((a) => a.tipe == _tab).toList(), _search);

  /// Total seluruh tipe, dipakai untuk badge di tab.
  int countOf(AccountType t) => _all.where((a) => a.tipe == t).length;

  bool isSelected(String id) => _selected.contains(id);

  void setTab(AccountType t) {
    if (_tab == t) return;
    _tab = t;
    _selected.clear();
    notifyListeners();
  }

  void setSearch(String value) {
    _search = value;
    notifyListeners();
  }

  void toggleSelect(String id) {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    notifyListeners();
  }

  void selectAllVisible() {
    final ids = visible.map((a) => a.id).toSet();
    final semuaSudah = ids.every(_selected.contains);
    if (semuaSudah) {
      _selected.removeAll(ids);
    } else {
      _selected.addAll(ids);
    }
    notifyListeners();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      _all = await _repo.fetchAll();
      _error = null;
    } on ApiException catch (e) {
      _error = e.displayMessage;
    } catch (e) {
      _error = 'Gagal memuat daftar akun.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> createVoucher(int nominal) => _mutate(
        () async {
          await _repo.createVoucher(nominal: nominal);
        },
        'Gagal membuat voucher.',
      );

  /// Membuat voucher lalu mengembalikan objek barunya, bukan hanya status.
  ///
  /// Dipakai dialog "Mulai Sesi": begitu akun baru dibuat, kodenya langsung
  /// dipakai untuk memulai sesi, jadi pemanggil wajib menerima kode barunya.
  /// Mengembalikan null kalau gagal, dan alasannya ada di [error].
  Future<Account?> createVoucherDapatKode(int nominal) => _createAndReturn(
        () => _repo.createVoucher(nominal: nominal),
      );

  /// Sama seperti [createVoucherDapatKode], tapi untuk member.
  Future<Account?> createMemberDapatKode({
    required String nama,
    required String password,
    required int nominal,
  }) =>
      _createAndReturn(
        () => _repo.createMember(
          nama: nama,
          password: password,
          nominal: nominal,
        ),
      );

  Future<Account?> _createAndReturn(Future<Account> Function() action) async {
    _error = null;
    try {
      final account = await action();
      await load(silent: true);
      return account;
    } on ApiException catch (e) {
      _error = e.displayMessage;
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Gagal membuat akun.';
      notifyListeners();
      return null;
    }
  }

  Future<bool> createMember({
    required String nama,
    required String password,
    required int nominal,
  }) =>
      _mutate(
        () async {
          await _repo.createMember(
            nama: nama,
            password: password,
            nominal: nominal,
          );
        },
        'Gagal membuat member.',
      );

  Future<bool> topupSelected(int amount) => _mutateSelected(
        (id) => _repo.topup(accountId: id, nominal: amount),
        'Gagal topup.',
      );

  Future<bool> withdrawSelected(int amount) => _mutateSelected(
        (id) => _repo.correct(accountId: id, nominal: amount),
        'Gagal menarik saldo.',
      );

  Future<bool> revokeSelected() => _mutateSelected(
        (id) => _repo.revoke(id),
        'Gagal menonaktifkan akun.',
      );

  Future<bool> revokeOne(String id) => _mutate(
        () => _repo.revoke(id),
        'Gagal menonaktifkan akun.',
      );

  Future<bool> _mutateSelected(
    Future<void> Function(String id) action,
    String failureMessage,
  ) async {
    if (_selected.isEmpty) return false;
    var ok = true;
    for (final id in List<String>.from(_selected)) {
      final success = await _mutate(() => action(id), failureMessage);
      ok = ok && success;
    }
    if (ok) _selected.clear();
    notifyListeners();
    return ok;
  }

  Future<bool> _mutate(
    Future<void> Function() action,
    String failureMessage,
  ) async {
    _error = null;
    try {
      await action();
      await load(silent: true);
      return true;
    } on ApiException catch (e) {
      _error = e.displayMessage;
      notifyListeners();
      return false;
    } catch (e) {
      _error = failureMessage;
      notifyListeners();
      return false;
    }
  }
}
