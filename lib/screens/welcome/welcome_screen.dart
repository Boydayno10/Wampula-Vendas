import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../routes.dart';
import '../../utils/responsive_helper.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _completeWelcome(BuildContext context, String route) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_welcome', true);
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final imageHeight = screenHeight * 0.3 < 280 ? screenHeight * 0.3 : 280.0;
    
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 8,
              right: 8,
              child: TextButton(
                onPressed: () {
                  _completeWelcome(context, Routes.home);
                },
                child: Text(
                  'Pular',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                  ),
                ),
              ),
            ),
            Padding(
              padding: ResponsiveHelper.getResponsivePadding(context, multiplier: 1.5),
              child: Column(
                children: [
                  const Spacer(),

                  Image.asset(
                    'assets/images/welcome_banner.png',
                    height: imageHeight,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: imageHeight,
                        color: Colors.grey[200],
                        child: Icon(
                          Icons.image,
                          size: ResponsiveHelper.getResponsiveIconSize(context, 64),
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),

                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 32)),

                  Text(
                    'Bem-vindo ao Wampula Vendas',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 22),
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 8)),

                  Text(
                    'As suas compras estão aqui',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                    ),
                  ),

                  const Spacer(),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _completeWelcome(context, Routes.login);
                          },
                          child: const Text('Criar conta'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _completeWelcome(context, Routes.login);
                          },
                          child: const Text('Login'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
