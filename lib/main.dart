import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/network/socket_service.dart';
import 'core/router/app_shell.dart';
import 'core/storage/secure_store.dart';
import 'core/theme/app_theme.dart';
import 'features/accounts/data/account_repository.dart';
import 'features/accounts/providers/accounts_provider.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/pcs/data/pc_repository.dart';
import 'features/transactions/data/transactions_repository.dart';
import 'features/pcs/providers/pc_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const V3NetbillApp());
}

class V3NetbillApp extends StatelessWidget {
  const V3NetbillApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Satu SecureStore dipakai bersama oleh ApiClient dan AuthRepository
    // supaya token hanya dibaca satu kali dan tidak ada dua salinan.
    final secureStore = SecureStore();
    final api = ApiClient(secureStore: secureStore);
    // Satu Socket.IO dipakai bersama oleh seluruh aplikasi.
    final socket = SocketService(secureStore);

    return MultiProvider(
      providers: [
        Provider<SecureStore>.value(value: secureStore),
        Provider<ApiClient>.value(value: api),
        Provider<SocketService>.value(value: socket),
        ChangeNotifierProvider(
          create: (_) =>
              AuthProvider(AuthRepository(api, secureStore))..bootstrap(),
        ),
        ChangeNotifierProvider(
          create: (_) => PcProvider(PcRepository(api, socket), socket),
        ),
        ChangeNotifierProvider(
          create: (_) => AccountsProvider(AccountRepository(api)),
        ),
        // Repository transaksi dipakai halaman transaksi, jadi didaftarkan
        // supaya halaman tidak memanggil API langsung.
        Provider<TransactionsRepository>(
          create: (_) => TransactionsRepository(api),
        ),
      ],
      child: MaterialApp(
        title: 'v3Netbill',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const _AppGate(),
      ),
    );
  }
}

/// Menghubungkan [ApiClient.onUnauthorized] ke [AuthProvider] supaya sesi
/// yang sudah tidak berlaku otomatis mengembalikan pengguna ke halaman login.
class _AppGate extends StatefulWidget {
  const _AppGate();

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final api = context.read<ApiClient>();
      final auth = context.read<AuthProvider>();
      api.onUnauthorized = auth.handleUnauthorized;
    });
  }

  @override
  Widget build(BuildContext context) => const AppShell();
}
