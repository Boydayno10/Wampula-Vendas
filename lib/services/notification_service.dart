import '../models/notification_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final _supabase = Supabase.instance.client;
  static bool enabled = true;

  static final List<AppNotification> _notifications = [];

  static List<AppNotification> get notifications => _notifications;

  // Carregar notificações do Supabase
  static Future<List<AppNotification>> loadNotifications() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];
      
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      _notifications.clear();
      for (var json in response as List) {
        _notifications.add(_notificationFromJson(json));
      }
      
      return _notifications;
    } catch (e) {
      print('Erro ao carregar notificações: $e');
      return _notifications;
    }
  }

  // Marcar notificação como lida
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'read': true})
          .eq('id', notificationId);
      
      final notification = _notifications.firstWhere((n) => n.id == notificationId);
      notification.read = true;
    } catch (e) {
      print('Erro ao marcar notificação como lida: $e');
    }
  }

  // Marcar todas como lidas
  static Future<void> markAllAsRead() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      await _supabase.rpc('mark_all_notifications_read', params: {
        'p_user_id': userId,
      });
      
      for (var notification in _notifications) {
        notification.read = true;
      }
    } catch (e) {
      print('Erro ao marcar todas como lidas: $e');
    }
  }

  // Contar notificações não lidas
  static Future<int> countUnread() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;
      
      final count = await _supabase.rpc('count_unread_notifications', params: {
        'p_user_id': userId,
      });
      
      return count ?? 0;
    } catch (e) {
      print('Erro ao contar notificações não lidas: $e');
      return 0;
    }
  }

  // Deletar notificação
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
      
      _notifications.removeWhere((n) => n.id == notificationId);
    } catch (e) {
      print('Erro ao deletar notificação: $e');
    }
  }

  static void toggle(bool value) {
    enabled = value;
  }

  // Método auxiliar para converter JSON
  static AppNotification _notificationFromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      createdAt: DateTime.parse(json['created_at']),
      read: json['read'] ?? false,
    );
  }
}
