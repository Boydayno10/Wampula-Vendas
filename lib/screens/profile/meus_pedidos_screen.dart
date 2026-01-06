import 'dart:async';

import 'package:flutter/material.dart';
import '../../utils/currency_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/order_service.dart';
import '../../models/order_model.dart';
import 'pedido_detalhe_screen.dart';

class MeusPedidosScreen extends StatefulWidget {
  const MeusPedidosScreen({super.key});

  @override
  State<MeusPedidosScreen> createState() => _MeusPedidosScreenState();
}

class _MeusPedidosScreenState extends State<MeusPedidosScreen> {
  String _searchQuery = '';
  RefundStatus? _refundFilter;

  StreamSubscription<List<Map<String, dynamic>>>? _ordersSubscription;

  @override
  void initState() {
    super.initState();
    _listenOrdersRealtime();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshOrders() async {
    // Recarregar pedidos do banco de dados
    await OrderService().loadOrders();
    setState(() {});
  }

  void _listenOrdersRealtime() {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    _ordersSubscription = client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((_) async {
          // Sempre recarrega a lista local ao ocorrer qualquer mudança
          await OrderService().loadOrders();
          if (mounted) {
            setState(() {});
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final allOrders = OrderService().orders;
    final orders = allOrders.where((order) {
      final matchesSearch = order.id.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );

      final matchesRefund = _refundFilter == null
          ? true
          : order.refundStatus == _refundFilter;

      return matchesSearch && matchesRefund;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: const BackButton(),
        title: const Text(
          'Meus pedidos',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      body: Column(
        children: [
          // 🔍 BARRA DE PESQUISA
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Pesquisar por número do pedido...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Filtros rápidos por status de reembolso
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _refundFilter == null,
                  onSelected: (_) {
                    setState(() => _refundFilter = null);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Reembolso solicitado'),
                  selected: _refundFilter == RefundStatus.requested,
                  onSelected: (_) {
                    setState(() => _refundFilter = RefundStatus.requested);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Reembolso em análise'),
                  selected: _refundFilter == RefundStatus.approved,
                  onSelected: (_) {
                    setState(() => _refundFilter = RefundStatus.approved);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Reembolso recusado'),
                  selected: _refundFilter == RefundStatus.denied,
                  onSelected: (_) {
                    setState(() => _refundFilter = RefundStatus.denied);
                  },
                ),
              ],
            ),
          ),

          // 📦 LISTA DE PEDIDOS
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshOrders,
              child: orders.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum pedido encontrado',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: orders.length,
                      itemBuilder: (_, index) {
                        final order = orders[index];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 1,
                          shadowColor:
                              Colors.black.withOpacity(0.05),
                          child: ListTile(
                            leading: const Icon(
                              Icons.shopping_bag,
                              size: 60,
                              color: Colors.deepPurple,
                            ),
                            title: Text(
                              'Pedido ${order.id}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              statusLabel(order.status, order.refundStatus),
                              style: TextStyle(
                                color: statusColor(
                                  order.status,
                                  order.refundStatus,
                                ),
                              ),
                            ),
                            trailing: Text(
                              CurrencyUtils.formatMt(order.total),
                              style: const TextStyle(
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PedidoDetalheScreen(order: order),
                                ),
                              ).then((_) {
                                // Atualizar lista quando voltar da tela de detalhes
                                setState(() {});
                              });
                            },
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

Color statusColor(OrderStatus status, RefundStatus refundStatus) {
  switch (refundStatus) {
    case RefundStatus.requested:
      return Colors.orange;
    case RefundStatus.approved:
      return Colors.green;
    case RefundStatus.denied:
      return Colors.red;
    case RefundStatus.none:
      break;
  }

  switch (status) {
    case OrderStatus.pendente:
      return Colors.orange;
    case OrderStatus.andamento:
      return Colors.blue;
    case OrderStatus.entregue:
      return Colors.green;
    case OrderStatus.reembolsoSolicitado:
      return Colors.red;
  }
}
