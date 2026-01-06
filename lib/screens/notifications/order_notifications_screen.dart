import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../utils/responsive_helper.dart';
import '../profile/pedido_detalhe_screen.dart';
import '../seller/seller_orders_screen.dart';

class OrderNotificationsScreen extends StatefulWidget {
  const OrderNotificationsScreen({super.key});

  @override
  State<OrderNotificationsScreen> createState() => _OrderNotificationsScreenState();
}

class _OrderNotificationsScreenState extends State<OrderNotificationsScreen> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  String _filter = 'Todos'; // Todos, NaoLidos

  Future<void> _refresh() async {
    await NotificationService.loadNotifications();
    if (mounted) setState(() {});
  }

  List<AppNotification> get _allOrders {
    final list = NotificationService.notifications
        .where((n) => n.type == 'pedido' || n.type == 'entrega')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (_filter == 'NaoLidos') {
      return list.where((n) => !n.read).toList();
    }
    return list;
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectionMode = true;
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final ids = List<String>.from(_selectedIds);
    for (final id in ids) {
      await NotificationService.deleteNotification(id);
    }
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  Future<void> _openNotification(AppNotification n) async {
    // Mesmo comportamento da tela principal
    if (n.type == 'pedido' || n.type == 'entrega') {
      final orderId = n.relatedId;
      if (orderId == null || orderId.isEmpty) return;

      if (AuthService.currentUser.isSeller && n.type == 'pedido') {
        await NotificationService.markAsRead(n.id);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SellerOrdersScreen()),
        );
        return;
      }

      final order = await OrderService().getOrderById(orderId);
      if (!mounted || order == null) return;

      await NotificationService.markAsRead(n.id);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PedidoDetalheScreen(order: order),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = _allOrders;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectionMode
              ? '${_selectedIds.length} selecionada(s)'
              : 'Notificações de pedidos',
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _filter = value);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'Todos', child: Text('Todas')),
              PopupMenuItem(value: 'NaoLidos', child: Text('Não lidas')),
            ],
          ),
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: orders.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Sem notificações de pedidos.')),
                ],
              )
            : ListView.builder(
                padding: ResponsiveHelper.getResponsivePadding(context),
                itemCount: orders.length,
                itemBuilder: (_, index) {
                  final n = orders[index];
                  final selected = _selectedIds.contains(n.id);
                  return _OrderNotificationCard(
                    notification: n,
                    selected: selected,
                    onTap: () {
                      if (_selectionMode) {
                        _toggleSelection(n.id);
                      } else {
                        _openNotification(n);
                      }
                    },
                    onLongPress: () => _toggleSelection(n.id),
                    onDelete: () async {
                      await NotificationService.deleteNotification(n.id);
                      if (mounted) setState(() {});
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _OrderNotificationCard extends StatelessWidget {
  final AppNotification notification;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Future<void> Function() onDelete;

  const _OrderNotificationCard({
    required this.notification,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey(notification.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) async => await onDelete(),
            backgroundColor: Colors.red.shade50,
            foregroundColor: Colors.red,
            icon: Icons.delete_outline,
          ),
        ],
      ),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Card(
          color: selected
              ? Colors.deepPurple.shade50
              : (notification.read ? Colors.white : Colors.deepPurple.shade50),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected
                  ? Colors.deepPurple.withOpacity(0.35)
                  : (notification.read
                      ? Colors.grey.shade200
                      : Colors.deepPurple.withOpacity(0.2)),
            ),
          ),
          margin: EdgeInsets.only(
            bottom: ResponsiveHelper.getResponsiveSpacing(context, 12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            leading: Checkbox(
              value: selected,
              onChanged: (_) => onTap(),
            ),
            title: Text(
              notification.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(notification.message),
          ),
        ),
      ),
    );
  }
}
