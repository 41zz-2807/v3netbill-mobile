import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../pcs/models/pc.dart';

/// Minta operator memilih PC tujuan, lalu mengembalikan PC itu.
///
/// [pc] yang sudah dipakai sesi tidak ikut ditawarkan. Backend akan menolaknya
/// dengan "PC sudah memiliki sesi berjalan", dan PC offline tidak punya layar
/// untuk dikunci. Menawarkan keduanya berarti kasir memilih lalu gagal — itu
/// lebih buruk daripada tidak menawarkannya sama sekali.
Future<Pc?> showPilihPcSheet(
  BuildContext context, {
  required List<Pc> daftarPc,
  required String namaAkun,
}) {
  return showModalBottomSheet<Pc>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _PilihPcSheet(pc: daftarPc, namaAkun: namaAkun),
  );
}

class _PilihPcSheet extends StatelessWidget {
  const _PilihPcSheet({required this.pc, required this.namaAkun});

  final List<Pc> pc;
  final String namaAkun;

  @override
  Widget build(BuildContext context) {
    final siap = pc.where((p) => p.status == PcStatus.idle).toList()
      ..sort((a, b) => a.namaPc.compareTo(b.namaPc));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Mulai Sesi di PC',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Akun $namaAkun',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            if (siap.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Tidak ada PC yang siap. PC yang sedang dipakai atau offline '
                  'tidak bisa memulai sesi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              )
            else
              ConstrainedBox(
                // Batas tinggi supaya daftar PC yang banyak tidak memenuhi
                // seluruh layar dan tidak bisa ditutup.
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: siap.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => ListTile(
                    onTap: () => Navigator.pop(context, siap[i]),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.computer_outlined,
                      color: AppColors.primaryLight,
                      size: 20,
                    ),
                    title: Text(
                      siap[i].namaPc,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.play_arrow,
                      color: AppColors.primaryLight,
                      size: 20,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Batal'),
            ),
          ],
        ),
      ),
    );
  }
}