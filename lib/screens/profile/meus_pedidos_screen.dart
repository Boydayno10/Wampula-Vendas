import 'package:flutter/material.dart';
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

  Future<void> _refreshOrders() async {
    // Recarregar pedidos do banco de dados
    await OrderService().loadOrders();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final allOrders = OrderService().orders;
    final orders = allOrders.where((order) {
      return order.id.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Meus pedidos'),
        elevation: 0,
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
                              statusLabel(order.status),
                              style: TextStyle(
                                color: statusColor(order.status),
                              ),
                            ),
                            trailing: Text(
                              '${order.total.toStringAsFixed(0)} MT',
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

Color statusColor(OrderStatus s) {
  switch (s) {
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
