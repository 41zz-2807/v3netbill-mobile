import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/apk/apk_repository.dart';
import 'core/apk/update_provider.dart';
import 'core/network/api_client.dart';
import 'core/network/socket_service.dart';
import 'core/notifikasi/notifikasi_provider.dart';
import 'core/notifikasi/notifikasi_repository.dart';
import 'core/notifikasi/push_client.dart';
import 'core/router/app_shell.dart';
import 'core/storage/secure_store.dart';
import 'core/theme/app_theme.dart';
import 'features/accounts/data/account_repository.dart';
import 'features/accounts/providers/accounts_provider.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/pcs/data/pc_repository.dart';
import 'features/pcs/providers/pc_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // WAJIB: `intl` tidak memuat data tanggal secara otomatis. Tanpa baris ini
  // setiap `DateFormat(..., 'id_ID')` melempar LocaleDataException, dan karena
  // format tanggal dipakai di dalam daftar akun, seluruh kartu gagal dibangun
  // sehingga daftar voucher dan member tampil kosong tanpa pesan apa pun.
  await initializeDateFormatting('id_ID', null);

  // Tanpa argumen: nilai project id, api key, dan sender id dibaca dari
  // resource yang di-generate plugin `com.google.gms.google-services` saat
  // build, bukan dari `firebase_options.dart`. File itu hanya dipakai untuk
  // iOS dan web.
  //
  // Sengaja dibungkus try/catch: kalau konfigurasi Firebase somehow tidak
  // terbaca, aplikasi harus tetap bisa dipakai untuk login dan berjualan
  // voucher. Notifikasi push yang hilang jauh lebih ringan daripada
  // aplikasi yang sama sekali tidak mau terbuka.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // Diabaikan dengan sengaja. Inisialisasi hanya gagal kalau
    // google-services.json rusak, dan itu bukan alasan memblokir aplikasi.
  }

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
    // Notifikasi push dibuat lebih dulu karena AuthProvider memakainya untuk
    // mendaftarkan token setelah login.
    final notifikasi = NotifikasiProvider(
      repository: NotifikasiRepository(api),
      store: secureStore,
      push: FirebasePushClient(),
    )..muat();

    return MultiProvider(
      providers: [
        Provider<SecureStore>.value(value: secureStore),
        Provider<ApiClient>.value(value: api),
        Provider<SocketService>.value(value: socket),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            AuthRepository(api, secureStore),
            notifikasi,
          )..bootstrap(),
        ),
        ChangeNotifierProvider(
          create: (_) => PcProvider(PcRepository(api, socket), socket),
        ),
        ChangeNotifierProvider(
          create: (_) => AccountsProvider(AccountRepository(api)),
        ),
        // Pembaruan aplikasi. Dibuat sekali bersama; pengecekan versi dipicu
        // dari DashboardPage, bukan dari sini, supaya tidak berjalan sebelum login.
        ChangeNotifierProvider(
          create: (_) => UpdateProvider(ApkRepository(api)),
        ),
        // Notifikasi push. Pendaftaran token dipicu dari AuthProvider setelah
        // login, bukan dari sini, supaya token tidak pernah dikirim sebelum
        // tahu owner-nya.
        ChangeNotifierProvider<NotifikasiProvider>.value(value: notifikasi),
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
