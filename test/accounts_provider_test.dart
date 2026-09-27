import 'package:flutter_test/flutter_test.dart';
import 'package:v3netbill_mobile/features/accounts/data/account_repository.dart';
import 'package:v3netbill_mobile/features/accounts/models/account.dart';
import 'package:v3netbill_mobile/features/accounts/providers/accounts_provider.dart';

/// Pengganti [AccountRepository] supaya provider bisa diuji tanpa jaringan.
///
/// Dipakai `implements`, bukan `extends`, supaya konstrutor aslinya yang
/// butuh [ApiClient] tidak pernah dijalankan.
class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository({this.failWith});

  /// Kalau diisi, pembuatan akun akan melempar error ini.
  final Object? failWith;

  List<Account> stored = const [];
  int? lastNominal;
  String? lastNama;
  int fetchAllCalls = 0;

  @override
  Future<List<Account>> fetchAll({AccountType? type, AccountStatus? status}) async {
    fetchAllCalls++;
    return stored;
  }

  @override
  Future<Account> createVoucher({required int nominal}) async {
    lastNominal = nominal;
    if (failWith != null) throw failWith!;
    const akun = Account(
      id: 'a1',
      tipe: AccountType.voucher,
      status: AccountStatus.active,
      kodeUnik: '123456',
      sisaWaktuDetik: 3600,
    );
    stored = [akun];
    return akun;
  }

  @override
  Future<Account> createMember({
    required String nama,
    required int nominal,
  }) async {
    lastNama = nama;
    lastNominal = nominal;
    if (failWith != null) throw failWith!;
    final akun = Account(
      id: 'a2',
      tipe: AccountType.member,
      status: AccountStatus.active,
      kodeUnik: '654321',
      nama: nama,
      sisaWaktuDetik: 3600,
    );
    stored = [akun];
    return akun;
  }

  @override
  Future<void> topup({required String accountId, required int nominal}) async {}

  @override
  Future<void> correct({required String accountId, required int nominal}) async {}

  @override
  Future<void> revoke(String accountId) async {}
}

void main() {
  group('AccountsProvider membuat akun dan mengembalikan kodenya', () {
    test('voucher mengembalikan kode unik supaya bisa langsung dipakai sesi', () async {
      final repo = _FakeAccountRepository();
      final p = AccountsProvider(repo);

      final akun = await p.createVoucherDapatKode(10000);

      expect(akun, isNotNull);
      expect(akun!.kodeUnik, '123456');
      expect(repo.lastNominal, 10000);
    });

    test('member mengembalikan kode unik dan meneruskan nama', () async {
      final repo = _FakeAccountRepository();
      final p = AccountsProvider(repo);

      final akun = await p.createMemberDapatKode(
        nama: 'Budi',
        nominal: 20000,
      );

      expect(akun, isNotNull);
      expect(akun!.kodeUnik, '654321');
      expect(repo.lastNama, 'Budi');
    });

    test('daftar akun ikut dimuat ulang setelah membuat', () async {
      final repo = _FakeAccountRepository();
      final p = AccountsProvider(repo);

      await p.createVoucherDapatKode(10000);

      expect(repo.fetchAllCalls, greaterThan(0));
      expect(p.all, hasLength(1));
    });

    test('gagal membuat mengembalikan null dan mengisi pesan galat', () async {
      final repo = _FakeAccountRepository(failWith: Exception('nominal kelipatan 500'));
      final p = AccountsProvider(repo);

      final akun = await p.createVoucherDapatKode(1000);

      expect(akun, isNull);
      expect(p.error, isNotNull);
    });
  });
}
