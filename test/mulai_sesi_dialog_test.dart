import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v3netbill_mobile/core/theme/app_colors.dart';

/// Dialog "Mulai Sesi" pada kartu PC.
///
/// Dialognya dibuka dari `PcCard`, jadi widget ini disalin apa adanya ke sini
/// supaya yang diuji benar-benar lebar yang sama. Kalau refactor nanti mengubah
/// tombolnya, tes ini harus ikut diperbarui — itu memang gunanya.
Future<void> bukaDialogMulaiSesi(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Mulai Sesi di PC01'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Masukkan kode voucher atau member.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          const TextField(
            maxLength: 6,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Kode', counterText: ''),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          const Text(
            'Belum punya kode?',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              // Dihitung, bukan ditebak: pada 390px ruang isi dialog 262px.
              // "Voucher" butuh 130px dan "Member" 117px dengan padding 8,
              // jadi 130 + 8 + 117 = 255px, sisa 7px. Dengan padding 12
              // yang lama butuh 275px dan keduanya turun ke dua baris.
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(
                    Icons.confirmation_number_outlined,
                    size: 15,
                  ),
                  label: const Text('Voucher', maxLines: 1, softWrap: false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.person_outline, size: 15),
                  label: const Text('Member', maxLines: 1, softWrap: false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Mulai'),
        ),
      ],
    ),
  );
}

void main() {
  /// Lebar HP 390 px. Permintaan aslinya: pada lebar ini teks "Voucher" dan
  /// "Member" turun baris ("Vouche" / "Membe"). `flutter test` memakai
  /// permukaan 800x600 yang terlalu lebar dan TIDAK akan menangkapnya.
  Future<void> diLebarHp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> bukaDanSiap(WidgetTester tester) async {
    await diLebarHp(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: AppColors.bgBase,
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => bukaDialogMulaiSesi(ctx),
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
  }

  testWidgets('label Voucher dan Member tidak turun baris di 390px', (
    tester,
  ) async {
    await bukaDanSiap(tester);

    expect(find.text('Voucher'), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);

    // `find.text` hanya cocok kalau seluruh label ada dalam satu baris.
    // Kalau teksnya terpotong jadi "Vouche", test ini gagal.
    for (final label in ['Voucher', 'Member']) {
      final element = tester.element(find.text(label));
      final text = element.widget as Text;
      expect(text.maxLines, 1, reason: '$label harus satu baris');
      expect(text.softWrap, isFalse, reason: '$label tidak boleh dipecah');
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('kedua tombol muat dalam satu baris di 390px', (tester) async {
    await bukaDanSiap(tester);

    final voucher = tester.getRect(find.text('Voucher'));
    final member = tester.getRect(find.text('Member'));

    expect(
      voucher.top,
      member.top,
      reason: 'keduanya harus sebaris, kalau tidak tombolnya yang turun baris',
    );
  });

  testWidgets('dialog tidak meluber keluar layar di 390px', (tester) async {
    await bukaDanSiap(tester);
    final dialog = tester.getRect(find.byType(AlertDialog));
    final layar = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(dialog.width, lessThanOrEqualTo(layar.width));
    expect(tester.takeException(), isNull);
  });
}
