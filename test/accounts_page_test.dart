import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:v3netbill_mobile/features/accounts/data/account_repository.dart';
import 'package:v3netbill_mobile/features/accounts/models/account.dart';
import 'package:v3netbill_mobile/features/accounts/providers/accounts_provider.dart';
import 'package:v3netbill_mobile/features/accounts/view/accounts_page.dart';
import 'package:v3netbill_mobile/shared/widgets/common.dart';

/// Repository yang mengembalikan data nyata dari backend, dibungkus fixture
/// supaya tes tidak bergantung jaringan.
class _FixtureRepo implements AccountRepository {
  _FixtureRepo(this.akun);

  final List<Account> akun;

  @override
  Future<List<Account>> fetchAll(
      {AccountType? type, AccountStatus? status}) async {
    if (type == null) return akun;
    return akun.where((a) => a.tipe == type).toList();
  }

  @override
  Future<Account> createVoucher({required int nominal}) async => akun.first;

  @override
  Future<Account> createMember({
    required String nama,
    required int nominal,
  }) async =>
      akun.first;

  @override
  Future<void> topup({required String accountId, required int nominal}) async {}

  @override
  Future<void> correct(
      {required String accountId, required int nominal}) async {}

  @override
  Future<void> changePassword({
    required String accountId,
    required String password,
  }) async {}

  @override
  Future<void> revoke(String accountId) async {}
}

List<Account> _muatFixture() {
  final teks = File('test/fixture_accounts.json').readAsStringSync();
  return (json.decode(teks) as List)
      .map((e) => Account.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

Widget _app(AccountsProvider p) =>
    ChangeNotifierProvider<AccountsProvider>.value(
      value: p,
      child: const MaterialApp(home: Scaffold(body: AccountsPage())),
    );

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  testWidgets('daftar voucher tampil dan tidak layar kosong',
      (WidgetTester tester) async {
    final semua = _muatFixture();
    final p = AccountsProvider(_FixtureRepo(semua));
    await p.load();

    await tester.pumpWidget(_app(p));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsNothing,
        reason: 'layar kosong padahal ada ${semua.length} akun');

    // Kode voucher dari data nyata harus muncul di layar.
    final kodeVoucher =
        semua.firstWhere((a) => a.tipe == AccountType.voucher).kodeUnik!;
    expect(find.textContaining(kodeVoucher), findsWidgets,
        reason: 'kode voucher dari server tidak tampil');
  });

  testWidgets('memilih akun memunculkan tombol aksi',
      (WidgetTester tester) async {
    final semua = _muatFixture();
    final p = AccountsProvider(_FixtureRepo(semua));
    await p.load();

    await tester.pumpWidget(_app(p));
    await tester.pumpAndSettle();

    // Ketuk centang pada kartu pertama supaya provider menandai akun terpilih.
    // Menyukai lewat teks tidak selalu merambat ke GestureDetector kartu.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(p.selectedCount, 1,
        reason: 'ketukan tidak menandai akun sebagai terpilih');

    // Tombol aksi sekarang ikon saja tanpa keterangan, jadi dicari lewat ikon.
    // Label teksnya pindah ke tooltip, yang tidak dirender sampai dipanggil.
    for (final ikon in [
      Icons.play_arrow,
      Icons.add,
      Icons.remove,
      Icons.block,
      Icons.lock_outline,
      Icons.close,
    ]) {
      expect(find.byIcon(ikon), findsWidgets,
          reason: 'ikon $ikon tidak muncul setelah memilih');
    }
    expect(find.textContaining('dipilih'), findsNothing,
        reason: 'tulisan jumlah terpilih harus dihapus');
  });

  testWidgets('bar aksi tidak meluber di layar HP 390 px',
      (WidgetTester tester) async {
    // Lebar HP yang paling umum. Bar versi lama meluber 261 px di lebar ini.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final semua = _muatFixture();
    final p = AccountsProvider(_FixtureRepo(semua));
    await p.load();

    await tester.pumpWidget(_app(p));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'bar aksi meluber di layar HP');
  });
}
