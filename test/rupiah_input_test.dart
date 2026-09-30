import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v3netbill_mobile/core/theme/app_colors.dart';
import 'package:v3netbill_mobile/features/accounts/models/account.dart';
import 'package:v3netbill_mobile/shared/utils/rupiah_input.dart';
import 'package:v3netbill_mobile/shared/widgets/account_create_sheet.dart';

void main() {
  group('FormatRibuan', () {
    const f = FormatRibuan();

    String ketik(String sebelum, String sesudah) {
      return f
          .formatEditUpdate(
            TextEditingValue(
              text: sebelum,
              selection: TextSelection.collapsed(offset: sebelum.length),
            ),
            TextEditingValue(
              text: sesudah,
              selection: TextSelection.collapsed(offset: sesudah.length),
            ),
          )
          .text;
    }

    test('memisahkan ribuan saat diketik', () {
      expect(ketik('', '1'), '1');
      expect(ketik('1', '10'), '10');
      expect(ketik('10', '100'), '100');
      expect(ketik('100', '1000'), '1.000');
      expect(ketik('1.000', '10000'), '10.000');
      expect(ketik('10.000', '100000'), '100.000');
      expect(ketik('100.000', '1000000'), '1.000.000');
    });

    test('huruf dan tanda baca ditolak', () {
      expect(ketik('', 'abc'), '');
      expect(ketik('', '1a0'), '10');
      expect(ketik('1.000', '1.000-'), '1.000');
    });

    test('digit lebih dari batas ditolak, bukan dipotong', () {
      // 8 digit adalah batas. Digit ke-9 harus ditolak utuh, bukan
      // dipotong jadi 8 digit terakhir: memotong akan mengubah nominal.
      expect(ketik('9.999.999', '99999999'), '99.999.999');
      expect(ketik('99.999.999', '999999999'), '99.999.999');
    });

    test('menghapus semua digit mengosongkan kolom', () {
      expect(ketik('10.000', ''), '');
    });

    test('kursor digeser ke akhir hasil format', () {
      final hasil = f.formatEditUpdate(
        const TextEditingValue(text: '1000'),
        const TextEditingValue(text: '10000'),
      );
      expect(hasil.selection.baseOffset, hasil.text.length);
    });

    test('perubahan seleksi saja diteruskan tanpa diubah', () {
      const awal = TextEditingValue(
        text: '10.000',
        selection: TextSelection.collapsed(offset: 1),
      );
      const baru = TextEditingValue(
        text: '10.000',
        selection: TextSelection.collapsed(offset: 4),
      );
      expect(
        f.formatEditUpdate(awal, baru),
        baru,
        reason: 'hanyaursor yang pindah, teks tidak boleh ditulis ulang',
      );
    });
  });

  group('parseNominal', () {
    test('membaca teks berformat ribuan', () {
      expect(parseNominal('10.000'), 10000);
      expect(parseNominal('1.000.000'), 1000000);
      expect(parseNominal('99.999.999'), 99999999);
      expect(parseNominal('500'), 500);
    });

    test('kosong dan bukan angka menghasilkan null', () {
      expect(parseNominal(''), isNull);
      expect(parseNominal('   '), isNull);
      expect(parseNominal('abc'), isNull);
    });
  });

  group('form buat akun', () {
    /// WAJIB diuji pada lebar HP. Permintaan aslinya: pada 390 px teks
    /// "Voucher" dan "Member" turun baris. `flutter test` memakai permukaan
    /// 800x600 yang terlalu lebar dan tidak akan menangkapnya.
    Future<void> diLebarHp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    testWidgets('kolom nominal kosong, tidak terisi 10000 lagi', (
      tester,
    ) async {
      await diLebarHp(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: AppColors.bgBase,
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => showAccountCreateSheet(
                  ctx,
                  tipe: AccountType.voucher,
                ),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Nominal voucher'),
      );
      expect(
        field.controller!.text,
        isEmpty,
        reason: 'kolom nominal harus kosong, bukan 10000',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('nama member dibatasi 40 karakter di level input', (
      tester,
    ) async {
      await diLebarHp(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: AppColors.bgBase,
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => showAccountCreateSheet(
                  ctx,
                  tipe: AccountType.member,
                ),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Nama member'),
      );
      expect(field.maxLength, maksKarakterNama);

      // Ketik jauh lebih dari batas: yang tersimpan harus terpotong oleh
      // maxLength, bukan diterima utuh.
      await tester.enterText(
        find.widgetWithText(TextField, 'Nama member'),
        'a' * 60,
      );
      await tester.pump();
      expect(field.controller!.text.length, maksKarakterNama);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nominal diformat ribuan saat diketik di sheet', (
      tester,
    ) async {
      await diLebarHp(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: AppColors.bgBase,
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => showAccountCreateSheet(
                  ctx,
                  tipe: AccountType.voucher,
                ),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Nominal voucher'),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Nominal voucher'),
        '10000',
      );
      await tester.pump();
      expect(field.controller!.text, '10.000');
      expect(parseNominal(field.controller!.text), 10000);
    });
  });
}
