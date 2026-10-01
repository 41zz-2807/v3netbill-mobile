import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:v3netbill_mobile/core/network/socket_service.dart';
import 'package:v3netbill_mobile/core/theme/app_theme.dart';
import 'package:v3netbill_mobile/features/pcs/data/pc_repository.dart';
import 'package:v3netbill_mobile/features/pcs/models/pc.dart';
import 'package:v3netbill_mobile/features/pcs/providers/pc_provider.dart';
import 'package:v3netbill_mobile/features/pcs/view/widgets/pc_card.dart';

class _Repo implements PcRepository {
  @override
  Future<List<Pc>> fetchAll() async => const [];

  @override
  Future<SocketResult> startSession({
    required String pcId,
    required String kode,
  }) async =>
      const SocketResult(success: true);

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

class _Socket implements SocketService {
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
  Future<SocketResult> startPc({
    required String pcId,
    required String kode,
  }) async =>
      const SocketResult(success: true);

  @override
  Future<SocketResult> lockPc(String pcId) async =>
      const SocketResult(success: true);

  @override
  Future<SocketResult> shutdownPc(String pcId) async =>
      const SocketResult(success: true);
}

Pc _pc({
  required PcStatus status,
  bool denganSesi = false,
}) =>
    Pc(
      id: 'p1',
      namaPc: 'PC-01',
      status: status,
      session: denganSesi
          ? const PcSession(kodeUnik: 'ABC123', tipe: 'VOUCHER', sisaDetik: 600)
          : null,
    );

/// Kartu PC harus punya tepat DUA tombol: tombol pertama bergantian antara
/// "Mulai Sesi" dan "Akhiri Sesi", tombol kedua "Matikan" selalu ada.
///
/// Versi lama menampilkan "Mulai Sesi" dan "Akhiri Sesi" BERSAMAAN. Itu
/// menyesatkan karena keduanya aksi yang bertentangan: kasir bisa menekan
/// "Mulai Sesi" di PC yang sedang berjalan lalu ditolak backend dengan
/// "PC sudah memiliki sesi berjalan".
void main() {
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  Future<void> pumpCard(WidgetTester tester, Pc pc) async {
    final socket = _Socket();
    await tester.pumpWidget(
      ChangeNotifierProvider<PcProvider>(
        create: (_) => PcProvider(_Repo(), socket),
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: SingleChildScrollView(child: PcCard(pc: pc))),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void diLebarHp(WidgetTester tester, double lebarPx) {
    tester.view.physicalSize = Size(lebarPx * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('PC idle: hanya "Mulai Sesi" dan "Matikan"', (tester) async {
    await pumpCard(tester, _pc(status: PcStatus.idle));

    expect(find.text('Mulai Sesi'), findsOneWidget);
    expect(find.text('Matikan'), findsOneWidget);
    expect(find.text('Akhiri Sesi'), findsNothing);
  });

  testWidgets('PC dengan sesi: hanya "Akhiri Sesi" dan "Matikan"', (
    tester,
  ) async {
    await pumpCard(
      tester,
      _pc(status: PcStatus.active, denganSesi: true),
    );

    expect(find.text('Akhiri Sesi'), findsOneWidget);
    expect(find.text('Matikan'), findsOneWidget);
    expect(find.text('Mulai Sesi'), findsNothing);
  });

  testWidgets('status ACTIVE tanpa info sesi tetap menampilkan "Akhiri Sesi"', (
    tester,
  ) async {
    // `session` bisa null walau status masih ACTIVE sesaat setelah sisi server
    // berubah. Kalau hanya `hasSession` yang diperiksa, kasir melihat
    // "Mulai Sesi" di PC yang sedang berjalan lalu ditolak backend.
    await pumpCard(tester, _pc(status: PcStatus.active));

    expect(find.text('Akhiri Sesi'), findsOneWidget);
    expect(find.text('Mulai Sesi'), findsNothing);
  });

  testWidgets('PC offline: tidak ada tombol yang bisa ditekan', (tester) async {
    await pumpCard(tester, _pc(status: PcStatus.offline));

    final tombol = tester.widgetList<PcActionButton>(find.byType(PcActionButton));
    expect(tombol, hasLength(2), reason: 'harus tetap tepat dua tombol');
    for (final t in tombol) {
      expect(t.enabled, isFalse);
    }
  });

  testWidgets('dua tombol tidak meluber di lebar HP 360 px', (tester) async {
    diLebarHp(tester, 360);
    await pumpCard(tester, _pc(status: PcStatus.idle));

    expect(tester.takeException(), isNull);
  });

  testWidgets('dua tombol tidak meluber di lebar HP 320 px', (tester) async {
    diLebarHp(tester, 320);
    await pumpCard(tester, _pc(status: PcStatus.active, denganSesi: true));

    expect(tester.takeException(), isNull);
  });
}
