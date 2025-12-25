import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../utils/responsive_helper.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Future<void> _refreshNotifications() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final notifications = NotificationService.notifications;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Notificações',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: Column(
        children: [
          // 🔔 SWITCH
          Container(
            color: Colors.white,
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              title: Text(
                'Ativar notificações',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                  fontWeight: FontWeight.w600,
                ),
              ),
              value: NotificationService.enabled,
              activeColor: Colors.deepPurple,
              onChanged: (value) {
                setState(() {
                  NotificationService.toggle(value);
                });
              },
            ),
          ),

          const SizedBox(height: 8),

          // 📩 LISTA
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshNotifications,
              child: notifications.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhuma notificação',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: ResponsiveHelper.getResponsivePadding(context),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final n = notifications[index];

                        return Card(
                          elevation: 2,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: EdgeInsets.only(
                            bottom: ResponsiveHelper.getResponsiveSpacing(context, 12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.notifications,
                                color: Colors.deepPurple,
                                size: ResponsiveHelper.getResponsiveIconSize(context, 24),
                              ),
                            ),
                            title: Text(
                              n.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                              ),
                            ),
                            subtitle: Text(
                              n.message,
                              style: TextStyle(
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
