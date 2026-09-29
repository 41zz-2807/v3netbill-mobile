import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/account_create_sheet.dart';
import '../../../shared/widgets/common.dart';
import '../models/account.dart';
import '../providers/accounts_provider.dart';

/// Halaman Voucher & Member: tab switcher, pencarian, daftar, dan aksi
/// massal saat ada yang dipilih.
class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.watch<AccountsProvider>();
    final list = p.visible;

    return Scaffold(
      body: Column(
        children: [
          // Judul + tombol refresh
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Voucher & Member',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => p.load(silent: true),
                  icon: const Icon(Icons.refresh),
                  color: AppColors.textSecondary,
                  tooltip: 'Muat ulang',
                ),
              ],
            ),
          ),

          // Tab switcher
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _TabBar(
              current: p.tab,
              voucherCount: p.countOf(AccountType.voucher),
              memberCount: p.countOf(AccountType.member),
              onChanged: p.setTab,
            ),
          ),

          // Pencarian
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              onChanged: p.setSearch,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: p.tab == AccountType.voucher
                    ? 'Cari kode voucher...'
                    : 'Cari nama member...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                suffixIcon: p.search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: AppColors.textMuted,
                        onPressed: () => p.setSearch(''),
                      ),
              ),
            ),
          ),

          // Bar jumlah terpilih
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            child: p.selectedCount == 0
                ? const SizedBox(width: double.infinity)
                : _SelectionBar(
                    onClear: p.clearSelection,
                    onTopup: () => _askAmount(
                      context,
                      title: 'Topup',
                      hint: 'Nominal yang ditambahkan (kelipatan 500)',
                      onSubmit: (v) => p.topupSelected(v),
                    ),
                    onWithdraw: () => _askAmount(
                      context,
                      title: 'Tarik Saldo',
                      hint: 'Nominal yang ditarik (kelipatan 500)',
                      onSubmit: (v) => p.withdrawSelected(v),
                    ),
                    onChangePassword: () => _gantiPassword(context, p),
                    onRevoke: () => _confirmRevoke(context, p),
                  ),
          ),

          if (p.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  p.error!,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 12),
                ),
              ),
            ),

          // Daftar
          Expanded(
            child: p.loading && p.all.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? EmptyState(
                        icon: p.search.isNotEmpty
                            ? Icons.search_off
                            : Icons.inbox_outlined,
                        title: p.search.isNotEmpty
                            ? 'Tidak ada hasil'
                            : 'Belum ada ${p.tab.label.toLowerCase()}',
                        message: p.search.isNotEmpty
                            ? 'Coba kata kunci lain.'
                            : 'Tekan tombol + untuk membuat ${p.tab.label.toLowerCase()} baru.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) =>
                            _AccountTile(account: list[i]),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, p),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Buat ${p.tab.label}'),
      ),
    );
  }

  Future<void> _openCreateSheet(
    BuildContext context,
    AccountsProvider p,
  ) async {
    final draft = await showAccountCreateSheet(context, tipe: p.tab);
    if (draft == null || !context.mounted) return;

    final ok = p.tab == AccountType.voucher
        ? await p.createVoucher(draft.nominal)
        : await p.createMember(
            nama: draft.nama,
            nominal: draft.nominal,
          );

    if (!context.mounted) return;
    _toast(context, ok ? 'Berhasil dibuat.' : 'Gagal membuat.', ok);
  }

  /// Ganti password satu akun yang dipilih.
  ///
  /// Dipakai operator, jadi tidak perlu password lama — sama seperti aksi
  /// ubah password di halaman web. Kolom ulangan dipakai supaya salah ketik
  /// tidak sampai terkirim.
  Future<void> _gantiPassword(
    BuildContext context,
    AccountsProvider p,
  ) async {
    if (p.selectedCount != 1) {
      _toast(context, 'Pilih tepat satu akun untuk ganti password.', false);
      return;
    }

    final baruCtrl = TextEditingController();
    final ulangCtrl = TextEditingController();

    final submit = await showModalBottomSheet<bool>(
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
            const Text(
              'Ganti Password Akun',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Berlaku untuk pelanggan. Kosongkan password lama di komputer bila ingin menyamarkan.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: baruCtrl,
              obscureText: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Password baru',
                prefixIcon: Icon(Icons.lock_outline, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ulangCtrl,
              obscureText: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Ulangi password baru',
                prefixIcon: Icon(Icons.lock_reset_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: () {
                final a = baruCtrl.text.trim();
                if (a.length < 4) return;
                if (a != ulangCtrl.text.trim()) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (submit != true || !context.mounted) return;

    final baru = baruCtrl.text.trim();
    if (baru.length < 4) {
      _toast(context, 'Password baru minimal 4 karakter.', false);
      return;
    }
    if (baru != ulangCtrl.text.trim()) {
      _toast(context, 'Ulangi password tidak sama.', false);
      return;
    }

    final id = p.selected.first;
    final ok = await p.changePasswordOne(id, baru);
    if (!context.mounted) return;
    _toast(context, ok ? 'Password diganti.' : 'Gagal mengganti password.', ok);
  }

  Future<void> _askAmount(
    BuildContext context, {
    required String title,
    required String hint,
    required Future<bool> Function(int) onSubmit,
  }) async {
    final ctrl = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(hintText: hint, suffixText: 'Rp'),
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

    if (submit != true || !context.mounted) return;
    final amount = int.tryParse(ctrl.text.trim()) ?? 0;
    if (amount <= 0) {
      _toast(context, 'Nominal tidak valid.', false);
      return;
    }
    final ok = await onSubmit(amount);
    if (!context.mounted) return;
    _toast(context, ok ? '$title berhasil.' : '$title gagal.', ok);
  }

  Future<void> _confirmRevoke(
    BuildContext context,
    AccountsProvider p,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nonaktifkan ${p.selectedCount} akun?'),
        content: const Text(
          'Akun yang dinonaktifkan tidak bisa dipakai lagi. Tindakan ini '
          'tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    final ok = await p.revokeSelected();
    if (!context.mounted) return;
    _toast(context, ok ? 'Akun dinonaktifkan.' : 'Gagal menonaktifkan.', ok);
  }

  void _toast(BuildContext context, String msg, bool ok) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: ok ? AppColors.active : AppColors.danger,
      ));
  }
}

/// Tab switcher Voucher / Member dengan jumlah.
class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.current,
    required this.voucherCount,
    required this.memberCount,
    required this.onChanged,
  });

  final AccountType current;
  final int voucherCount;
  final int memberCount;
  final void Function(AccountType) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          _tab(context, AccountType.voucher, voucherCount),
          _tab(context, AccountType.member, memberCount),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, AccountType t, int count) {
    final active = current == t;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(t),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: active ? AppColors.brandGradient : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                t.label,
                style: TextStyle(
                  color: active ? Colors.white : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.22)
                      : AppColors.bgCardAlt,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bar aksi yang muncul saat ada akun dipilih.
///
/// Tombolnya ikon saja tanpa keterangan. Bar versi lama memakai teks "N dipilih"
/// ditambah empat chip berlabel, dan total lebarnya melebihi layar HP — Flutter
/// melaporkan "RenderFlex overflowed by 261 pixels" pada lebar 390 px. Ikon dengan
/// tooltip menjaga bar ini muat di layar sempit tanpa kehilangan arti.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.onClear,
    required this.onTopup,
    required this.onWithdraw,
    required this.onRevoke,
    required this.onChangePassword,
  });

  final VoidCallback onClear;
  final VoidCallback onTopup;
  final VoidCallback onWithdraw;
  final VoidCallback onRevoke;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradientSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ikon(Icons.add, 'Topup', onTopup),
          _ikon(Icons.remove, 'Tarik', onWithdraw),
          _ikon(Icons.block, 'Revoke', onRevoke),
          _ikon(Icons.lock_outline, 'Password', onChangePassword),
          _ikon(Icons.close, 'Batalkan pilihan', onClear),
        ],
      ),
    );
  }

  Widget _ikon(IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 22, color: Colors.white),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Baris satu akun.
class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AccountsProvider>();
    final selected = p.isSelected(account.id);
    final (color, soft) = switch (account.status) {
      AccountStatus.active => (AppColors.active, AppColors.activeSoft),
      AccountStatus.revoked => (AppColors.danger, AppColors.dangerSoft),
      AccountStatus.expired => (AppColors.idle, AppColors.idleSoft),
    };

    return GestureDetector(
      onTap: () => p.toggleSelect(account.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.10)
              : AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: selected,
                onChanged: (_) => p.toggleSelect(account.id),
                side: const BorderSide(color: AppColors.textMuted, width: 1.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 12,
                        color: account.isHabis
                            ? AppColors.danger
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        Formatters.duration(account.sisaWaktuDetik),
                        style: TextStyle(
                          color: account.isHabis
                              ? AppColors.danger
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (account.isHabis) ...[
                        const SizedBox(width: 6),
                        const Text(
                          'Habis',
                          style: TextStyle(
                            color: AppColors.danger,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(
                  label: account.status.label,
                  color: color,
                  softColor: soft,
                ),
                const SizedBox(height: 6),
                Text(
                  Formatters.dateShort(account.createdAt),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
