import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../utils/responsive_helper.dart';

class PromotionNotificationsScreen extends StatefulWidget {
  const PromotionNotificationsScreen({super.key});

  @override
  State<PromotionNotificationsScreen> createState() => _PromotionNotificationsScreenState();
}

class _PromotionNotificationsScreenState extends State<PromotionNotificationsScreen> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  String _filter = 'Todos';

  Future<void> _refresh() async {
    await NotificationService.loadNotifications();
    if (mounted) setState(() {});
  }

  List<AppNotification> get _allPromotions {
    final list = NotificationService.notifications
        .where((n) => n.type == 'promocao')
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

  @override
  Widget build(BuildContext context) {
    final promos = _allPromotions;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectionMode
              ? '${_selectedIds.length} selecionada(s)'
              : 'Notificações de promoções',
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
        child: promos.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Sem notificações de promoções.')),
                ],
              )
            : ListView.builder(
                padding: ResponsiveHelper.getResponsivePadding(context),
                itemCount: promos.length,
                itemBuilder: (_, index) {
                  final n = promos[index];
                  final selected = _selectedIds.contains(n.id);
                  return _PromotionNotificationCard(
                    notification: n,
                    selected: selected,
                    onTap: () {
                      if (_selectionMode) {
                        _toggleSelection(n.id);
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

class _PromotionNotificationCard extends StatelessWidget {
  final AppNotification notification;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Future<void> Function() onDelete;

  const _PromotionNotificationCard({
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
