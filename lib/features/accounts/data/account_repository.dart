import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/account.dart';

/// Sumber data voucher dan member.
///
/// Semua endpoint di sini sudah dibaca langsung dari backend, jadi nama path
/// dan nama field-nya bukan tebakan:
///
/// - `POST /accounts/voucher`  body `{ nominal }`
/// - `POST /accounts/member`   body `{ nama, password, nominal }`
/// - `POST /accounts/:id/topup`    body `{ nominal }`
/// - `POST /accounts/:id/koreksi`  body `{ nominal }`
/// - `POST /accounts/:id/revoke`    tanpa body
///
/// Backend mewajibkan `nominal` kelipatan 500 dengan nilai minimal 500.
class AccountRepository {
  AccountRepository(this._api);

  final ApiClient _api;

  static const minNominal = 500;

  /// Ambil semua akun. Pencarian difilter di sisi klien karena backend
  /// hanya menerima `tipe` dan `status` sebagai query, bukan kata kunci.
  Future<List<Account>> fetchAll(
      {AccountType? type, AccountStatus? status}) async {
    final data = await _api.get(
      ApiConfig.accounts,
      query: {
        if (type != null) 'tipe': type.wire,
        if (status != null) 'status': status.wire,
      },
    );
    if (data is! List) {
      throw ApiException('Format jawaban akun tidak dikenali.');
    }
    return data
        .whereType<Map>()
        .map((e) => Account.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  /// Buat voucher baru. Sisa waktu dihitung backend dari nominal.
  Future<Account> createVoucher({required int nominal}) async {
    _validasiNominal(nominal);
    final data = await _api.post(
      '${ApiConfig.accounts}/voucher',
      data: {'nominal': nominal},
    );
    return Account.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Buat member baru.
  ///
  /// Member wajib punya password karena kasir membukanya dari halaman
  /// kasir, dan backend mewajibkan panjang minimal 4 karakter.
  Future<Account> createMember({
    required String nama,
    required String password,
    required int nominal,
  }) async {
    _validasiNominal(nominal);
    if (nama.trim().isEmpty) {
      throw ApiException('Nama member wajib diisi.');
    }
    if (password.length < 4) {
      throw ApiException('Password member minimal 4 karakter.');
    }
    final data = await _api.post(
      '${ApiConfig.accounts}/member',
      data: {'nama': nama.trim(), 'password': password, 'nominal': nominal},
    );
    return Account.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Tambah saldo atau tambah waktu.
  Future<void> topup({required String accountId, required int nominal}) async {
    _validasiNominal(nominal);
    await _api.post('${ApiConfig.accounts}/$accountId/topup',
        data: {'nominal': nominal});
  }

  /// Kurangi saldo. Backend menyebutnya koreksi, jadi itu transaksi
  /// pengurangan yang tercatat di riwayat, bukan sekadar mengubah angka.
  Future<void> correct(
      {required String accountId, required int nominal}) async {
    _validasiNominal(nominal);
    await _api.post('${ApiConfig.accounts}/$accountId/koreksi',
        data: {'nominal': nominal});
  }

  /// Nonaktifkan akun.
  Future<void> revoke(String accountId) async {
    await _api.post('${ApiConfig.accounts}/$accountId/revoke');
  }

  void _validasiNominal(int nominal) {
    if (nominal < minNominal) {
      throw ApiException('Nominal minimal Rp $minNominal.');
    }
    if (nominal % minNominal != 0) {
      throw ApiException('Nominal harus kelipatan Rp $minNominal.');
    }
  }

  /// Pencarian di sisi klien, dipakai untuk memfilter hasil [fetchAll].
  static List<Account> filterLocally(List<Account> list, String? search) {
    final q = search?.trim().toLowerCase() ?? '';
    if (q.isEmpty) return list;
    return list
        .where(
          (a) =>
              a.displayName.toLowerCase().contains(q) ||
              (a.nama?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }
}
