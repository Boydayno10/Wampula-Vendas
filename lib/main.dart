import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'routes.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://hhtoeixaqsnrurnkggkr.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhodG9laXhhcXNucnVybmtnZ2tyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY1NTk4ODMsImV4cCI6MjA4MjEzNTg4M30.PyhblLK8aQfzfTUywJhDCtuiWXw8UPhKQHal5gXTBwU',
  );
  
  // Verificar sessão ativa ao iniciar (login persistente)
  await AuthService.checkSession();
  
  runApp(const WampulaVendasApp());
}

class WampulaVendasApp extends StatelessWidget {
  const WampulaVendasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wampula Vendas',

      initialRoute: Routes.splash,
      routes: appRoutes,

      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
    );
  }
}
