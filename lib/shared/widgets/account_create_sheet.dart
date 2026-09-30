import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../features/accounts/models/account.dart';
import '../utils/rupiah_input.dart';

/// Isi form yang dikembalikan [showAccountCreateSheet].
///
/// Dipisah dari widget supaya pemanggil tidak perlu menyentuh controller,
/// dan supaya form yang sama bisa dipakai di dua tempat tanpa berubah
/// perilakunya.
class AccountDraft {
  const AccountDraft({
    required this.nama,
    required this.nominal,
  });

  final String nama;
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
            'Password awal semua akun 0000, bisa diganti dari komputer.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          if (tipe == AccountType.member) ...[
            TextField(
              controller: _namaCtrl,
              // Batas dipasang di level input, bukan dipotong saat dikirim.
              // Nama member adalah kredensial sesi, jadi kalau dipotong diam-
              // diam pelanggan akan gagal login dengan nama yang berbeda dari
              // yang tertulis di kartunya.
              maxLength: maksKarakterNama,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Nama member',
                helperText: 'Nama ini dipakai pelanggan untuk mulai sesi',
                prefixIcon: Icon(Icons.person_outline, size: 20),
              ),
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _nominalCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: const [FormatRibuan()],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(ctx, tipe),
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: tipe == AccountType.voucher
                  ? 'Nominal voucher'
                  : 'Saldo awal',
              // Dulu kolom ini sudah terisi 10000. Kasir menekan Simpan tanpa
              // sadar dan ada voucher seharga Rp 10.000, padahal maksudnya
              // mungkin Rp 1.000. Sekarang kosong, dengan petunjuk yang jelas.
              hintText: 'Contoh: 10.000',
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
final _nominalCtrl = TextEditingController();

/// Mengisi ulang controller sebelum form dibuka.
///
/// ⚠️ Kolom nominal sengaja dikosongkan, bukan diisi 10000 seperti versi
/// lama. Terisi diam-diam berarti kasir bisa menekan Simpan tanpa membaca,
/// lalu membuat handout Rp 10.000 padahal maksudnya mungkin Rp 1.000.
/// mengubah nilai yang diketik kasir tanpa dia sadari.
/// mengubah nilai yang diketik kasir tanpa dia sadari.
void _resetControllers(AccountType tipe) {
  _nominalCtrl.clear();
  if (tipe == AccountType.member) {
    _namaCtrl.clear();
  }
}

String? _validate(AccountType tipe) {
  if (tipe == AccountType.member && _namaCtrl.text.trim().isEmpty) {
    return 'Nama member wajib diisi.';
  }
  if (_namaCtrl.text.trim().length > maksKarakterNama) {
    return 'Nama member maksimal $maksKarakterNama karakter.';
  }
  final nominal = parseNominal(_nominalCtrl.text);
  if (nominal == null) {
    return 'Nominal wajib diisi.';
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
      nominal: parseNominal(_nominalCtrl.text)!,
    ),
  );
}
