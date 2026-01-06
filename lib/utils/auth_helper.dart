import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../routes.dart';

class AuthHelper {
  /// Verifica se o usuário está autenticado
  /// Se não estiver, redireciona para a tela de login
  /// Retorna true se autenticado, false caso contrário
  static bool requireAuth(BuildContext context, {String? message}) {
    if (!AuthService.isLoggedIn) {
      _showLoginDialog(context, message: message);
      return false;
    }
    return true;
  }

  /// Mostra um diálogo pedindo para fazer login
  static void _showLoginDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login necessário'),
        content: Text(
          message ?? 'Você precisa fazer login para continuar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, Routes.login);
            },
            child: const Text('Fazer Login'),
          ),
        ],
      ),
    );
  }

  /// Navega para uma tela que requer autenticação
  /// Se não autenticado, mostra diálogo de login
  static void navigateWithAuth(
    BuildContext context,
    String routeName, {
    String? message,
    Object? arguments,
  }) {
    if (requireAuth(context, message: message)) {
      Navigator.pushNamed(context, routeName, arguments: arguments);
    }
  }

  /// Executa uma ação que requer autenticação
  /// Se não autenticado, mostra diálogo de login
  static void executeWithAuth(
    BuildContext context,
    VoidCallback action, {
    String? message,
  }) {
    if (requireAuth(context, message: message)) {
      action();
    }
  }
}
