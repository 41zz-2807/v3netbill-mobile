import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../update_provider.dart';
import '../../theme/app_colors.dart';

/// Kartu pembaruan aplikasi, dipakai di Home dan di Profile.
///
/// Mengembalikan `SizedBox.shrink()` kalau tidak ada yang perlu ditampilkan,
/// jadi pemanggil tidak perlu dibungkus dengan if.
class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key, this.ringkas = false});

  /// Versi ringkas untuk Home, versi lengkap dengan tombol untuk Profile.
  final bool ringkas;

  @override
  Widget build(BuildContext context) {
    final update = context.watch<UpdateProvider>();
    final tampil =
        !update.adaPembaruan && update.tahap == TahapPembaruan.siapPasang
            ? true
            : update.adaPembaruan || update.sibuk || update.galat != null;
    if (!tampil) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: _Card(update: update, ringkas: ringkas),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.update, required this.ringkas});

  final UpdateProvider update;
  final bool ringkas;

  @override
  Widget build(BuildContext context) {
    final info = update.info;
    final mengunduh = update.tahap == TahapPembaruan.mengunduh;
    final memasang = update.tahap == TahapPembaruan.memasang;
    final siap = update.tahap == TahapPembaruan.siapPasang;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: update.adaPembaruan
              ? AppColors.primary.withValues(alpha: 0.6)
              : AppColors.divider,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                update.adaPembaruan
                    ? Icons.system_update_alt
                    : Icons.info_outline,
                size: 18,
                color: update.adaPembaruan
                    ? AppColors.primaryLight
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  update.adaPembaruan
                      ? 'Pembaruan tersedia'
                      : (siap ? 'Siap dipasang' : 'Pembaruan aplikasi'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (update.adaPembaruan)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'BARU',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (info != null && update.adaPembaruan)
            Text(
              'Versi ${info.versiTampil} tersedia. Anda memakai '
              '${update.versiTerpasang}.'
              '${info.ukuranBytes != null ? ' Ukuran ${_ukuran(info.ukuranBytes!)}.' : ''}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          if (update.alasanTidakBisaDicek != null) ...[
            const SizedBox(height: 6),
            Text(
              update.alasanTidakBisaDicek!,
              style: const TextStyle(
                color: AppColors.idle,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          if (mengunduh) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: update.persen == 0 ? null : update.persen,
                minHeight: 6,
                backgroundColor: AppColors.bgCardAlt,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              update.persen == 0
                  ? 'Mengunduh...'
                  : 'Mengunduh ${(update.persen * 100).round()}% dari '
                      '${_ukuran((update.info?.ukuranBytes) ?? 0)}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
          if (memasang)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Menunggu layar pemasangan Android...',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          if (ringkas && !mengunduh && !memasang) const SizedBox(height: 4),
          if (!ringkas || update.adaPembaruan) ...[
            const SizedBox(height: 14),
            _Tombol(
              update: update,
              mengunduh: mengunduh,
              memasang: memasang,
              siap: siap,
            ),
          ],
        ],
      ),
    );
  }
}

class _Tombol extends StatelessWidget {
  const _Tombol({
    required this.update,
    required this.mengunduh,
    required this.memasang,
    required this.siap,
  });

  final UpdateProvider update;
  final bool mengunduh;
  final bool memasang;
  final bool siap;

  @override
  Widget build(BuildContext context) {
    if (mengunduh || memasang) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _mulai(context),
            icon: Icon(
              siap ? Icons.install_mobile : Icons.download,
              size: 18,
            ),
            label: Text(siap ? 'Pasang' : 'Perbarui sekarang'),
            style: FilledButton.styleFrom(
              backgroundColor: siap ? AppColors.active : AppColors.primary,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton(
          onPressed: () => context.read<UpdateProvider>().cek(paksa: true),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(46, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Icon(Icons.refresh, size: 18),
        ),
      ],
    );
  }

  Future<void> _mulai(BuildContext context) async {
    final update = context.read<UpdateProvider>();
    if (update.tahap == TahapPembaruan.siapPasang) {
      await update.pasangSaja();
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pasang pembaruan?'),
        content: Text(
          'Aplikasi akan diunduh (${_ukuran(update.info?.ukuranBytes ?? 0)}) '
          'lalu dipasang di HP ini. Aplikasi ditutup sebentar saat pemasangan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    await update.unduhDanPasang();
  }
}

String _ukuran(int byte) {
  if (byte <= 0) return '?';
  final mb = byte / (1024 * 1024);
  return mb >= 1
      ? '${mb.toStringAsFixed(1)} MB'
      : '${(byte / 1024).round()} KB';
}
