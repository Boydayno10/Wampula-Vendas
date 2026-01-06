import '../models/notification_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_notification_helper.dart';

class NotificationService {
  static final _supabase = Supabase.instance.client;
  static bool enabled = true;

  // Lista "bruta" vinda do banco (pode ter várias linhas por chat)
  static final List<AppNotification> _notificationsRaw = [];

  // Lista agregada para uso na UI (1 linha por conversa de chat)
  static List<AppNotification> get notifications =>
      _aggregateNotifications(_notificationsRaw);

  // Stream realtime das notificações do usuário atual
  static Stream<List<AppNotification>> notificationsStream() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return const Stream.empty();
    }

    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at')
        .map((rows) {
          final previousIds = _notificationsRaw.map((n) => n.id).toSet();

          _notificationsRaw
            ..clear()
            ..addAll(
              rows.map(
                (json) => _notificationFromJson(json as Map<String, dynamic>),
              ),
            );

          // Disparar notificações locais para novas entradas não lidas
          for (final n in _notificationsRaw) {
            if (!previousIds.contains(n.id) && !n.read) {
              String prefix;
              switch (n.type) {
                case 'chat':
                  prefix = 'Nova mensagem';
                  break;
                case 'pedido':
                case 'entrega':
                  prefix = 'Atualização de pedido';
                  break;
                case 'promocao':
                  prefix = 'Nova promoção';
                  break;
                default:
                  prefix = 'Nova notificação';
              }

              final title = n.title.isNotEmpty ? n.title : prefix;
              final rawBody = n.message.isNotEmpty ? n.message : prefix;
              const maxLen = 80;
              final body = rawBody.length <= maxLen
                  ? rawBody
                  : rawBody.substring(0, maxLen).trimRight() + '…';

              LocalNotificationHelper.showNotification(
                title: title,
                body: body,
              );
            }
          }

          // Sempre expõe a lista já agregada
          return List.unmodifiable(notifications);
        });
  }

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

      _notificationsRaw.clear();
      for (var json in response as List) {
        _notificationsRaw.add(_notificationFromJson(json));
      }

      return notifications;
    } catch (e) {
      print('Erro ao carregar notificações: $e');
      return notifications;
    }
  }

  // Marcar notificação como lida
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'read': true})
          .eq('id', notificationId);

      final notification = _notificationsRaw.firstWhere(
        (n) => n.id == notificationId,
      );
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

      await _supabase.rpc(
        'mark_all_notifications_read',
        params: {'p_user_id': userId},
      );

      for (var notification in _notificationsRaw) {
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

      final count = await _supabase.rpc(
        'count_unread_notifications',
        params: {'p_user_id': userId},
      );

      return count ?? 0;
    } catch (e) {
      print('Erro ao contar notificações não lidas: $e');
      return 0;
    }
  }

  // Contador local (baseado na lista agregada em memória)
  static int get unreadCountLocal =>
      notifications.where((n) => !n.read).fold(0, (sum, n) {
        // Para conversas de chat, unreadCount já vem agregado (0 ou 1).
        // Para demais tipos (pedido, promoção, sistema), cada linha não lida
        // deve contar pelo menos como 1.
        final base = n.unreadCount > 0 ? n.unreadCount : 1;
        return sum + base;
      });

  // Contador de mensagens de chat não lidas (somatório por conversa)
  static int get unreadChatCountLocal => notifications
      .where((n) => n.type == 'chat' && !n.read)
      .fold(0, (sum, n) => sum + n.unreadCount);

  // Deletar notificação
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);

      _notificationsRaw.removeWhere((n) => n.id == notificationId);
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
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      type: (json['type'] ?? 'sistema').toString(),
      relatedId: json['related_id']?.toString(),
      read: json['read'] ?? false,
      pinned: json['pinned'] ?? false,
      unreadCount: json['unread_count'] is int
          ? json['unread_count'] as int
          : int.tryParse(json['unread_count']?.toString() ?? '0') ?? 0,
    );
  }

  // Fixar/Desfixar notificação
  static Future<void> togglePin(String notificationId, bool value) async {
    try {
      await _supabase
          .from('notifications')
          .update({'pinned': value})
          .eq('id', notificationId);

      final notification = _notificationsRaw.firstWhere(
        (n) => n.id == notificationId,
      );
      notification.pinned = value;
    } catch (e) {
      print('Erro ao fixar notificação: $e');
    }
  }

  // Deletar todas as notificações ligadas a um mesmo related_id (ex: um chat)
  static Future<void> deleteByRelatedId(String relatedId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('notifications')
          .delete()
          .eq('user_id', userId)
          .eq('related_id', relatedId);

      _notificationsRaw.removeWhere((n) => n.relatedId == relatedId);
    } catch (e) {
      print('Erro ao deletar notificações por relatedId: $e');
    }
  }

  // Marcar notificações de um chat como lidas e zerar contador
  static Future<void> markChatAsRead(String chatId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('notifications')
          .update({'read': true, 'unread_count': 0})
          .eq('user_id', userId)
          .eq('related_id', chatId)
          .eq('type', 'chat');

      for (final n in _notificationsRaw.where(
        (n) => n.type == 'chat' && n.relatedId == chatId,
      )) {
        n.read = true;
        n.unreadCount = 0;
      }
    } catch (e) {
      print('Erro ao marcar chat como lido: $e');
    }
  }

  // Agrega notificações de chat para termos apenas 1 linha por conversa
  // unreadCount agregado funciona como "+1" por conversa com algo não lido
  static List<AppNotification> _aggregateNotifications(
    List<AppNotification> all,
  ) {
    if (all.isEmpty) return const [];

    final Map<String, List<AppNotification>> chats = {};
    final List<AppNotification> others = [];

    for (final n in all) {
      if (n.type == 'chat' && n.relatedId != null && n.relatedId!.isNotEmpty) {
        chats.putIfAbsent(n.relatedId!, () => []).add(n);
      } else {
        others.add(n);
      }
    }

    final List<AppNotification> result = List.of(others);

    chats.forEach((chatId, list) {
      if (list.isEmpty) return;

      // Ordena por data e pega a mais recente para exibir
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final latest = list.last;

      // Soma o unreadCount real (unread_count) das linhas para
      // saber se existe alguma mensagem não lida neste chat.
      final unreadMessages = list.fold<int>(0, (sum, n) => sum + n.unreadCount);
      final pinned = list.any((n) => n.pinned);

      result.add(
        AppNotification(
          id: latest.id,
          title: latest.title,
          message: latest.message,
          createdAt: latest.createdAt,
          type: latest.type,
          relatedId: chatId,
          // Considera lido quando não há nenhuma mensagem não lida
          read: unreadMessages == 0,
          pinned: pinned,
          // Na UI mostramos sempre "+1" por conversa com algo não lido
          unreadCount: unreadMessages > 0 ? 1 : 0,
        ),
      );
    });

    return result;
  }
}
