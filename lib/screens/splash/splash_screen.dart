import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../routes.dart';
import '../../utils/responsive_helper.dart';
import '../../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateAfterSplash();
  }

  Future<void> _navigateAfterSplash() async {
    await Future.delayed(const Duration(seconds: 2));

    // Verificar se usuário já está autenticado (login persistente)
    if (AuthService.isLoggedIn) {
      // Usuário autenticado - vai direto para Home
      Navigator.pushReplacementNamed(context, Routes.home);
      return;
    }

    // Usuário não autenticado: checar se já viu a tela de boas-vindas
    final prefs = await SharedPreferences.getInstance();
    final hasSeenWelcome = prefs.getBool('has_seen_welcome') ?? false;

    if (hasSeenWelcome) {
      // Já viu o welcome em algum momento – segue direto para Home
      Navigator.pushReplacementNamed(context, Routes.home);
    } else {
      // Primeira vez no app – mostra welcome
      Navigator.pushReplacementNamed(context, Routes.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = ResponsiveHelper.getResponsiveWidth(context, 30);
    final clampedLogoSize = logoSize < 100 ? 100.0 : (logoSize > 150 ? 150.0 : logoSize);
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        color: Theme.of(context).colorScheme.primary,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: clampedLogoSize,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.shopping_bag,
                    size: clampedLogoSize,
                    color: Colors.white,
                  );
                },
              ),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 16)),
              Text(
                'Wampula Vendas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, 22),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
