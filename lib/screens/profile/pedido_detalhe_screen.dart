import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';

class PedidoDetalheScreen extends StatefulWidget {
  final OrderModel order;
  const PedidoDetalheScreen({super.key, required this.order});

  @override
  State<PedidoDetalheScreen> createState() => _PedidoDetalheScreenState();
}

class _PedidoDetalheScreenState extends State<PedidoDetalheScreen> {
  late OrderModel _currentOrder;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    // Recarregar dados ao abrir a tela
    _refreshOrderDetails();
  }

  Future<void> _refreshOrderDetails() async {
    setState(() => _isLoading = true);
    
    // Buscar pedido atualizado do banco de dados
    final updatedOrder = await OrderService().getOrderById(_currentOrder.id);
    
    if (updatedOrder != null && mounted) {
      setState(() {
        _currentOrder = updatedOrder;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _solicitarReembolso() async {
    final motivos = [
      'Produto com defeito',
      'Produto diferente do anunciado',
      'Produto não chegou',
      'Mudei de ideia',
      'Preço mais barato em outro lugar',
      'Outro motivo',
    ];

    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Motivo do Reembolso'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: motivos.map((m) => ListTile(
            title: Text(m),
            onTap: () => Navigator.pop(ctx, m),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (motivo != null) {
      await OrderService().solicitarReembolso(_currentOrder, motivo);
      
      // Recarregar pedido atualizado do banco
      await _refreshOrderDetails();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitação de reembolso enviada'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Widget buildActionButtons() {
    final order = _currentOrder;

    switch (order.status) {
      case OrderStatus.pendente:
        return smallButton('Solicitar reembolso', _solicitarReembolso);

      case OrderStatus.andamento:
        return Column(
          children: [
            const SizedBox(height: 8),
            smallButton('Solicitar reembolso', _solicitarReembolso),
          ],
        );

      case OrderStatus.reembolsoSolicitado:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Column(
                children: [
                  const Icon(Icons.hourglass_empty, color: Colors.orange, size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    '⏳ Reembolso em Análise',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Aguarde a resposta do vendedor',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (order.refundReason != null) ...[
              const SizedBox(height: 8),
              Text(
                order.refundReason!.startsWith('Negado:') 
                    ? '❌ ${order.refundReason}'
                    : '📝 Motivo enviado: ${order.refundReason}',
                style: TextStyle(
                  color: order.refundReason!.startsWith('Negado:') 
                      ? Colors.red 
                      : Colors.grey,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );

      case OrderStatus.entregue:
        if (!order.deliveryConfirmed) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.local_shipping, color: Colors.green, size: 32),
                    const SizedBox(height: 8),
                    const Text(
                      'Pedido marcado como entregue pelo vendedor',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Você recebeu o pedido?',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              fullButton('✓ Confirmar Recebimento', () async {
                await OrderService().confirmarEntrega(_currentOrder);
                
                // Recarregar pedido atualizado
                await _refreshOrderDetails();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Entrega confirmada com sucesso!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }),
              const SizedBox(height: 8),
              smallButton('Solicitar reembolso', _solicitarReembolso),
            ],
          );
        } else {
          return Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 8),
              const Text(
                'Pedido entregue e confirmado!',
                style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Obrigado pela sua compra!',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          );
        }
    }
  }

  Widget fullButton(String text, VoidCallback action) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(onPressed: action, child: Text(text)),
    );
  }

  Widget smallButton(String text, VoidCallback action) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(onPressed: action, child: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _currentOrder;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Pedido ${order.id}'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : order.items.isEmpty
          ? RefreshIndicator(
              onRefresh: _refreshOrderDetails,
              child: const Center(
                child: Text(
                  'Nenhum item no pedido',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshOrderDetails,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: order.items.length,
                      itemBuilder: (_, index) {
                        final item = order.items[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // CORRIGIDO: Suporta URLs HTTP e assets locais
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: item.image.startsWith('http')
                                    ? Image.network(
                                        item.image,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey[200],
                                            child: const Center(
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.image, color: Colors.grey),
                                          );
                                        },
                                      )
                                    : Image.asset(
                                        item.image,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.image, color: Colors.grey),
                                          );
                                        },
                                      ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Qtd: ${item.quantity}', style: const TextStyle(fontSize: 13)),
                                      if (item.size != null && item.size!.isNotEmpty)
                                        Text('Tam: ${item.size}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      if (item.color != null && item.color!.isNotEmpty)
                                        Text('Cor: ${item.color}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      if (item.age != null && item.age!.isNotEmpty)
                                        Text('Idade: ${item.age}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      if (item.storage != null && item.storage!.isNotEmpty)
                                        Text('Armaz: ${item.storage}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      if (item.pantSize != null && item.pantSize!.isNotEmpty)
                                        Text('Calça: ${item.pantSize}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      if (item.shoeSize != null && item.shoeSize!.isNotEmpty)
                                        Text('Calçado: ${item.shoeSize}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${(item.price * item.quantity).toStringAsFixed(0)} MT',
                                  style: const TextStyle(
                                    color: Colors.deepPurple,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pagamento: ${order.paymentMethod}'),
                      const SizedBox(height: 4),
                      Text('Estado: ${statusLabel(order.status)}'),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total'),
                          Text(
                            '${order.total.toStringAsFixed(0)} MT',
                            style: const TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      buildActionButtons(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
