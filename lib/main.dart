import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/transactions/presentation/providers/transaction_provider.dart';
import 'features/dashboard/presentation/providers/dashboard_provider.dart';
import 'features/dashboard/presentation/providers/notification_center_provider.dart';
import 'features/reports/presentation/providers/budget_provider.dart';
import 'features/reports/presentation/providers/reminder_provider.dart';
import 'features/reports/presentation/providers/report_provider.dart';
import 'core/config/router.dart';
import 'core/theme/app_theme.dart';
import 'core/database/hive_manager.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/budget_background_worker.dart';
import 'shared/providers/connectivity_provider.dart';
import 'shared/widgets/no_internet_overlay.dart';
import 'package:workmanager/workmanager.dart';

import 'core/config/supabase_config.dart';

const String _supabaseUrl = SupabaseConfig.url;
const String _supabaseAnonKey = SupabaseConfig.anonKey;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

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

  // Inisialisasi WorkManager untuk background budget checks
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    'budget_check',
    budgetCheckTask,
    frequency: const Duration(hours: 6),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(
      networkType: NetworkType.notRequired,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
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
        // BudgetProvider depends on TransactionProvider — kept at global level
        // to prevent InheritedNotifierElement reconciliation on every tab switch
        ChangeNotifierProxyProvider<TransactionProvider, BudgetProvider>(
          create: (ctx) => BudgetProvider(
            txnProvider: ctx.read<TransactionProvider>(),
          ),
          update: (_, txnProvider, budgetProvider) =>
              budgetProvider ?? BudgetProvider(txnProvider: txnProvider),
        ),
        ChangeNotifierProvider(create: (_) => ReminderProvider()),
        ChangeNotifierProvider(create: (_) => NotificationCenterProvider()),
        ChangeNotifierProxyProvider<TransactionProvider, ReportProvider>(
          create: (_) => ReportProvider(),
          update: (_, txnProvider, reportProvider) {
            final provider = reportProvider ?? ReportProvider();
            provider.attachTransactionProvider(txnProvider);
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
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('id', 'ID'),
            Locale('en', 'US'),
          ],
          builder: (context, routerChild) => NoInternetOverlay(
            child: routerChild ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
