import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:v3netbill_mobile/core/apk/apk_installer.dart';
import 'package:v3netbill_mobile/core/apk/apk_repository.dart';
import 'package:v3netbill_mobile/core/apk/info_apk.dart';
import 'package:v3netbill_mobile/core/apk/update_provider.dart';
import 'package:v3netbill_mobile/core/network/socket_service.dart';
import 'package:v3netbill_mobile/core/notifikasi/notifikasi_provider.dart';
import 'package:v3netbill_mobile/core/notifikasi/notifikasi_repository.dart';
import 'package:v3netbill_mobile/core/storage/secure_store.dart';
import 'package:v3netbill_mobile/core/theme/app_colors.dart';
import 'package:v3netbill_mobile/core/theme/app_theme.dart';
import 'package:v3netbill_mobile/features/auth/data/auth_repository.dart';
import 'package:v3netbill_mobile/features/auth/models/user_session.dart';
import 'package:v3netbill_mobile/features/auth/providers/auth_provider.dart';
import 'package:v3netbill_mobile/features/pcs/data/pc_repository.dart';
import 'package:v3netbill_mobile/features/pcs/models/pc.dart';
import 'package:v3netbill_mobile/features/pcs/providers/pc_provider.dart';
import 'package:v3netbill_mobile/features/profile/view/profile_page.dart';

class _FakeAuthRepository implements AuthRepository {
  static const sesi = UserSession(
    token: 'token-uji',
    role: 'ADMIN',
    username: 'admin',
  );

  @override
  Future<UserSession> login({
    required String username,
    required String password,
  }) async =>
      sesi;

  @override
  Future<UserSession?> restore() async => sesi;

  @override
  Future<void> logout() async {}
}

class _FakeSocketService implements SocketService {
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

class _FakePcRepository implements PcRepository {
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

class _FakeApkRepository implements ApkRepository {
  _FakeApkRepository({this.versionCode = 17, this.versionName = '1.0.17'});

  /// Nomor versi di server. Kalau lebih besar dari yang terpasang, provider
  /// menganggap ada pembaruan tersedia.
  final int versionCode;
  final String versionName;

  @override
  Future<InfoApk> cekInfo() async => InfoApk.fromJson({
        'ada': true,
        'versionCode': versionCode,
        'versionName': versionName,
      });

  @override
  Future<void> bersihkan() async {}

  @override
  Future<Never> unduh(
    InfoApk info, {
    void Function(int diterima, int total)? onProgress,
  }) async =>
      throw UnimplementedError('tidak dipakai di test tampilan');
}

class _FakeApkInstaller implements ApkInstaller {
  @override
  Future<HasilPasang> pasang(String pathApk) async =>
      const HasilPasang(StatusPasang.gagal, 'tidak dipakai');
}

class _FakeNotifikasiRepository implements NotifikasiRepository {
  final List<String> terdaftar = [];
  final List<String> dihapus = [];

  @override
  Future<bool> daftar(String token) async {
    terdaftar.add(token);
    return true;
  }

  @override
  Future<void> hapus(String token) async => dihapus.add(token);
}

/// Widget test untuk kartu informasi di halaman Profile.
///
/// Yang diuji adalah perataan, bukan isi teks. Bug yang pernah ada:
/// nilai info memakai `Spacer()` + `Flexible()`, dan keduanya sama-sama
/// flex 1, jadi ruang sisa dibagi dua sama besar. Nilai yang lebih pendek
/// dari bagiannya lalu berhenti di tengah dan tidak menempel tepi kanan,
/// sehingga ketiganya terlihat tidak sejajar.
void main() {
  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'v3Netbill',
      packageName: 'com.v3netbill.v3netbill_mobile',
      version: '1.0.17',
      buildNumber: '17',
      buildSignature: '',
    );
  });

  /// WAJIB diuji pada lebar HP. `flutter test` memakai permukaan 800x600,
  /// cukup lebar untuk Row apa pun, jadi bug perataan seperti ini tidak
  /// akan terlihat di lebar default.
  void diLebarHp(WidgetTester tester, double lebarPx) {
    tester.view.physicalSize = Size(lebarPx * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> pumpProfile(
    WidgetTester tester, {
    int versionCode = 17,
    String? versionName,
  }) async {
    final socket = _FakeSocketService();
    final auth = AuthProvider(_FakeAuthRepository());
    await auth.bootstrap();
    final update = UpdateProvider(
      _FakeApkRepository(
        versionCode: versionCode,
        versionName: versionName ?? '1.0.$versionCode',
      ),
      installer: _FakeApkInstaller(),
    );
    await update.cek();

    // `push: null` supaya tidak ada yang menyentuh Firebase. Dengan begitu
    // provider tidak pernah memanggil repository, jadi tidak ada jaringan.
    final notifikasi = NotifikasiProvider(
      repository: _FakeNotifikasiRepository(),
      store: SecureStore(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<UpdateProvider>.value(value: update),
          ChangeNotifierProvider<NotifikasiProvider>.value(value: notifikasi),
          ChangeNotifierProvider<PcProvider>(
            create: (_) => PcProvider(_FakePcRepository(), socket),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            backgroundColor: AppColors.bgBase,
            body: ProfilePage(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final lebar in [390.0, 360.0]) {
    testWidgets(
      'nilai info rata kanan semua di lebar ${lebar.toInt()}px',
      (tester) async {
        diLebarHp(tester, lebar);
        await pumpProfile(tester);

        expect(find.text('Server'), findsOneWidget);
        expect(find.text('Versi aplikasi'), findsOneWidget);
        expect(find.text('Status'), findsOneWidget);
        expect(find.text('v3netbill.bilmary.my.id'), findsOneWidget);

        final kanan = [
          for (final nilai in [
            'v3netbill.bilmary.my.id',
            '1.0.17',
            'Terbaru',
          ])
            tester.getRect(find.text(nilai)).right,
        ];

        for (final x in kanan) {
          expect(x, closeTo(kanan.first, 0.5));
        }

        // Label harus mulai dari kolom yang sama, tidak ikut bergeser
        // mengikuti panjang nilai.
        final kiriLabel = [
          for (final label in ['Server', 'Versi aplikasi', 'Status'])
            tester.getRect(find.text(label)).left,
        ];
        for (final x in kiriLabel) {
          expect(x, closeTo(kiriLabel.first, 0.5));
        }

        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('kartu info tidak meluber di lebar HP 320px', (tester) async {
    diLebarHp(tester, 320);
    await pumpProfile(tester);
    expect(find.text('v3netbill.bilmary.my.id'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Notifikasi pembaruan hanya di Home. Di Profile sengaja tidak ada
  // UpdateCard, supaya tidak muncul dua kali berdekatan.
  //
  // Diuji dengan server melaporkan versi LEBIH BARU dari yang terpasang.
  // Kalau versinya sama, kartu itu memang tidak akan muncul juga, jadi
  // tes dengan versi sama tidak membuktikan apa pun.
  testWidgets('halaman Profile tidak menampilkan kartu pembaruan', (
    tester,
  ) async {
    diLebarHp(tester, 390);
    await pumpProfile(tester, versionCode: 18);

    expect(find.text('Pembaruan tersedia'), findsNothing);
    expect(find.text('BARU'), findsNothing);
    expect(find.text('Perbarui sekarang'), findsNothing);

    // Baris Status tetap memberi tahu, jadi kasir tidak kehilangan informasi.
    expect(find.text('Ada versi 1.0.18'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
