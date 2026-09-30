import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:v3netbill_mobile/core/apk/apk_installer.dart';
import 'package:v3netbill_mobile/core/apk/apk_repository.dart';
import 'package:v3netbill_mobile/core/apk/info_apk.dart';
import 'package:v3netbill_mobile/core/apk/update_provider.dart';
import 'package:v3netbill_mobile/core/apk/view/update_card.dart';
import 'package:v3netbill_mobile/core/theme/app_colors.dart';

class _FakeApkRepository implements ApkRepository {
  _FakeApkRepository(this.info);

  final InfoApk info;

  @override
  Future<InfoApk> cekInfo() async => info;

  @override
  Future<void> bersihkan() async {}

  @override
  Future<Never> unduh(
    InfoApk info, {
    void Function(int diterima, int total)? onProgress,
  }) async {
    throw UnimplementedError('tidak dipakai di test tampilan');
  }
}

class _FakeInstaller implements ApkInstaller {
  @override
  Future<HasilPasang> pasang(String pathApk) async =>
      const HasilPasang(StatusPasang.gagal, 'tidak dipakai');
}

void main() {
  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'v3Netbill',
      packageName: 'com.v3netbill.v3netbill_mobile',
      version: '1.0.12',
      buildNumber: '12',
      buildSignature: '',
    );
  });

  InfoApk infoBaru() => InfoApk.fromJson(const {
    'ada': true,
    'versionCode': 14,
    'versionName': '1.0.14',
    'ukuranBytes': 53956267,
    'sha256': 'abc',
    'tanggalUpload': '2026-09-30T02:00:00.000Z',
  });

  Widget bungkus(UpdateProvider provider) {
    return ChangeNotifierProvider<UpdateProvider>.value(
      value: provider,
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          backgroundColor: AppColors.bgBase,
          body: SingleChildScrollView(child: UpdateCard()),
        ),
      ),
    );
  }

  /// WAJIB diuji pada lebar HP. `flutter test` memakai permukaan 800x600,
  /// cukup lebar untuk Row apa pun, jadi bug meluber hanya terlihat di sini.
  Future<void> diLebarHp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('kartu pembaruan tidak meluber di lebar HP 390px', (tester) async {
    await diLebarHp(tester);
    final provider = UpdateProvider(
      _FakeApkRepository(infoBaru()),
      installer: _FakeInstaller(),
    );
    await provider.cek();

    await tester.pumpWidget(bungkus(provider));
    await tester.pump();

    expect(find.text('Pembaruan tersedia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kartu versi ringkas tidak meluber di lebar HP', (tester) async {
    await diLebarHp(tester);
    final provider = UpdateProvider(
      _FakeApkRepository(infoBaru()),
      installer: _FakeInstaller(),
    );
    await provider.cek();

    await tester.pumpWidget(
      ChangeNotifierProvider<UpdateProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            backgroundColor: AppColors.bgBase,
            body: SingleChildScrollView(
              child: UpdateCard(ringkas: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('saat tidak ada pembaruan, kartu tidak muncul sama sekali', (
    tester,
  ) async {
    await diLebarHp(tester);
    final provider = UpdateProvider(
      _FakeApkRepository(
        InfoApk.fromJson(const {
          'ada': true,
          'versionCode': 12,
          'versionName': '1.0.12',
        }),
      ),
      installer: _FakeInstaller(),
    );
    await provider.cek();

    await tester.pumpWidget(bungkus(provider));
    await tester.pump();

    expect(find.text('Pembaruan tersedia'), findsNothing);
  });
}
