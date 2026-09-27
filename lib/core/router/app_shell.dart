import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/accounts/view/accounts_page.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/view/login_page.dart';
import '../../features/pcs/view/dashboard_page.dart';
import '../../features/pcs/view/pc_list_page.dart';
import '../../features/profile/view/profile_page.dart';
import '../../features/transactions/view/transactions_page.dart';
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
                PcListPage(),
                AccountsPage(),
                TransactionsPage(),
                ProfilePage(),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.computer_outlined),
                selectedIcon: Icon(Icons.computer),
                label: 'PC',
              ),
              NavigationDestination(
                icon: Icon(Icons.confirmation_number_outlined),
                selectedIcon: Icon(Icons.confirmation_number),
                label: 'Voucher',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Transaksi',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
    }
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
