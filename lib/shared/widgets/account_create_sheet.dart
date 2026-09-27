import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../features/accounts/models/account.dart';

/// Isi form yang dikembalikan [showAccountCreateSheet].
///
/// Dipisah dari widget supaya pemanggil tidak perlu menyentuh controller,
/// dan supaya form yang sama bisa dipakai di dua tempat tanpa berubah
/// perilakunya.
class AccountDraft {
  const AccountDraft({
    required this.nama,
    required this.password,
    required this.nominal,
  });

  final String nama;
  final String password;
  final int nominal;
}

/// Form bersama untuk membuat voucher atau member.
///
/// Dipakai di dua tempat: halaman Voucher/Member, dan dialog "Mulai Sesi"
/// yang bisa membuat voucher atau member baru tanpa berpindah halaman.
/// Bentuk dan validasinya sengaja disatukan supaya kasir tidak menemukan
/// dua form yang berbeda.
Future<AccountDraft?> showAccountCreateSheet(
  BuildContext context, {
  required AccountType tipe,
}) {
  _resetControllers(tipe);
  return showModalBottomSheet<AccountDraft>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Buat ${tipe.label} Baru',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Nominal harus kelipatan 500.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          if (tipe == AccountType.member) ...[
            TextField(
              controller: _namaCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Nama member',
                prefixIcon: Icon(Icons.person_outline, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _sandiCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Password member',
                hintText: 'Minimal 4 angka',
                prefixIcon: Icon(Icons.lock_outline, size: 20),
              ),
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _nominalCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: tipe == AccountType.voucher ? 'Nominal voucher' : 'Saldo awal',
              prefixIcon: const Icon(Icons.payments_outlined, size: 20),
              suffixText: 'Rp',
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: () => _submit(ctx, tipe),
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
}

/// Controller disimpan di luar builder agar tidak ikut dibangun ulang setiap
/// kali keyboard muncul atau hilang. Kalau controller dibuat di dalam builder,
/// teks yang sudah diketik bisa ikut terhapus.
final _namaCtrl = TextEditingController();
final _sandiCtrl = TextEditingController();
final _nominalCtrl = TextEditingController(text: '10000');

/// Mengisi ulang controller sebelum form dibuka.
void _resetControllers(AccountType tipe) {
  _nominalCtrl.text = '10000';
  if (tipe == AccountType.member) {
    _namaCtrl.clear();
    _sandiCtrl.clear();
  }
}

String? _validate(AccountType tipe) {
  if (tipe == AccountType.member && _namaCtrl.text.trim().isEmpty) {
    return 'Nama member wajib diisi.';
  }
  if (tipe == AccountType.member && _sandiCtrl.text.trim().length < 4) {
    return 'Password member minimal 4 karakter.';
  }
  final nominal = int.tryParse(_nominalCtrl.text.trim());
  if (nominal == null) {
    return 'Nominal harus berupa angka.';
  }
  if (nominal < 500) {
    return 'Nominal minimal Rp 500.';
  }
  if (nominal % 500 != 0) {
    return 'Nominal harus kelipatan Rp 500.';
  }
  return null;
}

void _submit(BuildContext ctx, AccountType tipe) {
  final galat = _validate(tipe);
  if (galat != null) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(galat),
        backgroundColor: AppColors.danger,
      ),
    );
    return;
  }
  Navigator.pop(
    ctx,
    AccountDraft(
      nama: _namaCtrl.text.trim(),
      password: _sandiCtrl.text.trim(),
      nominal: int.parse(_nominalCtrl.text.trim()),
    ),
  );
}
