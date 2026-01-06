import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../chats/chats_page.dart';

enum _NotificationGroupAction {
  togglePinned,
  markAllRead,
  deleteGroup,
  viewDetails,
}

class _NotificationGroup {
  _NotificationGroup({
    required this.key,
    required this.userId,
    required this.type,
    required this.orderId,
    required this.chatId,
    required this.notifications,
  });

  final String key;
  final String userId;
  final String type;
   final String orderId;
  final String chatId;
  final List<Map<String, dynamic>> notifications;

  Map<String, dynamic> get latest => notifications.first;

  int get unreadCount => notifications
      .where((n) => !(n['read'] as bool? ?? false))
      .length;

  bool get isPinned => notifications
      .any((n) => (n['pinned'] as bool?) ?? false);
}

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _notifications = const [];
  String _search = '';
  bool _onlyUnread = false;
  final Map<String, bool> _expandedGroups = {};
  final Set<String> _selectedGroupKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final supabase = Supabase.instance.client;

    try {
      final data = await supabase
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(200);
      setState(() {
        _notifications = (data as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _loading = false;
        _selectedGroupKeys.clear();
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar notificações: $e';
        _loading = false;
      });
    }
  }

  Future<void> _toggleRead(Map<String, dynamic> n) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase
          .from('notifications')
          .update({'read': !(n['read'] as bool? ?? false)})
          .eq('id', n['id']);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao marcar como lida: $e')),
      );
    }
  }

  Future<void> _togglePinned(Map<String, dynamic> n) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase
          .from('notifications')
          .update({'pinned': !(n['pinned'] as bool? ?? false)})
          .eq('id', n['id']);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao fixar notificação: $e')),
      );
    }
  }

  Future<void> _deleteNotification(Map<String, dynamic> n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar notificação'),
        content: const Text(
          'Tem certeza que deseja apagar esta notificação? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final supabase = Supabase.instance.client;
    try {
      await supabase
          .from('notifications')
          .delete()
          .eq('id', n['id']);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao apagar notificação: $e')),
      );
    }
  }

  Future<void> _createNotification() async {
    final userIdController = TextEditingController();
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    bool pinned = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Nova notificação'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: userIdController,
                    decoration: const InputDecoration(
                      labelText: 'User ID (uuid)',
                    ),
                  ),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Título'),
                  ),
                  TextField(
                    controller: messageController,
                    decoration: const InputDecoration(labelText: 'Mensagem'),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: pinned,
                        onChanged: (v) => setStateDialog(() {
                          pinned = v ?? false;
                        }),
                      ),
                      const Text('Fixar (pinned)'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Enviar'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    final supabase = Supabase.instance.client;

    try {
      await supabase.from('notifications').insert({
        'user_id': userIdController.text.trim(),
        'title': titleController.text.trim(),
        'message': messageController.text.trim(),
        'pinned': pinned,
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar notificação: $e')),
      );
    }
  }

  List<_NotificationGroup> _buildGroups(
    List<Map<String, dynamic>> list,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final n in list) {
      final userId = (n['user_id'] as String? ?? '');
      final type = n['type']?.toString() ?? '';
      final orderId = (n['order_id']?.toString() ?? '');
      final chatId = (n['chat_id']?.toString() ?? '');

      String groupKey;
      final typeLower = type.toLowerCase();

      if (typeLower == 'chat' && chatId.isNotEmpty) {
        groupKey = 'chat|$chatId';
      } else if ((typeLower == 'pedido' || typeLower == 'order') &&
          orderId.isNotEmpty) {
        groupKey = 'pedido|$orderId';
      } else {
        groupKey = '$userId|$type|$orderId|$chatId';
      }

      grouped.putIfAbsent(groupKey, () => []).add(n);
    }

    final groups = grouped.entries.map((entry) {
      final items = entry.value;
      items.sort((a, b) {
        final aCreated = (a['created_at'] as String?) ?? '';
        final bCreated = (b['created_at'] as String?) ?? '';
        return bCreated.compareTo(aCreated);
      });

      final first = items.first;

      return _NotificationGroup(
        key: entry.key,
        userId: (first['user_id'] as String? ?? ''),
        type: first['type']?.toString() ?? '',
        orderId: (first['order_id']?.toString() ?? ''),
        chatId: (first['chat_id']?.toString() ?? ''),
        notifications: items,
      );
    }).toList();

    groups.sort((a, b) {
      final aCreated = (a.latest['created_at'] as String?) ?? '';
      final bCreated = (b.latest['created_at'] as String?) ?? '';
      return bCreated.compareTo(aCreated);
    });

    return groups;
  }

  Future<void> _markGroupRead(_NotificationGroup group) async {
    final ids = group.notifications
        .where((n) => !(n['read'] as bool? ?? false))
        .map((n) => n['id'])
        .toList();

    if (ids.isEmpty) return;

    // Atualiza imediatamente em memória para tirar o negrito e o badge +N
    setState(() {
      _notifications = _notifications.map((n) {
        if (ids.contains(n['id'])) {
          final updated = Map<String, dynamic>.from(n);
          updated['read'] = true;
          return updated;
        }
        return n;
      }).toList();
    });

    // Persiste no Supabase em segundo plano (um a um para garantir)
    final supabase = Supabase.instance.client;
    try {
      for (final id in ids) {
        await supabase
            .from('notifications')
            .update({'read': true})
            .eq('id', id);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao marcar grupo como lido: $e')),
      );
    }
  }

  Future<void> _toggleGroupPinned(_NotificationGroup group) async {
    final ids = group.notifications.map((n) => n['id']).toList();
    if (ids.isEmpty) return;

    final newPinned = !group.isPinned;
    final supabase = Supabase.instance.client;
    try {
      await supabase
          .from('notifications')
          .update({'pinned': newPinned})
          .inFilter('id', ids);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar fixação: $e')),
      );
    }
  }

  Future<void> _deleteGroup(_NotificationGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar notificações'),
        content: Text(
          'Apagar todas as ${group.notifications.length} notificações deste grupo? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar grupo'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ids = group.notifications.map((n) => n['id']).toList();
    if (ids.isEmpty) return;

    final supabase = Supabase.instance.client;
    try {
      await supabase
          .from('notifications')
          .delete()
          .inFilter('id', ids);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao apagar grupo: $e')),
      );
    }
  }

  bool _isGroupSelected(_NotificationGroup group) =>
      _selectedGroupKeys.contains(group.key);

  void _toggleGroupSelected(_NotificationGroup group, bool selected) {
    setState(() {
      if (selected) {
        _selectedGroupKeys.add(group.key);
      } else {
        _selectedGroupKeys.remove(group.key);
      }
    });
  }

  Future<void> _deleteSelectedGroups() async {
    if (_selectedGroupKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum grupo selecionado.')),
      );
      return;
    }

    final allGroups = _buildGroups(_notifications);
    final toDelete =
        allGroups.where((g) => _selectedGroupKeys.contains(g.key)).toList();
    if (toDelete.isEmpty) return;

    final totalNotifs =
        toDelete.fold<int>(0, (sum, g) => sum + g.notifications.length);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar selecionados'),
        content: Text(
          'Apagar $totalNotifs notificações em ${toDelete.length} grupos selecionados? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ids = <dynamic>[];
    for (final g in toDelete) {
      ids.addAll(g.notifications.map((n) => n['id']));
    }
    if (ids.isEmpty) return;

    final supabase = Supabase.instance.client;
    try {
      await supabase
          .from('notifications')
          .delete()
          .inFilter('id', ids);

      setState(() {
        _notifications = _notifications
            .where((n) => !ids.contains(n['id']))
            .toList();
        _selectedGroupKeys.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao apagar selecionados: $e')),
      );
    }
  }

  Future<void> _onGroupTap(_NotificationGroup group) async {
    final typeLower = group.type.toLowerCase();
    await _markGroupRead(group);

    if (typeLower == 'chat') {
      if (group.chatId.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (routeContext) => Scaffold(
              appBar: AppBar(
                title: const Text('Chats'),
              ),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ChatsPage(initialChatId: group.chatId),
                ),
              ),
            ),
          ),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (routeContext) => Scaffold(
              appBar: AppBar(
                title: const Text('Chats'),
              ),
              body: const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: ChatsPage(),
                ),
              ),
            ),
          ),
        );
      }
      return;
    }

    _showGroupDetails(group);
  }

  void _showGroupDetails(_NotificationGroup group) {
    final theme = Theme.of(context);

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Notificações (${group.notifications.length})',
          ),
          content: SizedBox(
            width: 520,
            height: 360,
            child: ListView.builder(
              itemCount: group.notifications.length,
              itemBuilder: (context, index) {
                final n = group.notifications[index];
                final title = (n['title'] as String? ?? '');
                final message = (n['message'] as String? ?? '').trim();
                final createdAt = (n['created_at'] as String?) ?? '-';
                final read = (n['read'] as bool?) ?? false;

                final textStyle = theme.textTheme.bodyMedium?.copyWith(
                  fontWeight:
                      read ? FontWeight.normal : FontWeight.w600,
                );

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title.isEmpty ? '(Sem título)' : title,
                          style: textStyle),
                      const SizedBox(height: 2),
                      Text(
                        message,
                        style: textStyle,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        createdAt,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color
                              ?.withOpacity(0.7),
                        ),
                      ),
                      const Divider(height: 12),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }

    final isWide = MediaQuery.of(context).size.width > 900;

    final total = _notifications.length;
    final unread =
        _notifications.where((n) => !(n['read'] as bool? ?? false)).length;

    final query = _search.toLowerCase();
    final filtered = _notifications.where((n) {
      if (_onlyUnread && (n['read'] as bool? ?? false)) return false;
      final title = (n['title'] as String? ?? '').toLowerCase();
      final message = (n['message'] as String? ?? '').toLowerCase();
      final userId = (n['user_id'] as String? ?? '').toLowerCase();
      if (query.isEmpty) return true;
      return title.contains(query) ||
          message.contains(query) ||
          userId.contains(query);
    }).toList();

    final groups = _buildGroups(filtered);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Wrap(
              spacing: 16,
              children: [
                Chip(label: Text('Total: $total')),
                Chip(label: Text('Não lidas: $unread')),
              ],
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _selectedGroupKeys.isEmpty
                      ? null
                      : _deleteSelectedGroups,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Apagar selecionados'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _createNotification,
                  icon: const Icon(Icons.add),
                  label: const Text('Nova notificação'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar por título, mensagem ou user',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {
                    _search = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            FilterChip(
              label: const Text('Somente não lidas'),
              selected: _onlyUnread,
              onSelected: (v) {
                setState(() => _onlyUnread = v);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: groups.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 80),
                      Center(
                        child: Text(
                          'Nenhuma notificação encontrada com os filtros.',
                        ),
                      ),
                    ],
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;

                      if (maxWidth > 900) {
                        // Modo desktop: tabela agrupando notificações por user/tipo/pedido
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            DataTable(
                              columnSpacing: 16,
                              columns: const [
                                DataColumn(label: Text('User')),
                                DataColumn(label: Text('Título')),
                                DataColumn(label: Text('Mensagem (última)')),
                                DataColumn(label: Text('Tipo')),
                                DataColumn(label: Text('Criada em')),
                                DataColumn(label: Text('Ações')),
                              ],
                              rows: groups.map((group) {
                                final latest = group.latest;
                                final userId =
                                    (latest['user_id'] as String? ?? '');
                                final title =
                                    (latest['title'] as String? ?? '-');
                                final message =
                                    (latest['message'] as String? ?? '')
                                        .replaceAll(
                                            RegExp(r'\s+'), ' ');
                                final createdAt =
                                    (latest['created_at'] as String?) ?? '-';
                                final unreadCount = group.unreadCount;
                                final orderId = group.orderId;

                                final typeLower = group.type.toLowerCase();
                                String typeLabel;
                                if ((typeLower == 'pedido' ||
                                        typeLower == 'order') &&
                                    orderId.isNotEmpty) {
                                  typeLabel = 'Pedido $orderId';
                                } else if (typeLower == 'chat') {
                                  typeLabel = 'Chat';
                                } else {
                                  typeLabel = group.type.isEmpty
                                      ? '-'
                                      : group.type;
                                }

                                final textStyle =
                                    Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: unreadCount > 0
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        );

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      SizedBox(
                                        width: 96,
                                        child: Row(
                                          children: [
                                            Checkbox(
                                              value:
                                                  _isGroupSelected(group),
                                              onChanged: (v) =>
                                                  _toggleGroupSelected(
                                                group,
                                                v ?? false,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                userId.isEmpty
                                                    ? '-'
                                                    : userId.substring(0, 8),
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: textStyle,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 180,
                                        child: InkWell(
                                          onTap: () => _onGroupTap(group),
                                          child: Text(
                                            title,
                                            overflow: TextOverflow.ellipsis,
                                            style: textStyle,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 260,
                                        child: Text(
                                          message,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: textStyle,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        typeLabel,
                                        style: textStyle,
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 140,
                                        child: Text(
                                          createdAt,
                                          overflow: TextOverflow.ellipsis,
                                          style: textStyle,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 96,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            if (unreadCount > 0)
                                              Container(
                                                margin:
                                                    const EdgeInsets.only(
                                                        right: 4),
                                                padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                                child: Text(
                                                  '+$unreadCount',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: Colors.white,
                                                      ),
                                                ),
                                              ),
                                            PopupMenuButton<
                                                _NotificationGroupAction>(
                                              tooltip: 'Opções',
                                              icon: const Icon(
                                                Icons.more_vert,
                                                size: 18,
                                              ),
                                              onSelected: (action) {
                                                final isChatGroup =
                                                    group.type
                                                        .toLowerCase() ==
                                                    'chat';
                                                switch (action) {
                                                  case _NotificationGroupAction
                                                        .togglePinned:
                                                    _toggleGroupPinned(group);
                                                    break;
                                                  case _NotificationGroupAction
                                                        .markAllRead:
                                                    _markGroupRead(group);
                                                    break;
                                                  case _NotificationGroupAction
                                                        .deleteGroup:
                                                    _deleteGroup(group);
                                                    break;
                                                  case _NotificationGroupAction
                                                        .viewDetails:
                                                    if (isChatGroup) {
                                                      _onGroupTap(group);
                                                    } else {
                                                      _showGroupDetails(group);
                                                    }
                                                    break;
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                PopupMenuItem(
                                                  value:
                                                      _NotificationGroupAction
                                                          .viewDetails,
                                                  child: Text(
                                                    group.type
                                                                .toLowerCase() ==
                                                            'chat'
                                                        ? 'Ver chat'
                                                        : 'Ver notificações',
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value:
                                                      _NotificationGroupAction
                                                          .markAllRead,
                                                  child: const Text(
                                                    'Marcar todas como lidas',
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value:
                                                      _NotificationGroupAction
                                                          .togglePinned,
                                                  child: Text(
                                                    group.isPinned
                                                        ? 'Desfixar grupo'
                                                        : 'Fixar grupo',
                                                  ),
                                                ),
                                                const PopupMenuDivider(),
                                                PopupMenuItem(
                                                  value:
                                                      _NotificationGroupAction
                                                          .deleteGroup,
                                                  child: const Text(
                                                    'Apagar grupo',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      }

                      // Modo mobile: cards verticais agrupando notificações
                      return ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          final latest = group.latest;
                          final userId =
                              (latest['user_id'] as String? ?? '');
                          final title =
                              (latest['title'] as String? ?? '');
                          final message =
                              (latest['message'] as String? ?? '').trim();
                          final orderId = group.orderId;
                          final typeLower = group.type.toLowerCase();
                          final typeLabel = (() {
                            if ((typeLower == 'pedido' ||
                                    typeLower == 'order') &&
                                orderId.isNotEmpty) {
                              return 'Pedido $orderId';
                            }
                            if (typeLower == 'chat') {
                              return 'Chat';
                            }
                            return group.type.isEmpty ? '-' : group.type;
                          })();
                          final created =
                              (latest['created_at'] as String?) ?? '-';
                          final unreadCount = group.unreadCount;

                          final isUnread = unreadCount > 0;
                          final titleStyle = Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: isUnread
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              );
                          final bodyStyle = Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontWeight: isUnread
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              );

                          return GestureDetector(
                            onTap: () {
                              _onGroupTap(group);
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 0,
                              ),
                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title.isEmpty
                                                    ? '(Sem título)'
                                                    : title,
                                                style: titleStyle,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                            PopupMenuButton<
                                                _NotificationGroupAction>(
                                              tooltip: 'Opções',
                                              icon: const Icon(
                                                Icons.more_vert,
                                                size: 18,
                                              ),
                                              onSelected: (action) {
                                                final isChatGroup =
                                                    group.type
                                                        .toLowerCase() ==
                                                    'chat';
                                                switch (action) {
                                                  case _NotificationGroupAction
                                                        .togglePinned:
                                                    _toggleGroupPinned(group);
                                                    break;
                                                  case _NotificationGroupAction
                                                        .markAllRead:
                                                    _markGroupRead(group);
                                                    break;
                                                  case _NotificationGroupAction
                                                        .deleteGroup:
                                                    _deleteGroup(group);
                                                    break;
                                                  case _NotificationGroupAction
                                                        .viewDetails:
                                                    if (isChatGroup) {
                                                      _onGroupTap(group);
                                                    } else {
                                                      _showGroupDetails(group);
                                                    }
                                                    break;
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                PopupMenuItem(
                                                  value:
                                                      _NotificationGroupAction
                                                          .viewDetails,
                                                  child: Text(
                                                    group.type
                                                                .toLowerCase() ==
                                                            'chat'
                                                        ? 'Ver chat'
                                                        : 'Ver notificações',
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value:
                                                      _NotificationGroupAction
                                                          .markAllRead,
                                                  child: const Text(
                                                    'Marcar todas como lidas',
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value:
                                                      _NotificationGroupAction
                                                          .togglePinned,
                                                  child: Text(
                                                    group.isPinned
                                                        ? 'Desfixar grupo'
                                                        : 'Fixar grupo',
                                                  ),
                                                ),
                                                const PopupMenuDivider(),
                                                PopupMenuItem(
                                                  value:
                                                      _NotificationGroupAction
                                                          .deleteGroup,
                                                  child: const Text(
                                                    'Apagar grupo',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'User: ${userId.isEmpty ? '-' : userId}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                        if ((typeLower == 'pedido' ||
                                                typeLower == 'order') &&
                                            orderId.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Pedido: $orderId',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                        const SizedBox(height: 4),
                                        Text(
                                          message,
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                          style: bodyStyle,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Tipo: $typeLabel'),
                                            Text(
                                              created,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.color
                                                        ?.withOpacity(0.7),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (unreadCount > 0)
                                    Positioned(
                                      right: 8,
                                      bottom: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          '+$unreadCount',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

