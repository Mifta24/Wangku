import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'features/auth/presentation/providers/auth_provider.dart';
import 'core/config/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi Supabase
  await Supabase.initialize(
    url: 'https://ctsehnuympzpkbdlwifc.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN0c2VobnV5bXB6cGtiZGx3aWZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU1MjMwOTMsImV4cCI6MjA5MTA5OTA5M30.7C2PbZ2GHq-vUrMi5Y0u7dqjt_H-S_c7gKVWWh__Mjc',
  );

  // Inisialisasi Hive
  await Hive.initFlutter();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
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
          theme: ThemeData(
            primaryColor: const Color(0xFF2563EB), // Modern Blue
            scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Slate 50
            textTheme: GoogleFonts.interTextTheme(
              Theme.of(context).textTheme,
            ),
            useMaterial3: true,
          ),
          routerConfig: appRouter,
        );
      },
    );
  }
}
