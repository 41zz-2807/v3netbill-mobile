import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v3netbill_mobile/core/theme/app_colors.dart';
import 'package:v3netbill_mobile/core/theme/app_theme.dart';
import 'package:v3netbill_mobile/shared/widgets/common.dart';

/// Widget test untuk widget bersama di [common.dart].
///
/// Widget ini murni tampilan, tidak butuh Provider, jaringan, maupun
/// flutter_secure_storage, jadi bisa diuji tanpa mock.
void main() {
  testWidgets('StatusBadge menampilkan label dengan titik status',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusBadge(label: 'Aktif', color: AppColors.active),
        ),
      ),
    );
    expect(find.text('Aktif'), findsOneWidget);
  });

  testWidgets('StatCard menampilkan angka dan label',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatCard(
            label: 'Idle',
            value: 3,
            color: AppColors.idle,
          ),
        ),
      ),
    );
    expect(find.text('Idle'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('EmptyState menampilkan judul dan pesan',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: EmptyState(
            icon: Icons.computer_outlined,
            title: 'Belum ada PC',
            message: 'Tambahkan PC terlebih dahulu.',
          ),
        ),
      ),
    );
    expect(find.text('Belum ada PC'), findsOneWidget);
    expect(find.text('Tambahkan PC terlebih dahulu.'), findsOneWidget);
  });
}
