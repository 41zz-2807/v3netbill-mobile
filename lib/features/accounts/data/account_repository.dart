import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/account.dart';

/// Sumber data voucher dan member.
class AccountRepository {
  AccountRepository(this._api);

  final ApiClient _api;

  /// Ambil semua akun. Pencarian dikirim ke server lewat [search], dan
  /// [AccountRepository.filterLocally] dipakai sebagai cadangan supaya
  /// pencarian tetap jalan walau server tidak mendukungnya.
  ///
  /// PERLU DIKONFIRMASI: nama parameter pencarian di backend belum dipastikan
  /// (kandidat `q`, `q`, atau `search`). Yang sudah pasti ada `limit`.
  /// Kalau ternyata berbeda, cukup ganti nama key-nya satu baris di bawah.
  Future<List<Account>> fetchAll({
    String? search,
    AccountType? type,
    int limit = 200,
  }) async {
    final data = await _api.get(
      ApiConfig.accounts,
      query: {
        'limit': limit,
        if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
      },
    );
    if (data is! List) {
      throw ApiException('Format jawaban akun tidak dikenali.');
    }
    var list = data
        .whereType<Map>()
        .map((e) => Account.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    if (type != null) {
      list = list.where((a) => a.tipe == type).toList();
    }
    return filterLocally(list, search);
  }

  /// Pencarian di sisi klien, dipakai sebagai cadangan.
  static List<Account> filterLocally(List<Account> list, String? search) {
    final q = search?.trim().toLowerCase() ?? '';
    if (q.isEmpty) return list;
    return list
        .where((a) =>
            a.displayName.toLowerCase().contains(q) ||
            (a.nama?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  /// Buat voucher baru.
  ///
  /// PERLU DIKONFIRMASI: nama field body belum dipastikan. Yang sudah pasti
  /// dari aturan bisnis backend: `nominal` harus kelipatan 500, dan sisa
  /// waktu dihitung dari `nominal / harga_per_menit`.
  Future<Account> createVoucher({required int nominal}) async {
    final data = await _api.post(
      ApiConfig.accounts,
      data: {
        'tipe': 'VOUCHER',
        'nominal': nominal,
      },
    );
    return Account.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Buat member baru.
  ///
  /// PERLU DIKONFIRMASI: sama seperti [createVoucher], nama field belum
  /// dipastikan. Untuk member, `nominal` berarti saldo awal.
  Future<Account> createMember({
    required String nama,
    required int nominal,
  }) async {
    final data = await _api.post(
      ApiConfig.accounts,
      data: {
        'tipe': 'MEMBER',
        'nama': nama,
        'nominal': nominal,
      },
    );
    return Account.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Tambah saldo / tambah waktu.
  ///
  /// PERLU DIKONFIRMASI: endpoint dan body belum dipastikan. Yang jelas dari
  /// aplikasi web: aksi ini memakai dropdown "Topup" dan tercatat sebagai
  /// transaksi bertipe `TOPUP`.
  Future<void> topup({
    required String accountId,
    required int amount,
  }) async {
    await _api.post(
      '${ApiConfig.accounts}/$accountId/topup',
      data: {'nominal': amount},
    );
  }

  /// Kurangi saldo / tarik waktu.
  ///
  /// PERLU DIKONFIRMASI: lihat catatan di [topup].
  Future<void> withdraw({
    required String accountId,
    required int amount,
  }) async {
    await _api.post(
      '${ApiConfig.accounts}/$accountId/withdraw',
      data: {'nominal': amount},
    );
  }

  /// Nonaktifkan akun (revoke).
  ///
  /// PERLU DIKONFIRMASI: aplikasi web memakai aksi "Revoke" yang
  /// kemungkinan besar memanggil `PATCH /accounts/:id` dengan
  /// `{ status: 'REVOKED' }`.
  Future<void> revoke(String accountId) async {
    await _api.patch(
      '${ApiConfig.accounts}/$accountId',
      data: {'status': 'REVOKED'},
    );
  }
}
