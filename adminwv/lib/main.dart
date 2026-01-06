import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/auth/admin_auth_gate.dart';
import 'src/theme/app_theme.dart';
import 'src/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: substitua pela mesma URL e anonKey usados no app principal
  await Supabase.initialize(
    url: 'https://hhtoeixaqsnrurnkggkr.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhodG9laXhhcXNucnVybmtnZ2tyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY1NTk4ODMsImV4cCI6MjA4MjEzNTg4M30.PyhblLK8aQfzfTUywJhDCtuiWXw8UPhKQHal5gXTBwU',
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeController(),
      child: const AdminWampulaApp(),
    ),
  );
}

class AdminWampulaApp extends StatelessWidget {
  const AdminWampulaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wampula Admin',
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: child!,
        breakpoints: const [
          Breakpoint(start: 0, end: 600, name: MOBILE),
          Breakpoint(start: 600, end: 1024, name: TABLET),
          Breakpoint(start: 1024, end: 1440, name: DESKTOP),
          Breakpoint(start: 1440, end: double.infinity, name: '4K'),
        ],
      ),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeController.themeMode,
      home: const AdminAuthGate(),
    );
  }
}
