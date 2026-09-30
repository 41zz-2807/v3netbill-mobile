import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:v3netbill_mobile/core/network/socket_service.dart';
import 'package:v3netbill_mobile/core/theme/app_theme.dart';
import 'package:v3netbill_mobile/features/accounts/data/account_repository.dart';
import 'package:v3netbill_mobile/features/accounts/models/account.dart';
import 'package:v3netbill_mobile/features/accounts/providers/accounts_provider.dart';
import 'package:v3netbill_mobile/features/accounts/view/accounts_page.dart';
import 'package:v3netbill_mobile/features/pcs/data/pc_repository.dart';
import 'package:v3netbill_mobile/features/pcs/models/pc.dart';
import 'package:v3netbill_mobile/features/pcs/providers/pc_provider.dart';

class _RepoAkun implements AccountRepository {
  _RepoAkun(this.akun);

  final List<Account> akun;

  @override
  Future<List<Account>> fetchAll({AccountType? type, AccountStatus? status}) async =>
      type == null ? akun : akun.where((a) => a.tipe == type).toList();

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
  Future<void> correct({required String accountId, required int nominal}) async {}

  @override
  Future<void> changePassword({
    required String accountId,
    required String password,
  }) async {}

  @override
  Future<void> revoke(String accountId) async {}
}

class _RepoPc implements PcRepository {
  _RepoPc(this.socket, this.daftar);

  final _SocketPalsu socket;
  final List<Pc> daftar;

  @override
  Future<List<Pc>> fetchAll() async => daftar;

  @override
  Future<SocketResult> startSession({
    required String pcId,
    required String kode,
  }) async {
    socket.pasangan.add((pcId, kode));
    return const SocketResult(success: true);
  }

  @override
  Future<SocketResult> endSession(String pcId) async =>
      const SocketResult(success: true);

  @override
  Future<SocketResult> lock(String pcId) async =>
      const SocketResult(success: true);

  @override
  Future<SocketResult> shutdown(String pcId) async =>
      const SocketResult(success: true);
}

class _SocketPalsu implements SocketService {
  final List<(String, String)> pasangan = [];

  @override
  void Function(bool)? onConnectionChange;

  @override
  void Function(List<Map<String, dynamic>>)? onPcUpdate;

  @override
  bool get isConnected => true;

  @override
  Future<void> connect() async {}

  @override
  void disconnect() {}

  @override
  Future<SocketResult> emitWithAck(
    String event,
    Map<String, dynamic> data, {
    Duration? timeout,
  }) async =>
      const SocketResult(success: true);

  @override
  Future<SocketResult> startPc({required String pcId, required String kode}) async =>
      const SocketResult(success: true);

  @override
  Future<SocketResult> lockPc(String pcId) async =>
      const SocketResult(success: true);

  @override
  Future<SocketResult> shutdownPc(String pcId) async =>
      const SocketResult(success: true);
}

Pc _pc(String id, String nama, PcStatus status) =>
    Pc(id: id, namaPc: nama, status: status);

Account _voucher(String kode, {int sisa = 3600}) => Account(
      id: 'a-$kode',
      tipe: AccountType.voucher,
      kodeUnik: kode,
      sisaWaktuDetik: sisa,
      status: AccountStatus.active,
    );

Account _member(String nama, {int sisa = 3600}) => Account(
      id: 'a-$nama',
      tipe: AccountType.member,
      nama: nama,
      sisaWaktuDetik: sisa,
      status: AccountStatus.active,
    );

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  void diLebarHp(WidgetTester tester, double lebarPx) {
    tester.view.physicalSize = Size(lebarPx * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<(AccountsProvider, _SocketPalsu)> pump(
    WidgetTester tester, {
    required List<Account> akun,
    required List<Pc> pc,
    bool pilihVoucher = true,
    bool pilihSemua = false,
  }) async {
    final socket = _SocketPalsu();
    final ap = AccountsProvider(_RepoAkun(akun));
    await ap.load();
    if (pilihVoucher) {
      ap.setTab(AccountType.voucher);
    } else {
      ap.setTab(AccountType.member);
    }
    if (pilihSemua) {
      ap.selectAllVisible();
    } else {
      ap.toggleSelect(ap.visible.first.id);
    }

    final pp = PcProvider(_RepoPc(socket, pc), socket);
    // `load()` mengisi daftar PC. Tanpa itu sheet-nya terbuka tapi kosong,
    // karena PcProvider tidak pernah tahu ada PC sama sekali.
    await pp.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AccountsProvider>.value(value: ap),
          ChangeNotifierProvider<PcProvider>.value(value: pp),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: AccountsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (ap, socket);
  }

  testWidgets('klik Mulai di PC menampilkan pilihan PC', (tester) async {
    diLebarHp(tester, 390);
    final (_, _) = await pump(
      tester,
      akun: [_voucher('AAA111'), _voucher('BBB222')],
      pc: [_pc('p1', 'PC-01', PcStatus.idle)],
    );

    await tester.tap(find.byIcon(Icons.play_arrow).first);
    await tester.pumpAndSettle();

    expect(find.text('Mulai Sesi di PC'), findsOneWidget);
    expect(find.text('PC-01'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PC yang sedang dipakai dan offline tidak ditawarkan', (
    tester,
  ) async {
    diLebarHp(tester, 390);
    await pump(
      tester,
      akun: [_voucher('AAA111')],
      pc: [
        _pc('p1', 'PC-SIBUK', PcStatus.active),
        _pc('p2', 'PC-OFFLINE', PcStatus.offline),
        _pc('p3', 'PC-SIAP', PcStatus.idle),
      ],
    );

    await tester.tap(find.byIcon(Icons.play_arrow).first);
    await tester.pumpAndSettle();

    expect(find.text('PC-SIAP'), findsOneWidget);
    expect(find.text('PC-SIBUK'), findsNothing,
        reason: 'backend menolak PC yang sudah punya sesi');
    expect(find.text('PC-OFFLINE'), findsNothing);
  });

  testWidgets('tidak ada PC siap: sheet menjelaskan, tidak crash', (
    tester,
  ) async {
    diLebarHp(tester, 390);
    await pump(
      tester,
      akun: [_voucher('AAA111')],
      pc: [_pc('p1', 'PC-SIBUK', PcStatus.active)],
    );

    await tester.tap(find.byIcon(Icons.play_arrow).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Tidak ada PC yang siap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('memilih PC memulai sesi dengan kode akun', (tester) async {
    diLebarHp(tester, 390);
    final (_, socket) = await pump(
      tester,
      akun: [_voucher('XYZ789')],
      pc: [_pc('p1', 'PC-01', PcStatus.idle)],
    );

    await tester.tap(find.byIcon(Icons.play_arrow).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('PC-01'));
    await tester.pumpAndSettle();

    expect(socket.pasangan, [('p1', 'XYZ789')]);
  });

  testWidgets('member dikirim memakai NAMA, bukan kode', (tester) async {
    diLebarHp(tester, 390);
    final (_, socket) = await pump(
      tester,
      akun: [_member('Budi')],
      pc: [_pc('p1', 'PC-01', PcStatus.idle)],
      pilihVoucher: false,
    );

    await tester.tap(find.byIcon(Icons.play_arrow).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('PC-01'));
    await tester.pumpAndSettle();

    // Member tidak punya kodeUnik sama sekali, jadi kredensialnya NAMA.
    // Backend mencari kodeUnik dulu, lalu jatuh ke pencocokan nama.
    expect(socket.pasangan, [('p1', 'Budi')]);
  });

  testWidgets('memilih lebih dari satu akun ditolak sebelum memanggil server', (
    tester,
  ) async {
    diLebarHp(tester, 390);
    final (_, socket) = await pump(
      tester,
      akun: [_voucher('AAA111'), _voucher('BBB222')],
      pc: [_pc('p1', 'PC-01', PcStatus.idle)],
      pilihSemua: true,
    );

    await tester.tap(find.byIcon(Icons.play_arrow).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Pilih tepat satu akun'), findsOneWidget);
    expect(find.text('Mulai Sesi di PC'), findsNothing);
    expect(socket.pasangan, isEmpty,
        reason: 'server tidak boleh dipanggil untuk permintaan yang jelas salah');
  });

  // Dua tes terpisah, satu untuk tiap kondisi. Kalau digabung, SnackBar dari
  // penolakan pertama masih menempel dan membuat pengetikan kedua tidak
  // menemukan tombolnya — itu kegagalan tes, bukan perilaku aplikasi.
  testWidgets('saldo voucher habis ditolak sebelum memanggil server', (
    tester,
  ) async {
    diLebarHp(tester, 390);
    final (_, socket) = await pump(
      tester,
      akun: [
        const Account(
          id: 'a-x',
          tipe: AccountType.voucher,
          kodeUnik: 'HABIS1',
          sisaWaktuDetik: 0,
          status: AccountStatus.active,
        ),
      ],
      pc: [_pc('p1', 'PC-01', PcStatus.idle)],
    );

    await tester.tap(find.byIcon(Icons.play_arrow).first);
    await tester.pumpAndSettle();

    expect(find.text('Waktu voucher habis.'), findsOneWidget);
    expect(find.text('Mulai Sesi di PC'), findsNothing,
        reason: 'sheet jangan sampai terbuka untuk akun yang sudah tidak layak');
    expect(socket.pasangan, isEmpty);
  });

  testWidgets('akun dinonaktifkan ditolak sebelum memanggil server', (
    tester,
  ) async {
    diLebarHp(tester, 390);
    final (_, socket) = await pump(
      tester,
      akun: [
        const Account(
          id: 'a-y',
          tipe: AccountType.voucher,
          kodeUnik: 'NONAKTIF',
          sisaWaktuDetik: 3600,
          status: AccountStatus.revoked,
        ),
      ],
      pc: [_pc('p1', 'PC-01', PcStatus.idle)],
    );

    await tester.tap(find.byIcon(Icons.play_arrow).first);
    await tester.pumpAndSettle();

    expect(find.text('Akun ini sudah dinonaktifkan.'), findsOneWidget);
    expect(find.text('Mulai Sesi di PC'), findsNothing);
    expect(socket.pasangan, isEmpty);
  });

  testWidgets('membatalkan sheet tidak memulai sesi', (tester) async {
    diLebarHp(tester, 390);
    final (_, socket) = await pump(
      tester,
      akun: [_voucher('AAA111')],
      pc: [_pc('p1', 'PC-01', PcStatus.idle)],
    );

    await tester.tap(find.byIcon(Icons.play_arrow).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(socket.pasangan, isEmpty);
  });

  testWidgets('bar aksi 6 ikon tidak meluber di lebar HP 360 px', (tester) async {
    diLebarHp(tester, 360);
    await pump(
      tester,
      akun: [_voucher('AAA111')],
      pc: [_pc('p1', 'PC-01', PcStatus.idle)],
    );

    expect(find.byIcon(Icons.play_arrow), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
