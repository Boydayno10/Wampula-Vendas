import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../screens/notifications/notifications_screen.dart';
import '../utils/auth_helper.dart';

class NotificationBell extends StatelessWidget {
  final BuildContext rootContext;

  const NotificationBell({super.key, required this.rootContext});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: NotificationService.notificationsStream(),
      builder: (context, snapshot) {
        // Usa a lista vinda do stream quando disponível para garantir
        // que o contador esteja sempre sincronizado em todas as telas
        final notificationsFromStream =
            (snapshot.data ?? NotificationService.notifications);

        final count = notificationsFromStream.where((n) => !n.read).fold<int>(
          0,
          (sum, n) {
            final base = n.unreadCount > 0 ? n.unreadCount : 1;
            return sum + base;
          },
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none),
              onPressed: () {
                AuthHelper.executeWithAuth(rootContext, () {
                  Navigator.push(
                    rootContext,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                }, message: 'Faça login para ver suas notificações.');
              },
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 16,
                  ),
                  child: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
