import 'package:flutter/material.dart';
import 'meus_pedidos_screen.dart';
import '../payments/payments_screen.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../seller/seller_dashboard.dart';
import 'edit_profile_screen.dart';
import 'view_profile_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../widgets/notification_bell.dart';
import '../../utils/auth_helper.dart';
import '../../routes.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel>(
      valueListenable: AuthService.currentUserNotifier,
      builder: (context, user, _) {
        final bool isLoggedIn = AuthService.isLoggedIn;
        final String formattedPhone = user.phone.startsWith('+258')
            ? user.phone
            : '+258 ${user.phone}';

        return Scaffold(
          // Fundo cinza claro no estilo iOS
          backgroundColor: const Color(0xFFF2F2F7),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
            title: const Text(
              'Perfil',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            automaticallyImplyLeading: false,
            actions: [NotificationBell(rootContext: context)],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              // 👤 TOPO DO PERFIL
              Card(
                elevation: 0,
                color: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      // Foto de perfil: se não logado, mostra avatar genérico
                      GestureDetector(
                        onTap: () {
                          if (!isLoggedIn) {
                            Navigator.pushNamed(context, Routes.login);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ViewProfileScreen(
                                  user: user,
                                ),
                              ),
                            );
                          }
                        },
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.deepPurple.shade50,
                          backgroundImage: isLoggedIn &&
                                  user.profileImageUrl != null &&
                                  user.profileImageUrl!.isNotEmpty &&
                                  user.profileImageUrl!.startsWith('http')
                              ? NetworkImage(user.profileImageUrl!)
                              : null,
                          child: !isLoggedIn ||
                                  user.profileImageUrl == null ||
                                  user.profileImageUrl!.isEmpty ||
                                  !user.profileImageUrl!.startsWith('http')
                              ? const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.deepPurple,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (!isLoggedIn) {
                                  Navigator.pushNamed(context, Routes.login);
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ViewProfileScreen(
                                        user: user,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isLoggedIn
                                        ? user.name
                                        : 'Iniciar sessão / Registar-se',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isLoggedIn
                                          ? Colors.black
                                          : Colors.deepPurple,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (isLoggedIn)
                                    Text(
                                      formattedPhone,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isLoggedIn)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.edit,
                                color: Colors.deepPurple),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const EditProfileScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 📦 MEUS PEDIDOS
              Card(
                elevation: 0,
                color: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long,
                        color: Colors.deepPurple),
                  ),
                  title: const Text(
                    'Meus pedidos',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    AuthHelper.executeWithAuth(
                      context,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MeusPedidosScreen(),
                          ),
                        );
                      },
                      message: 'Faça login para ver seus pedidos.',
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),

              // 💳 PAGAMENTOS (M-PESA)
              Card(
                elevation: 0,
                color: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        const Icon(Icons.payment, color: Colors.green),
                  ),
                  title: const Text(
                    'Pagamentos',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Gerir números M-Pesa'),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    AuthHelper.executeWithAuth(
                      context,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PaymentsScreen(),
                          ),
                        );
                      },
                      message:
                          'Faça login para gerir seus pagamentos.',
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),

              // ⭐ AVALIAR APP
              Card(
                elevation: 0,
                color: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.star_rate,
                        color: Colors.orange),
                  ),
                  title: const Text(
                    'Avaliar aplicativo',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                  onTap: () {},
                ),
              ),

              const SizedBox(height: 8),

              // ❓ AJUDA
              Card(
                elevation: 0,
                color: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.help_outline,
                        color: Colors.blue),
                  ),
                  title: const Text(
                    'Ajuda',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                  onTap: () {},
                ),
              ),

              const SizedBox(height: 8),

              // 🏪 PAINEL DO VENDEDOR (apenas quando logado e vendedor)
              if (isLoggedIn && user.isSeller)
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.store,
                          color: Colors.purple),
                    ),
                    title: const Text(
                      'Painel do vendedor',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SellerDashboard(),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 16),

              // 🚪 SAIR (apenas quando logado)
              if (isLoggedIn)
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          const Icon(Icons.logout, color: Colors.red),
                    ),
                    title: const Text(
                      'Sair',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.red,
                    ),
                    onTap: () {
                      AuthService.logout();
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        Routes.welcome,
                        (route) => false,
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
