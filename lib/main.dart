import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/transactions/presentation/providers/transaction_provider.dart';
import 'features/dashboard/presentation/providers/dashboard_provider.dart';
import 'core/config/router.dart';
import 'core/theme/app_theme.dart';
import 'core/database/hive_manager.dart';
import 'core/notifications/notification_service.dart';

const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    throw Exception(
      'SUPABASE_URL atau SUPABASE_ANON_KEY belum di-set. '
      'Jalankan app dengan --dart-define.',
    );
  }
  
  // Inisialisasi Supabase
  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  // Inisialisasi Hive
  await Hive.initFlutter();

  // Inisialisasi locale data untuk DateFormat (mis. id_ID)
  await initializeDateFormatting('id_ID');
  
  // Inisialisasi Hive Manager untuk database lokal
  await HiveManager.instance.initializeBoxes();

  // Inisialisasi notifikasi lokal
  await NotificationService.instance.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProxyProvider<TransactionProvider, DashboardProvider>(
          create: (_) => DashboardProvider(),
          update: (_, txnProvider, dashboardProvider) {
            final provider = dashboardProvider ?? DashboardProvider();
            provider.initialize(txnProvider);
            return provider;
          },
        ),
      ],
      child: const WangkuApp(),
    ),
  );
}

class WangkuApp extends StatelessWidget {
  const WangkuApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Inisialisasi ScreenUtil untuk ukuran yang responsif
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'Wangku',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: appRouter,
        );
      },
    );
  }
}
