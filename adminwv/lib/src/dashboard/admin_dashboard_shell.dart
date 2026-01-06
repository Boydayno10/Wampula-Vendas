import 'dart:async';
import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../modules/users/users_page.dart';
import '../modules/products/products_page.dart';
import '../modules/orders/orders_page.dart';
import '../modules/sellers/sellers_page.dart';
import '../modules/finance/finance_page.dart';
import '../modules/chats/chats_page.dart';
import '../modules/notifications/notifications_page.dart';
import '../modules/logs/logs_page.dart';
import '../modules/banners/featured_banners_page.dart';

class AdminDashboardShell extends StatefulWidget {
  final Session session;

  const AdminDashboardShell({super.key, required this.session});

  @override
  State<AdminDashboardShell> createState() => _AdminDashboardShellState();
}

class _AdminDashboardShellState extends State<AdminDashboardShell> {
  int _selectedIndex = 0;

  int _unreadChats = 0;
  int _unreadNotifications = 0;
  StreamSubscription<List<Map<String, dynamic>>>? _notificationsSub;

  final _sections = const [
    _AdminSection('Visão geral', Icons.dashboard_outlined),
    _AdminSection('Usuários', Icons.people_alt_outlined),
    _AdminSection('Produtos', Icons.shopping_bag_outlined),
    _AdminSection('Pedidos', Icons.receipt_long_outlined),
    _AdminSection('Lojas & Vendedores', Icons.store_mall_directory_outlined),
    _AdminSection('Finanças', Icons.account_balance_wallet_outlined),
    _AdminSection('Chats', Icons.chat_bubble_outline),
    _AdminSection('Notificações', Icons.notifications_active_outlined),
    _AdminSection('Logs & Métricas', Icons.analytics_outlined),
    _AdminSection('Banners', Icons.slideshow_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _listenNotifications();
  }

  @override
  void dispose() {
    _notificationsSub?.cancel();
    super.dispose();
  }

  void _listenNotifications() {
    final supabase = Supabase.instance.client;

    _notificationsSub?.cancel();

    final stream = supabase
        .from('notifications')
        .stream(primaryKey: ['id']);

    _notificationsSub = stream.listen(
      (data) {
        if (!mounted) return;
        final list = data.cast<Map<String, dynamic>>();

        final unreadAll = list
            .where((n) => !(n['read'] as bool? ?? false))
            .length;

        final unreadChat = list.where((n) {
          final type = n['type']?.toString().toLowerCase() ?? '';
          final isChat = type == 'chat';
          final unread = !(n['read'] as bool? ?? false);
          return isChat && unread;
        }).length;

        setState(() {
          _unreadNotifications = unreadAll;
          _unreadChats = unreadChat;
        });
      },
      onError: (_) {
        // Ignora erros do stream; a UI continua funcionando sem badges.
      },
    );
  }

  int _badgeCountForIndex(int index) {
    switch (index) {
      case 6: // Chats
        return _unreadChats;
      case 7: // Notificações
        return _unreadNotifications;
      default:
        return 0;
    }
  }

  Widget _buildIconWithBadge(IconData icon, int count) {
    final baseIcon = Icon(icon);
    if (count <= 0) return baseIcon;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        baseIcon,
        Positioned(
          right: -6,
          top: -4,
          child: _NavBadge(count: count),
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const _OverviewPage();
      case 1:
        return const UsersPage();
      case 2:
        return const ProductsPage();
      case 3:
        return const OrdersPage();
      case 4:
        return const SellersPage();
      case 5:
        return const FinancePage();
      case 6:
        return const ChatsPage();
      case 7:
        return const AdminNotificationsPage();
      case 8:
        return const LogsPage();
      case 9:
        return const FeaturedBannersPage();
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.of(context).largerOrEqualTo(DESKTOP);

    final userEmail = widget.session.user.email ?? 'Admin';

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('Wampula Admin'),
              actions: [
                IconButton(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout),
                  tooltip: 'Sair',
                ),
              ],
            ),
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wampula Admin',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      userEmail,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    IconButton(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout),
                      tooltip: 'Sair',
                    ),
                  ],
                ),
              ),
              destinations: [
                for (var i = 0; i < _sections.length; i++)
                  NavigationRailDestination(
                    icon: _buildIconWithBadge(
                      _sections[i].icon,
                      _badgeCountForIndex(i),
                    ),
                    label: Text(_sections[i].label),
                  ),
              ],
            ),
          Expanded(
            child: Row(
              children: [
                if (!isDesktop)
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (index) {
                      setState(() => _selectedIndex = index);
                    },
                    labelType: NavigationRailLabelType.selected,
                    destinations: [
                      for (var i = 0; i < _sections.length; i++)
                        NavigationRailDestination(
                          icon: _buildIconWithBadge(
                            _sections[i].icon,
                            _badgeCountForIndex(i),
                          ),
                          label: Text(_sections[i].label),
                        ),
                    ],
                  ),
                Expanded(
                  child: Container(
                    color: Theme.of(context).colorScheme.surfaceVariant
                        .withOpacity(0.2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isDesktop)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _sections[_selectedIndex].label,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: _buildBody(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSection {
  final String label;
  final IconData icon;

  const _AdminSection(this.label, this.icon);
}

class _NavBadge extends StatelessWidget {
  final int count;

  const _NavBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final display = count > 99 ? '99+' : '$count';
    final colorScheme = Theme.of(context).colorScheme;

    return Container
    (
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.error,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        display,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onError,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _OverviewPage extends StatefulWidget {
  const _OverviewPage();

  @override
  State<_OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<_OverviewPage> {
  bool _loading = true;
  String? _error;
  int _activeUsers = 0;
  int _activeProducts = 0;
  int _ordersToday = 0;
  double _revenueToday = 0;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final supabase = Supabase.instance.client;

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      // Perfis: alguns projetos não têm a coluna "banned", então buscamos só o id
      final profilesFuture = supabase.from('profiles').select('id');
      final productsFuture = supabase.from('products').select('id, active');
      final ordersFuture = supabase
          .from('orders')
          .select('total, created_at')
          .gte('created_at', todayStart.toIso8601String())
          .lt('created_at', todayEnd.toIso8601String());

      final results = await Future.wait([
        profilesFuture,
        productsFuture,
        ordersFuture,
      ]);

      final profiles = results[0] as List;
      final products = results[1] as List;
      final orders = results[2] as List;

        // Como não filtramos por banned aqui, consideramos todos os perfis
        final activeUsers = profiles.length;

      final activeProducts = products
          .where((p) => (p['active'] as bool? ?? true))
          .length;

      final ordersToday = orders.length;
      final revenueToday = orders.fold<double>(
        0,
        (sum, o) => sum + ((o['total'] as num?)?.toDouble() ?? 0),
      );

      if (!mounted) return;
      setState(() {
        _activeUsers = activeUsers;
        _activeProducts = activeProducts;
        _ordersToday = ordersToday;
        _revenueToday = revenueToday;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar visão geral: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!));
    }

    final crossAxisCount =
        ResponsiveBreakpoints.of(context).largerOrEqualTo(DESKTOP)
            ? 4
            : ResponsiveBreakpoints.of(context).largerOrEqualTo(TABLET)
                ? 3
                : 2;

    String formatInt(int value) => value.toString();

    String formatCurrency(double value) {
      if (value == 0) return '0.00';
      return value.toStringAsFixed(2);
    }

    return RefreshIndicator(
      onRefresh: _loadMetrics,
      child: GridView.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _MetricCard(
            label: 'Usuários ativos',
            value: formatInt(_activeUsers),
            icon: Icons.people_alt_outlined,
          ),
          _MetricCard(
            label: 'Produtos ativos',
            value: formatInt(_activeProducts),
            icon: Icons.shopping_bag_outlined,
          ),
          _MetricCard(
            label: 'Pedidos hoje',
            value: formatInt(_ordersToday),
            icon: Icons.receipt_long_outlined,
          ),
          _MetricCard(
            label: 'Receita hoje (MZN)',
            value: formatCurrency(_revenueToday),
            icon: Icons.attach_money,
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
