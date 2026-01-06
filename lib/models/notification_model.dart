class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  bool read; // Tornado mutável para poder atualizar
  final String type; // tipo vindo do Supabase (ex: pedido, promocao, sistema)
  final String? relatedId; // ID relacionado (pedido, chat, etc)
  bool pinned; // se a notificação está fixada
  int unreadCount; // usado para chats (quantidade de mensagens novas)

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.type,
    this.relatedId,
    this.read = false,
    this.pinned = false,
    this.unreadCount = 0,
  });
}
