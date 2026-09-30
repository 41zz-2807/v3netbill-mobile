import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/accounts/view/accounts_page.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/view/login_page.dart';
import '../../features/pcs/view/dashboard_page.dart';
import '../../features/profile/view/profile_page.dart';
import '../apk/update_provider.dart';
import '../theme/app_colors.dart';

/// Kerangka aplikasi: menampilkan login dulu, lalu membungkus seluruh halaman
/// dengan bottom navigation.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final status = context.select<AuthProvider, AuthStatus>(
      (a) => a.status,
    );
    final adaPembaruan = context.select<UpdateProvider, bool>(
      (u) => u.adaPembaruan,
    );

    switch (status) {
      case AuthStatus.checking:
        return const _SplashPage();

      case AuthStatus.unauthenticated:
      case AuthStatus.submitting:
        return const LoginPage();

      case AuthStatus.authenticated:
        return Scaffold(
          // SafeArea menjaga isi tidak menimpa bar status HP, seperti jam
          // sinyal, dan bar navigasi Android di bagian bawah.
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _index,
              children: const [
                DashboardPage(),
                AccountsPage(),
                ProfilePage(),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            // Halaman PC dan Transaksi sengaja tidak ada sebagai tab terpisah.
            // Semua PC sudah tampil di dashboard, jadi tab PC hanya menduplikasi
            // isi yang sama.
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              const NavigationDestination(
                icon: Icon(Icons.confirmation_number_outlined),
                selectedIcon: Icon(Icons.confirmation_number),
                label: 'Voucher',
              ),
              // Penanda merah di pojok ikon kalau ada versi baru. Sengaja
              // titik kecil, bukan angka, supaya tidak membuat NavigationBar
              // melebar di HP layar sempit.
              NavigationDestination(
                icon: _Badge(
                  aktif: adaPembaruan,
                  child: const Icon(Icons.person_outline),
                ),
                selectedIcon: _Badge(
                  aktif: adaPembaruan,
                  child: const Icon(Icons.person),
                ),
                label: 'Profile',
              ),
            ],
          ),
        );
    }
  }
}

/// Titik merah kecil di pojok ikon tab Profile.
class _Badge extends StatelessWidget {
  const _Badge({required this.aktif, required this.child});

  final bool aktif;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!aktif) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -2,
          top: -1,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.danger,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.bgBase, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo-v3netbill.png',
              height: 48,
              errorBuilder: (_, __, ___) => const SizedBox(height: 48),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              height: 26,
              width: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}
