import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/account_create_sheet.dart';
import '../../../../shared/widgets/common.dart';
import '../../../accounts/models/account.dart';
import '../../../accounts/providers/accounts_provider.dart';
import '../../models/pc.dart';
import '../../providers/pc_provider.dart';

/// Apa yang dipilih operator di dialog "Mulai Sesi".
enum _MulaiAksi {
  /// Pakai kode yang diketik manual.
  pakaiKode,

  /// Buat voucher baru, lalu pakai kodenya.
  buatVoucher,

  /// Buat member baru, lalu pakai kodenya.
  buatMember,
}

/// Kartu satu PC beserta tombol aksi.
///
/// Dipakai oleh dashboard dan halaman PC supaya tampilan dan perilakunya
/// identik di dua tempat.
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

    // Ikon di samping nama PC dipakai dua purposes sekaligus. Kalau agent PC
    // masih heartbeat dalam 30 detik terakhir, ikon jadi hijau karena itu
    // tanda koneksinya benar-benar sehat. Kalau sudah lama tidak heartbeat,
    // warna kembali mengikuti status PC supaya informasi statusnya tidak hilang.
    final (warnaIkon, warnaLatar) = pc.heartbeatSehat
        ? (AppColors.active, AppColors.activeSoft)
        : (color, soft);

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
                  color: warnaLatar,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.computer, size: 20, color: warnaIkon),
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

          // Info sesi yang sedang berjalan, kalau ada.
          if (pc.hasSession) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.bgCardAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.confirmation_number_outlined,
                    size: 15,
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pc.session!.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Formatters.duration(pc.session!.sisaDetik),
                    style: const TextStyle(
                      color: AppColors.active,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Aksi utama

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
              // Backend tidak punya perintah stop terpisah untuk operator.
              // Mengakhiri sesi dan mengunci layar memakai perintah yang sama,
              // jadi dua tombol itu digabung di sini.
              Expanded(
                child: PcActionButton(
                  label: 'Akhiri Sesi',
                  icon: Icons.lock_outline,
                  color: AppColors.idle,
                  enabled: pc.status.canOperate && !busy,
                  loading: busy,
                  onTap: () => _confirmEnd(context, provider),
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

  /// Dialog mulai sesi. Backend hanya meminta kode voucher atau member,
  /// tanpa password, karena proses ini dilakukan dari sisi operator.
  ///
  /// Kasir sering menemukan PC kosong dengan voucher yang sudah habis atau belum
  /// dibuat sama sekali. Karena itu dialog ini juga bisa membuat voucher atau
  /// member baru, lalu memakai kode yang barusan dibuat untuk langsung memulai
  /// sesi, supaya kasir tidak perlu naik ke halaman akun lalu kembali ke sini.
  Future<void> _startSession(
    BuildContext context,
    PcProvider provider,
  ) async {
    final kodeCtrl = TextEditingController();

    final aksi = await showDialog<_MulaiAksi>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mulai Sesi di ${pc.namaPc}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Masukkan kode voucher atau member.',
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
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            const Text(
              'Belum punya kode?',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pop(ctx, _MulaiAksi.buatVoucher),
                    icon: const Icon(Icons.confirmation_number_outlined,
                        size: 18),
                    label: const Text('Voucher'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(ctx, _MulaiAksi.buatMember),
                    icon: const Icon(Icons.person_outline, size: 18),
                    label: const Text('Member'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _MulaiAksi.pakaiKode),
            child: const Text('Mulai'),
          ),
        ],
      ),
    );

    if (aksi == null || !context.mounted) return;

    if (aksi == _MulaiAksi.buatVoucher || aksi == _MulaiAksi.buatMember) {
      await _buatLaluMulai(context, provider, aksi == _MulaiAksi.buatVoucher);
      return;
    }

    final kode = kodeCtrl.text.trim();
    if (kode.isEmpty) {
      _toast(context, 'Kode wajib diisi.', false);
      return;
    }
    final err = await provider.startSession(pcId: pc.id, kode: kode);
    if (!context.mounted) return;
    _toast(context, err ?? 'Sesi dimulai di ${pc.namaPc}.', err == null);
  }

  /// Membuat akun baru, lalu memakai kode barunya untuk memulai sesi.
  Future<void> _buatLaluMulai(
    BuildContext context,
    PcProvider provider,
    bool voucher,
  ) async {
    final tipe = voucher ? AccountType.voucher : AccountType.member;
    final accounts = context.read<AccountsProvider>();

    final draft = await showAccountCreateSheet(context, tipe: tipe);
    if (draft == null || !context.mounted) return;

    final akun = voucher
        ? await accounts.createVoucherDapatKode(draft.nominal)
        : await accounts.createMemberDapatKode(
            nama: draft.nama,
            password: draft.password,
            nominal: draft.nominal,
          );

    if (!context.mounted) return;
    if (akun == null) {
      _toast(context, accounts.error ?? 'Gagal membuat akun.', false);
      return;
    }

    // Voucher memakai kode uniknya, sedangkan member tidak punya kode sama
    // sekali. Backend mencari akun dari kode voucher dulu, lalu jatuh ke
    // pencocokan nama member, jadi untuk member yang dikirim adalah namanya.
    final kredensial = voucher ? akun.kodeUnik : akun.nama;
    if (kredensial == null || kredensial.isEmpty) {
      _toast(context, 'Akun dibuat, tapi kredensialnya tidak terbaca.', false);
      return;
    }

    final err = await provider.startSession(pcId: pc.id, kode: kredensial);
    if (!context.mounted) return;
    _toast(
      context,
      err ?? 'Sesi di ${pc.namaPc} berjalan dengan $kredensial.',
      err == null,
    );
  }

  Future<void> _confirmEnd(
    BuildContext context,
    PcProvider provider,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Akhiri sesi di PC ini?'),
        content: Text(
          pc.hasSession
              ? 'Akun ${pc.session!.displayName} akan dilepas, layar PC '
                  'dikunci, dan sisa waktu dikembalikan ke akun.'
              : 'Tidak ada sesi berjalan. Layar PC akan dikunci.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.idle),
            child: const Text('Akhiri'),
          ),
        ],
      ),
    );
    if (yes == true && context.mounted) {
      _run(context, () => provider.endSession(pc.id), 'Akhiri Sesi');
    }
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
      _run(context, () => provider.shutdown(pc.id), 'Matikan');
    }
  }

  void _run(
    BuildContext context,
    Future<String?> Function() action,
    String label,
  ) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    action().then((err) {
      if (!context.mounted) return;
      _toast(context, err ?? 'Aksi $label berhasil.', err == null);
    });
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
