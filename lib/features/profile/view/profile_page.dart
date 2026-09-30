import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/apk/update_provider.dart';
import '../../../core/apk/view/update_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../pcs/providers/pc_provider.dart';

/// Halaman profil: identitas user, ringkasan, dan tombol keluar.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final session = auth.session;
    final update = context.watch<UpdateProvider>();
    // Ringkas, bukan objek Provider: di rebuild berikutnya object yang sama
    // akan menggagalkan perbandingan dan memicu build tanpa guna.
    final statusTeks = switch (update.tahap) {
      TahapPembaruan.tersedia => 'Ada versi ${update.info?.versiTampil ?? '?'}',
      TahapPembaruan.siapPasang => 'Siap dipasang',
      _ => 'Terbaru',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Text(
          'Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),

        // Kartu identitas
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session?.username ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        session?.roleLabel ?? '-',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Pembaruan aplikasi. Versi di bawah ini dibaca dari metadata paket,
        // bukan ditulis manual, jadi selalu benar.
        const UpdateCard(),

        // Ringkasan jumlah PC sengaja tidak ada di sini. Angka yang sama sudah
        // tampil sebagai StatCard di dashboard, jadi di sini hanya info akun
        // dan info server.
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              const _Row(
                icon: Icons.dns_outlined,
                label: 'Server',
                value: 'v3netbill.bilmary.my.id',
              ),
              const Divider(height: 1),
              _Row(
                icon: Icons.info_outline,
                label: 'Versi aplikasi',
                value: context.select<UpdateProvider, String>(
                  (u) => u.versiTerpasang,
                ),
              ),
              const Divider(height: 1),
              _Row(
                icon: Icons.dns,
                label: 'Status',
                value: statusTeks,
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Keluar
        OutlinedButton.icon(
          onPressed: () => _confirmLogout(context),
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Keluar'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari aplikasi?'),
        content: const Text('Anda perlu login kembali untuk melanjutkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (yes != true || !context.mounted) return;
    final auth = context.read<AuthProvider>();
    // Daftar PC dan timer polling harus ikut dibersihkan, kalau tidak
    // request tetap berjalan setelah pengguna keluar.
    context.read<PcProvider>().clear();
    await auth.logout();
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
