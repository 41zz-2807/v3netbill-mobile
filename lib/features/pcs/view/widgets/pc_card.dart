import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/common.dart';
import '../../models/pc.dart';
import '../../providers/pc_provider.dart';

/// Kartu satu PC beserta tombol aksi.
///
/// Dipakai oleh [DashboardPage] dan [PcListPage] supaya tampilan dan
/// perilakunya identik di dua tempat.
class PcCard extends StatelessWidget {
  const PcCard({super.key, required this.pc});

  final Pc pc;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PcProvider>();
    final busy = provider.isBusy(pc.id);
    final (color, soft) = switch (pc.status) {
      PcStatus.active => (AppColors.active, AppColors.activeSoft),
      PcStatus.idle => (AppColors.idle, AppColors.idleSoft),
      PcStatus.offline => (AppColors.danger, AppColors.dangerSoft),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.computer, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pc.namaPc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      pc.ipClient ?? 'IP tidak diketahui',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(
                  label: pc.status.label, color: color, softColor: soft),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Heartbeat ${Formatters.relative(pc.lastHeartbeatAt)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          // Start
          SizedBox(
            width: double.infinity,
            child: PcActionButton(
              label: 'Mulai Sesi',
              icon: Icons.play_arrow,
              color: AppColors.active,
              enabled: pc.status.canOperate && !busy,
              loading: busy,
              onTap: () => _startSession(context, provider),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: PcActionButton(
                  label: 'Kunci',
                  icon: Icons.lock_outline,
                  color: AppColors.idle,
                  enabled: pc.status.canOperate && !busy,
                  loading: busy,
                  onTap: () => _run(context, provider.lock(pc.id), 'Kunci'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PcActionButton(
                  label: 'Stop',
                  icon: Icons.stop_circle_outlined,
                  color: AppColors.danger,
                  enabled: pc.status.canOperate && !busy,
                  loading: busy,
                  onTap: () =>
                      _run(context, provider.stopSession(pc.id), 'Stop'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PcActionButton(
                  label: 'Matikan',
                  icon: Icons.power_settings_new,
                  color: AppColors.danger,
                  enabled: pc.status.canOperate && !busy,
                  loading: busy,
                  onTap: () => _confirmShutdown(context, provider),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startSession(
    BuildContext context,
    PcProvider provider,
  ) async {
    final kodeCtrl = TextEditingController();
    final sandiCtrl = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mulai Sesi di ${pc.namaPc}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Masukkan kode voucher atau member beserta passwordnya.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: kodeCtrl,
              autofocus: true,
              maxLength: 6,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Kode',
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: sandiCtrl,
              maxLength: 4,
              obscureText: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Password',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mulai'),
          ),
        ],
      ),
    );

    if (submit != true || !context.mounted) return;
    final kode = kodeCtrl.text.trim();
    final sandi = sandiCtrl.text.trim();
    if (kode.isEmpty || sandi.isEmpty) {
      _toast(context, 'Kode dan password wajib diisi.', false);
      return;
    }
    final ok = await provider.startSession(
      pcId: pc.id,
      kode: kode,
      password: sandi,
    );
    if (!context.mounted) return;
    _toast(
      context,
      ok ? 'Sesi dimulai di ${pc.namaPc}.' : 'Gagal memulai sesi.',
      ok,
    );
  }

  void _toast(BuildContext context, String msg, bool ok) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: ok ? AppColors.active : AppColors.danger,
        ),
      );
  }

  void _run(BuildContext context, Future<bool> future, String label) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    future.then((ok) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Aksi $label berhasil.' : 'Aksi $label gagal.'),
          backgroundColor: ok ? AppColors.active : AppColors.danger,
        ),
      );
    });
  }

  Future<void> _confirmShutdown(
    BuildContext context,
    PcProvider provider,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Matikan ${pc.namaPc}?'),
        content: const Text(
          'PC akan kehilangan daya. Pelanggan yang sedang memakai akan '
          'terputus sesinya.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Matikan'),
          ),
        ],
      ),
    );
    if (yes == true && context.mounted) {
      _run(context, provider.shutdown(pc.id), 'Matikan');
    }
  }
}

/// Tombol aksi kecil di dalam [PcCard].
class PcActionButton extends StatelessWidget {
  const PcActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Container(
            height: 42,
            alignment: Alignment.center,
            child: loading
                ? SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 15, color: color),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
