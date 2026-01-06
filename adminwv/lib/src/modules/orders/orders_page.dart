import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

enum _OrderAction {
  viewItems,
  editStatus,
  approveRefund,
  refuseRefund,
  deleteClient,
}

enum _SellerOrderAction {
  deleteSeller,
}

class _OrdersPageState extends State<OrdersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loadingOrders = true;
  bool _loadingSellerOrders = true;
  String? _error;
  List<Map<String, dynamic>> _orders = const [];
  List<Map<String, dynamic>> _sellerOrders = const [];
  String _search = '';
  bool _onlyPendingDelivery = false;

  // Larguras ajustáveis das colunas (similar à tela de Usuários)
  double _idColumnWidth = 100;
  double _clientColumnWidth = 120;
  double _totalColumnWidth = 90;
  double _paymentColumnWidth = 140;
  double _statusColumnWidth = 140;
  double _refundColumnWidth = 220;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
    _loadSellerOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loadingOrders = true;
      _error = null;
    });

    final supabase = Supabase.instance.client;

    try {
      final data = await supabase.from('orders').select();
      setState(() {
        _orders = (data as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _loadingOrders = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar pedidos: $e';
        _loadingOrders = false;
      });
    }
  }

  Future<void> _loadSellerOrders() async {
    setState(() {
      _loadingSellerOrders = true;
    });

    final supabase = Supabase.instance.client;

    try {
      final data = await supabase.from('seller_orders').select();
      setState(() {
        _sellerOrders = (data as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _loadingSellerOrders = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar pedidos de vendedores: $e';
        _loadingSellerOrders = false;
      });
    }
  }

  Future<void> _editOrderStatus(Map<String, dynamic> order) async {
    final statusController = TextEditingController(
      text: (order['status'] as String?) ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alterar status do pedido'),
        content: TextField(
          controller: statusController,
          decoration: const InputDecoration(
            labelText: 'Novo status',
            helperText:
                'Use um valor válido do enum order_status configurado no banco.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final supabase = Supabase.instance.client;
    try {
      await supabase.from('orders').update({
        'status': statusController.text.trim(),
      }).eq('id', order['id']);
      await _loadOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar status: $e')),
      );
    }
  }

  Future<void> _toggleDeliveryConfirmed(Map<String, dynamic> order) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase
          .from('orders')
          .update({
            'delivery_confirmed': !(order['delivery_confirmed'] as bool? ?? false),
          })
          .eq('id', order['id']);
      await _loadOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar entrega: $e')),
      );
    }
  }

  Future<void> _setRefundDecision(
      Map<String, dynamic> order, String decision) async {
    final supabase = Supabase.instance.client;
    try {
      final reason = (order['refund_reason'] as String?) ?? '';
      await supabase.from('orders').update({
        'refund_reason': '$decision: $reason',
      }).eq('id', order['id']);
      await _loadOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao registrar decisão: $e')),
      );
    }
  }

  Future<void> _showOrderItems(String orderId) async {
    final supabase = Supabase.instance.client;

    try {
      final data = await supabase
          .from('order_items')
          .select()
          .eq('order_id', orderId);

      final items = (data as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();

      // ignore: use_build_context_synchronously
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Itens do pedido $orderId'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Produto')),
                  DataColumn(label: Text('Qtd')),
                  DataColumn(label: Text('Preço')),
                ],
                rows: items
                    .map(
                      (i) => DataRow(
                        cells: [
                          DataCell(Text(i['name'] as String)),
                          DataCell(Text((i['quantity'] as int).toString())),
                          DataCell(
                            Text((i['price'] as num).toStringAsFixed(2)),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar itens: $e')),
      );
    }
  }

  Future<void> _deleteClientOrder(Map<String, dynamic> order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir pedido do cliente'),
        content: Text(
          'Tem certeza que deseja excluir o pedido ${order['id']} da lista de clientes? Isto não remove os registros em "Pedidos vendedores".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final supabase = Supabase.instance.client;
    try {
      await supabase.from('orders').delete().eq('id', order['id']);
      await _loadOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir pedido: $e')),
      );
    }
  }

  Future<void> _deleteSellerOrder(Map<String, dynamic> sellerOrder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir pedido do vendedor'),
        content: Text(
          'Tem certeza que deseja excluir o pedido ${sellerOrder['id']} da lista de vendedores? O mesmo pedido também será removido da lista de clientes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir em ambos'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final supabase = Supabase.instance.client;
    try {
      final orderId =
          (sellerOrder['order_id'] as String?) ?? (sellerOrder['id'] as String);

      // Remove o registro na tabela de pedidos de vendedores
      await supabase.from('seller_orders').delete().eq('id', sellerOrder['id']);

      // Remove também o pedido principal da lista de clientes
      await supabase.from('orders').delete().eq('id', orderId);

      await _loadOrders();
      await _loadSellerOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir pedido do vendedor: $e')),
      );
    }
  }

  Widget _buildResizableHeader(
    String title,
    double width,
    ValueChanged<double> onResize,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: (details) {
            final newWidth =
                (width + details.delta.dx).clamp(70.0, 400.0) as double;
            onResize(newWidth);
          },
          child: SizedBox(
            width: 10,
            child: Center(
              child: Container(
                width: 2,
                height: 18,
                color:
                    Theme.of(context).dividerColor.withOpacity(0.7),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalOrders = _orders.length;
    final pendingOrders =
        _orders.where((o) => !(o['delivery_confirmed'] as bool? ?? false)).length;

    final query = _search.toLowerCase();
    final filteredOrders = _orders.where((o) {
      final id = (o['id'] as String).toLowerCase();
      final userId = (o['user_id'] as String).toLowerCase();
      final matchesQuery =
          query.isEmpty || id.contains(query) || userId.contains(query);
      if (!matchesQuery) return false;
      if (_onlyPendingDelivery && (o['delivery_confirmed'] as bool? ?? false)) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Chip(label: Text('Pedidos: $totalOrders')),
            Chip(label: Text('Pendentes: $pendingOrders')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar por ID do pedido ou cliente',
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
              label: const Text('Somente entrega pendente'),
              selected: _onlyPendingDelivery,
              onSelected: (v) {
                setState(() => _onlyPendingDelivery = v);
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Recarregar',
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _loadOrders();
                _loadSellerOrders();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Pedidos clientes'),
            Tab(text: 'Pedidos vendedores'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOrdersTable(filteredOrders),
              _buildSellerOrdersTable(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersTable(List<Map<String, dynamic>> orders) {
    if (_loadingOrders) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (orders.isEmpty) {
      return const Center(child: Text('Nenhum pedido encontrado.'));
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;

          if (maxWidth > 900) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                DataTable(
                  columnSpacing: 16,
                  columns: [
                    DataColumn(
                      label: _buildResizableHeader(
                        'ID',
                        _idColumnWidth,
                        (v) => setState(() => _idColumnWidth = v),
                      ),
                    ),
                    DataColumn(
                      label: _buildResizableHeader(
                        'Cliente',
                        _clientColumnWidth,
                        (v) => setState(() => _clientColumnWidth = v),
                      ),
                    ),
                    DataColumn(
                      label: _buildResizableHeader(
                        'Total',
                        _totalColumnWidth,
                        (v) => setState(() => _totalColumnWidth = v),
                      ),
                    ),
                    DataColumn(
                      label: _buildResizableHeader(
                        'Pagamento',
                        _paymentColumnWidth,
                        (v) => setState(() => _paymentColumnWidth = v),
                      ),
                    ),
                    DataColumn(
                      label: _buildResizableHeader(
                        'Status',
                        _statusColumnWidth,
                        (v) => setState(() => _statusColumnWidth = v),
                      ),
                    ),
                    const DataColumn(label: Text('Entrega')),
                    DataColumn(
                      label: _buildResizableHeader(
                        'Reembolso',
                        _refundColumnWidth,
                        (v) => setState(() => _refundColumnWidth = v),
                      ),
                    ),
                    const DataColumn(label: Text('')),
                  ],
                  rows: orders
                      .map(
                        (o) => DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: _idColumnWidth,
                                child: Text(
                                  (o['id'] as String).substring(0, 8),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: _clientColumnWidth,
                                child: Text(
                                  (o['user_id'] as String).substring(0, 8),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: _totalColumnWidth,
                                child: Text(
                                  (o['total'] as num).toStringAsFixed(2),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: _paymentColumnWidth,
                                child: Text(
                                  (o['payment_method'] as String?) ?? '-',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: _statusColumnWidth,
                                child: Text(
                                  (o['status'] as String?) ?? '-',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              Transform.scale(
                                scale: 0.7,
                                child: Switch(
                                  value:
                                      (o['delivery_confirmed'] as bool? ??
                                          false),
                                  onChanged: (_) =>
                                      _toggleDeliveryConfirmed(o),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: _refundColumnWidth,
                                child: Text(
                                  (o['refund_reason'] as String?) ?? '-',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              Align(
                                alignment: Alignment.centerRight,
                                child: PopupMenuButton<_OrderAction>(
                                  tooltip: 'Mais ações',
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (action) {
                                    switch (action) {
                                      case _OrderAction.viewItems:
                                        _showOrderItems(o['id'] as String);
                                        break;
                                      case _OrderAction.editStatus:
                                        _editOrderStatus(o);
                                        break;
                                      case _OrderAction.approveRefund:
                                        _setRefundDecision(o, 'APROVADO');
                                        break;
                                      case _OrderAction.refuseRefund:
                                        _setRefundDecision(o, 'RECUSADO');
                                        break;
                                      case _OrderAction.deleteClient:
                                        _deleteClientOrder(o);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: _OrderAction.viewItems,
                                      child: Text('Ver itens'),
                                    ),
                                    PopupMenuItem(
                                      value: _OrderAction.editStatus,
                                      child: Text('Alterar status'),
                                    ),
                                    PopupMenuItem(
                                      value: _OrderAction.approveRefund,
                                      child: Text('Aprovar reembolso'),
                                    ),
                                    PopupMenuItem(
                                      value: _OrderAction.refuseRefund,
                                      child: Text('Recusar reembolso'),
                                    ),
                                    PopupMenuItem(
                                      value: _OrderAction.deleteClient,
                                      child: Text('Excluir só do cliente'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ],
            );
          }

          // Mobile: cards com todas as informações
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final o = orders[index];
              final id = o['id'] as String;
              final userId = o['user_id'] as String;
              final total = (o['total'] as num).toStringAsFixed(2);
              final payment = (o['payment_method'] as String?) ?? '-';
              final status = (o['status'] as String?) ?? '-';
              final refund = (o['refund_reason'] as String?) ?? '-';
              final deliveryConfirmed =
                  (o['delivery_confirmed'] as bool? ?? false);

              return Card(
                margin:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Pedido ${id.substring(0, 8)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.list_alt, size: 18),
                            tooltip: 'Ver itens',
                            onPressed: () => _showOrderItems(id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Cliente: ${userId.substring(0, 8)}'),
                      Text('Total: $total'),
                      Text('Pagamento: $payment'),
                      Text('Status: $status'),
                      if (refund.isNotEmpty && refund != '-')
                        Text('Reembolso: $refund'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Entrega confirmada'),
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: deliveryConfirmed,
                              onChanged: (_) =>
                                  _toggleDeliveryConfirmed(o),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: PopupMenuButton<_OrderAction>(
                          tooltip: 'Mais ações',
                          icon: const Icon(Icons.more_vert),
                          onSelected: (action) {
                            switch (action) {
                              case _OrderAction.viewItems:
                                _showOrderItems(id);
                                break;
                              case _OrderAction.editStatus:
                                _editOrderStatus(o);
                                break;
                              case _OrderAction.approveRefund:
                                _setRefundDecision(o, 'APROVADO');
                                break;
                              case _OrderAction.refuseRefund:
                                _setRefundDecision(o, 'RECUSADO');
                                break;
                              case _OrderAction.deleteClient:
                                _deleteClientOrder(o);
                                break;
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: _OrderAction.viewItems,
                              child: Text('Ver itens'),
                            ),
                            PopupMenuItem(
                              value: _OrderAction.editStatus,
                              child: Text('Alterar status'),
                            ),
                            PopupMenuItem(
                              value: _OrderAction.approveRefund,
                              child: Text('Aprovar reembolso'),
                            ),
                            PopupMenuItem(
                              value: _OrderAction.refuseRefund,
                              child: Text('Recusar reembolso'),
                            ),
                            PopupMenuItem(
                              value: _OrderAction.deleteClient,
                              child: Text('Excluir só do cliente'),
                            ),
                          ],
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
    );
  }

  Widget _buildSellerOrdersTable() {
    if (_loadingSellerOrders) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_sellerOrders.isEmpty) {
      return const Center(child: Text('Nenhum pedido de vendedor.'));
    }

    return RefreshIndicator(
      onRefresh: _loadSellerOrders,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;

          if (maxWidth > 900) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                DataTable(
                  columnSpacing: 16,
                  columns: const [
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('Vendedor')),
                    DataColumn(label: Text('Produto')),
                    DataColumn(label: Text('Qtd')),
                    DataColumn(label: Text('Total')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Reembolso')),
                    DataColumn(label: Text('')),
                  ],
                  rows: _sellerOrders
                      .map(
                        (o) => DataRow(
                          cells: [
                            DataCell(Text(
                                (o['id'] as String).substring(0, 8))),
                            DataCell(Text((o['seller_id'] as String)
                                .substring(0, 8))),
                            DataCell(
                              SizedBox(
                                width: 180,
                                child: Text(
                                  o['product_name'] as String,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(
                                (o['quantity'] as int).toString())),
                            DataCell(Text((o['total'] as num)
                                .toStringAsFixed(2))),
                            DataCell(Text((o['status'] as String?) ?? '-')),
                            DataCell(
                                Text((o['refund_reason'] as String?) ?? '-')),
                            DataCell(
                              Align(
                                alignment: Alignment.centerRight,
                                child:
                                    PopupMenuButton<_SellerOrderAction>(
                                  tooltip: 'Mais ações',
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (action) {
                                    if (action ==
                                        _SellerOrderAction.deleteSeller) {
                                      _deleteSellerOrder(o);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: _SellerOrderAction.deleteSeller,
                                      child: Text(
                                        'Excluir do vendedor e do cliente',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: _sellerOrders.length,
            itemBuilder: (context, index) {
              final o = _sellerOrders[index];
              return Card(
                margin:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedido ${o['id'].toString().substring(0, 8)}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                          'Vendedor: ${(o['seller_id'] as String).substring(0, 8)}'),
                      Text('Produto: ${o['product_name']}'),
                      Text('Qtd: ${o['quantity']}'),
                      Text(
                          'Total: ${(o['total'] as num).toStringAsFixed(2)}'),
                      Text('Status: ${o['status'] ?? '-'}'),
                      if ((o['refund_reason'] as String?)?.isNotEmpty == true)
                        Text('Reembolso: ${o['refund_reason']}'),
                      Align(
                        alignment: Alignment.centerRight,
                        child: PopupMenuButton<_SellerOrderAction>(
                          tooltip: 'Mais ações',
                          icon: const Icon(Icons.more_vert),
                          onSelected: (action) {
                            if (action ==
                                _SellerOrderAction.deleteSeller) {
                              _deleteSellerOrder(o);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: _SellerOrderAction.deleteSeller,
                              child: Text(
                                'Excluir do vendedor e do cliente',
                              ),
                            ),
                          ],
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
    );
  }
}

