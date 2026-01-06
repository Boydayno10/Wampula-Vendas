import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../services/notification_service.dart';
import '../../services/order_service.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../models/notification_model.dart';
import '../../screens/profile/pedido_detalhe_screen.dart';
import '../../screens/chat/chat_screen.dart';
import '../../screens/seller/seller_orders_screen.dart';
import '../../utils/responsive_helper.dart';
import 'order_notifications_screen.dart';
import 'promotion_notifications_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  StreamSubscription<List<AppNotification>>? _subscription;

  @override
  void initState() {
    super.initState();
    // Escuta o stream de notificações para atualizar a tela em tempo real
    _subscription = NotificationService.notificationsStream().listen((_) {
      if (mounted) setState(() {});
    });

    // Limpa notificações de chats que já não existem mais no Supabase
    _cleanupInvalidChatNotifications();

    // Assim que o utilizador abre a tela de notificações,
    // consideramos que ele visualizou tudo e zeramos o contador.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.markAllAsRead();
      await NotificationService.loadNotifications();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshNotifications() async {
    await NotificationService.loadNotifications();
    await _cleanupInvalidChatNotifications();
    if (mounted) setState(() {});
  }

  /// Remove notificações de conversas de chat que já foram apagadas do Supabase
  Future<void> _cleanupInvalidChatNotifications() async {
    final notifications = List<AppNotification>.from(
      NotificationService.notifications,
    );

    for (final n in notifications) {
      if (n.type != 'chat') continue;

      final chatId = n.relatedId;

      // Notificações antigas sem relatedId válido: remove direto
      if (chatId == null || chatId.isEmpty) {
        await NotificationService.deleteNotification(n.id);
        continue;
      }

      // Se o chat não existe mais no Supabase, remove todas as
      // notificações ligadas a esse chatId
      final chat = await ChatService.getChatById(chatId);
      if (chat == null) {
        await NotificationService.deleteByRelatedId(chatId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = NotificationService.notifications;

    // Notificações de pedidos (inclui criação, status e entrega)
    final pedidos =
        notifications
            .where((n) => n.type == 'pedido' || n.type == 'entrega')
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final promocoes = notifications.where((n) => n.type == 'promocao').toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final mensagens =
        notifications
            // Exclui pedidos / entregas / promoções desta seção
            .where(
              (n) =>
                  n.type != 'pedido' &&
                  n.type != 'promocao' &&
                  n.type != 'entrega',
            )
            .toList()
          ..sort((a, b) {
            if (a.pinned == b.pinned) {
              return b.createdAt.compareTo(a.createdAt);
            }
            return a.pinned ? -1 : 1;
          });

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Notificações',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: Column(
        children: [
          // 🔔 SWITCH
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                title: Text(
                  'Ativar notificações',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      16,
                    ),
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
          ),

          const SizedBox(height: 8),

          // 📩 LISTA
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshNotifications,
              child: ListView(
                padding: ResponsiveHelper.getResponsivePadding(context),
                children: [
                  const Text(
                    'Pedidos',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: pedidos.isEmpty
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const OrderNotificationsScreen(),
                              ),
                            );
                          },
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: pedidos.isEmpty
                              ? Colors.grey.shade200
                              : Colors.deepPurple.withOpacity(0.15),
                        ),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.receipt_long,
                          color: Colors.deepPurple,
                        ),
                        title: Text(
                          pedidos.isEmpty
                              ? 'Sem notificações de pedidos'
                              : 'Você tem ${pedidos.length} notificações de pedidos',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(
                              context,
                              14,
                            ),
                            fontWeight: pedidos.isEmpty
                                ? FontWeight.w400
                                : FontWeight.w600,
                          ),
                        ),
                        trailing: pedidos.isEmpty
                            ? null
                            : const Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Promoções',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: promocoes.isEmpty
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const PromotionNotificationsScreen(),
                              ),
                            );
                          },
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: promocoes.isEmpty
                              ? Colors.grey.shade200
                              : Colors.deepPurple.withOpacity(0.15),
                        ),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.local_offer,
                          color: Colors.deepPurple,
                        ),
                        title: Text(
                          promocoes.isEmpty
                              ? 'Sem notificações de promoções'
                              : 'Você tem ${promocoes.length} notificações de promoções',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(
                              context,
                              14,
                            ),
                            fontWeight: promocoes.isEmpty
                                ? FontWeight.w400
                                : FontWeight.w600,
                          ),
                        ),
                        trailing: promocoes.isEmpty
                            ? null
                            : const Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Mensagens e Toques',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (mensagens.isEmpty)
                    Text(
                      'Sem notificações de mensagens ou toques',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: ResponsiveHelper.getResponsiveFontSize(
                          context,
                          14,
                        ),
                      ),
                    )
                  else
                    ...mensagens.map(
                      (n) => _buildNotificationCard(
                        context,
                        n,
                        onTap: () => _handleNotificationTap(n),
                        onDelete: () => _deleteSingle(n),
                        onTogglePin: () => _togglePin(n),
                        onLongDelete: () => _deleteConversation(n),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleNotificationTap(AppNotification n) async {
    // Pedidos / entrega
    if (n.type == 'pedido' || n.type == 'entrega') {
      final orderId = n.relatedId;
      if (orderId == null || orderId.isEmpty) return;

      // Se o usuário atual é vendedor, ao tocar em uma notificação de pedido
      // leva para a tela de pedidos do painel do vendedor.
      if (AuthService.currentUser.isSeller && n.type == 'pedido') {
        await NotificationService.markAsRead(n.id);

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SellerOrdersScreen()),
        );
        return;
      }

      // Cliente: abrir detalhes do pedido
      final order = await OrderService().getOrderById(orderId);
      if (!mounted || order == null) return;

      await NotificationService.markAsRead(n.id);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PedidoDetalheScreen(order: order)),
      );
      return;
    }

    // Mensagens: abrir chat correspondente
    final chatId = n.relatedId;
    if (chatId == null || chatId.isEmpty) return;

    // Ao tocar na notificação de chat, já marca como lida
    // para não ficar o "+1" depois de entrar na conversa.
    await NotificationService.markChatAsRead(chatId);

    final chat = await ChatService.getChatById(chatId);
    if (chat == null || !mounted) return;

    String pubName = 'Chat';

    // Se o chat estiver ligado a uma publicação, usar o nome da publicação.
    if (chat.publicationId != null) {
      pubName =
          await ChatService.getPublicationName(chat.publicationId!) ?? 'Chat';
    } else if (chat.orderCode != null && chat.orderCode!.isNotEmpty) {
      // Para chats diretos ligados a pedidos (reembolso/suporte), usar sempre
      // o código do pedido como título (ex: WP-00001), tanto para cliente
      // quanto para vendedor.
      pubName = chat.orderCode!;
    } else if (n.title.isNotEmpty) {
      // Fallback: usar o título salvo na notificação (assunto da conversa).
      pubName = n.title;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(chatId: chat.id, publicationName: pubName),
      ),
    );
  }

  Future<void> _deleteSingle(AppNotification n) async {
    // Para notificações de chat, apagar sempre TODAS as notificações
    // ligadas àquela conversa (relatedId), para que não reapareçam
    // quando chegar uma nova mensagem.
    if (n.type == 'chat' && n.relatedId != null && n.relatedId!.isNotEmpty) {
      await NotificationService.deleteByRelatedId(n.relatedId!);
    } else {
      await NotificationService.deleteNotification(n.id);
    }
    if (mounted) setState(() {});
  }

  Future<void> _togglePin(AppNotification n) async {
    await NotificationService.togglePin(n.id, !n.pinned);
    if (mounted) setState(() {});
  }

  Future<void> _deleteConversation(AppNotification n) async {
    final relatedId = n.relatedId;
    if (relatedId != null && relatedId.isNotEmpty) {
      await NotificationService.deleteByRelatedId(relatedId);
    } else {
      await NotificationService.deleteNotification(n.id);
    }

    if (mounted) setState(() {});
  }

  Widget _buildNotificationCard(
    BuildContext context,
    AppNotification n, {
    VoidCallback? onTap,
    Future<void> Function()? onDelete,
    Future<void> Function()? onTogglePin,
    Future<void> Function()? onLongDelete,
  }) {
    return Slidable(
      key: ValueKey(n.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        dismissible: onLongDelete == null
            ? null
            : DismissiblePane(
                onDismissed: () async {
                  await onLongDelete();
                },
              ),
        children: [
          SlidableAction(
            onPressed: (_) async {
              if (onDelete != null) await onDelete();
            },
            backgroundColor: Colors.red.shade50,
            foregroundColor: Colors.red,
            icon: Icons.delete_outline,
          ),
          SlidableAction(
            onPressed: (_) async {
              if (onTogglePin != null) await onTogglePin();
            },
            backgroundColor: Colors.amber.shade50,
            foregroundColor: Colors.amber[800]!,
            icon: n.pinned ? Icons.push_pin : Icons.push_pin_outlined,
          ),
        ],
      ),
      child: Stack(
        children: [
          Card(
            elevation: 2,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: EdgeInsets.only(
              bottom: ResponsiveHelper.getResponsiveSpacing(context, 12),
            ),
            child: ListTile(
              onTap: onTap,
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  n.type == 'chat'
                      ? Icons.chat_bubble_outline
                      : Icons.notifications,
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
              trailing: n.pinned
                  ? const Icon(Icons.push_pin, color: Colors.amber, size: 20)
                  : null,
            ),
          ),
          if (n.type == 'chat' && n.unreadCount > 0)
            Positioned(
              right: 16,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+${n.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
