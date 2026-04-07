import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Nanti inisialisasi Supabase dan Hive di sini
  // await Supabase.initialize(...);
  // await Hive.initFlutter();

  runApp(
    MultiProvider(
      providers: [
        // ProviderState akan didaftarkan di sini
        // ChangeNotifierProvider(create: (_) => AuthProvider()),
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
      designSize: const Size(360, 690), // Sesuaikan dengan ukuran desain dasar (biasanya iPhone atau ukuran rata2 Android)
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'Wangku',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.blue,
            textTheme: GoogleFonts.interTextTheme(
              Theme.of(context).textTheme,
            ),
            useMaterial3: true,
          ),
          home: child,
        );
      },
      child: const Scaffold(
        body: Center(
          child: Text('Wangku: Persiapan Selesai!'),
        ),
      ),
    );
  }
}
