import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/seller_product_service.dart';
import '../../models/seller_order_model.dart';

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  SellerOrderStatus? _filterStatus;
  bool _isSelectionMode = false;
  Set<String> _selectedOrderIds = {};

  Future<void> _refreshOrders() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {});
  }

  Future<List<SellerOrderModel>> _getFilteredOrders() async {
    final sellerId = AuthService.currentUser.id;
    var orders = await SellerProductService.getOrdersBySeller(sellerId);

    if (_filterStatus != null) {
      orders = orders.where((o) => o.status == _filterStatus).toList();
    }

    // Ordenar por data (mais recentes primeiro)
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return orders;
  }

  Future<void> _updateOrderStatus(SellerOrderModel order, SellerOrderStatus newStatus) async {
    try {
      print('🔄 Atualizando status do pedido ${order.id} para ${newStatus.name}');
      
      await SellerProductService.updateOrderStatus(order.id, newStatus);
      
      print('✅ Status atualizado com sucesso');
      
      // Recarregar lista de pedidos
      if (mounted) {
        setState(() {});
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status atualizado para: ${_getStatusName(newStatus)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Erro ao atualizar status: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getStatusName(SellerOrderStatus status) {
    switch (status) {
      case SellerOrderStatus.novo:
        return 'Novo';
      case SellerOrderStatus.processando:
        return 'Processando';
      case SellerOrderStatus.enviado:
        return 'Enviado';
      case SellerOrderStatus.entregue:
        return 'Entregue';
      case SellerOrderStatus.cancelado:
        return 'Cancelado';
      case SellerOrderStatus.reembolsoSolicitado:
        return 'Reembolso Solicitado';
    }
  }

  Color _getStatusColor(SellerOrderStatus status) {
    switch (status) {
      case SellerOrderStatus.novo:
        return Colors.blue;
      case SellerOrderStatus.processando:
        return Colors.orange;
      case SellerOrderStatus.enviado:
        return Colors.purple;
      case SellerOrderStatus.entregue:
        return Colors.green;
      case SellerOrderStatus.cancelado:
        return Colors.red;
      case SellerOrderStatus.reembolsoSolicitado:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(SellerOrderStatus status) {
    switch (status) {
      case SellerOrderStatus.novo:
        return Icons.new_releases;
      case SellerOrderStatus.processando:
        return Icons.loop;
      case SellerOrderStatus.enviado:
        return Icons.local_shipping;
      case SellerOrderStatus.entregue:
        return Icons.check_circle;
      case SellerOrderStatus.cancelado:
        return Icons.cancel;
      case SellerOrderStatus.reembolsoSolicitado:
        return Icons.money_off;
    }
  }

  Future<void> _deleteOrder(SellerOrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja realmente excluir o pedido #${order.id}?\n\nEsta ação não pode ser desfeita e removerá o pedido tanto para o vendedor quanto para o cliente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      print('🗑️ Deletando pedido: ${order.id}');
      
      await SellerProductService.deleteOrder(order.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido excluído com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Recarregar lista
        setState(() {});
      }
    } catch (e) {
      print('❌ Erro ao deletar pedido: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao deletar pedido: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showApproveRefundDialog(SellerOrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('✅ Aprovar Reembolso'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pedido: #${order.id}'),
            Text('Valor: ${order.total.toStringAsFixed(2)} MT'),
            const SizedBox(height: 8),
            if (order.refundReason != null) ...[
              const Text('Motivo do cliente:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(order.refundReason!, style: const TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 8),
            ],
            const Text(
              '⚠️ Ao aprovar, o valor será deduzido do seu saldo e devolvido ao cliente.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Aprovar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SellerProductService.approveRefund(order.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Reembolso aprovado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao aprovar reembolso: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showDenyRefundDialog(SellerOrderModel order) async {
    final TextEditingController reasonController = TextEditingController();
    
    final String? reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('❌ Negar Reembolso'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pedido: #${order.id}'),
            const SizedBox(height: 16),
            if (order.refundReason != null) ...[
              const Text('Motivo do cliente:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(order.refundReason!, style: const TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
            ],
            const Text('Informe o motivo da negação:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Ex: Produto já foi entregue e está em perfeitas condições',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Por favor, informe um motivo')),
                );
                return;
              }
              Navigator.pop(ctx, reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Negar'),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    try {
      await SellerProductService.denyRefund(order.id, reason);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Reembolso negado'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao negar reembolso: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showOrderDetails(SellerOrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            Text(
              'Pedido #${order.id}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(order.status).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getStatusIcon(order.status), size: 16, color: _getStatusColor(order.status)),
                  const SizedBox(width: 6),
                  Text(
                    order.statusText,
                    style: TextStyle(
                      color: _getStatusColor(order.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 32),
            
            // Produto
            const Text('Produto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: order.productImage.startsWith('http')
                      ? Image.network(
                          order.productImage,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image_not_supported, size: 40),
                          ),
                        )
                      : Image.asset(
                          order.productImage,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image_not_supported, size: 40),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${order.productPrice.toStringAsFixed(2)} MT x ${order.quantity}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (_hasOptions(order)) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Opções Selecionadas:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (order.size != null && order.size!.isNotEmpty) 
                              _buildOptionChip('Tamanho: ${order.size}'),
                            if (order.color != null && order.color!.isNotEmpty) 
                              _buildOptionChip('Cor: ${order.color}'),
                            if (order.storage != null && order.storage!.isNotEmpty) 
                              _buildOptionChip('Armazenamento: ${order.storage}'),
                            if (order.age != null && order.age!.isNotEmpty) 
                              _buildOptionChip('Idade: ${order.age}'),
                            if (order.pantSize != null && order.pantSize!.isNotEmpty) 
                              _buildOptionChip('Calça: ${order.pantSize}'),
                            if (order.shoeSize != null && order.shoeSize!.isNotEmpty) 
                              _buildOptionChip('Calçado: ${order.shoeSize}'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            const Divider(height: 32),
            
            // Cliente
            const Text('Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.person, 'Nome', order.customerName),
            _buildInfoRow(Icons.phone, 'Telefone', order.customerPhone),
            _buildInfoRow(Icons.location_on, 'Endereço', order.deliveryAddress),
            
            // Mostrar motivo do reembolso se existir
            if ((order.status == SellerOrderStatus.reembolsoSolicitado || order.status == SellerOrderStatus.cancelado) && order.refundReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Motivo do Reembolso:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          Text(
                            order.refundReason!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const Divider(height: 32),
            
            // Valores
            const Text('Valores', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.shopping_cart, 'Subtotal', '${order.total.toStringAsFixed(2)} MT'),
            _buildInfoRow(Icons.local_offer, 'Comissão (10%)', '${(order.total * 0.1).toStringAsFixed(2)} MT', color: Colors.red),
            _buildInfoRow(Icons.account_balance_wallet, 'Você Recebe', '${(order.total * 0.9).toStringAsFixed(2)} MT', color: Colors.green, bold: true),
            
            const Divider(height: 32),
            
            // Datas
            const Text('Informações', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.calendar_today, 'Data do Pedido', DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt)),
            if (order.processedAt != null)
              _buildInfoRow(Icons.check, 'Processado em', DateFormat('dd/MM/yyyy HH:mm').format(order.processedAt!)),
            if (order.deliveredAt != null)
              _buildInfoRow(Icons.check_circle, 'Entregue em', DateFormat('dd/MM/yyyy HH:mm').format(order.deliveredAt!)),
            
            const SizedBox(height: 24),
            
            // Ações para Reembolso
            if (order.status == SellerOrderStatus.reembolsoSolicitado) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.orange, size: 24),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '⚠️ Cliente solicitou reembolso',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Você precisa decidir se aprova ou nega o reembolso:',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Botão Aprovar Reembolso
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showApproveRefundDialog(order);
                },
                icon: const Icon(Icons.check_circle),
                label: const Text('✓ Aprovar Reembolso'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 8),
              
              // Botão Negar Reembolso
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showDenyRefundDialog(order);
                },
                icon: const Icon(Icons.cancel),
                label: const Text('✗ Negar Reembolso'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
            
            // Ações Normais
            if (order.status != SellerOrderStatus.entregue && order.status != SellerOrderStatus.cancelado && order.status != SellerOrderStatus.reembolsoSolicitado) ...[
              const Text('Alterar Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              
              if (order.status == SellerOrderStatus.novo)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateOrderStatus(order, SellerOrderStatus.processando);
                  },
                  icon: const Icon(Icons.loop),
                  label: const Text('Iniciar Processamento'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              
              if (order.status == SellerOrderStatus.processando) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateOrderStatus(order, SellerOrderStatus.enviado);
                  },
                  icon: const Icon(Icons.local_shipping),
                  label: const Text('Marcar como Enviado'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              
              if (order.status == SellerOrderStatus.enviado)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateOrderStatus(order, SellerOrderStatus.entregue);
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Confirmar Entrega'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              
              const SizedBox(height: 8),
              
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _updateOrderStatus(order, SellerOrderStatus.cancelado);
                },
                icon: const Icon(Icons.cancel),
                label: const Text('Cancelar Pedido'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
            
            // Botão de Deletar (sempre visível)
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _deleteOrder(order);
              },
              icon: const Icon(Icons.delete_forever),
              label: const Text('Excluir Pedido'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Verificar se o pedido tem opções selecionadas
  bool _hasOptions(SellerOrderModel order) {
    return (order.size != null && order.size!.isNotEmpty) ||
           (order.color != null && order.color!.isNotEmpty) ||
           (order.storage != null && order.storage!.isNotEmpty) ||
           (order.age != null && order.age!.isNotEmpty) ||
           (order.pantSize != null && order.pantSize!.isNotEmpty) ||
           (order.shoeSize != null && order.shoeSize!.isNotEmpty);
  }

  Widget _buildOptionChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: Colors.deepPurple.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _deleteSelectedOrders() async {
    if (_selectedOrderIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão em Lote'),
        content: Text('Deseja realmente excluir ${_selectedOrderIds.length} pedido(s) selecionado(s)?\n\nEsta ação não pode ser desfeita e removerá os pedidos tanto para o vendedor quanto para os clientes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir Todos'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      int successCount = 0;
      int errorCount = 0;

      for (String orderId in _selectedOrderIds) {
        try {
          await SellerProductService.deleteOrder(orderId);
          successCount++;
        } catch (e) {
          errorCount++;
          print('❌ Erro ao deletar pedido $orderId: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorCount == 0
                  ? '✅ $successCount pedido(s) excluído(s) com sucesso!'
                  : '⚠️ $successCount pedido(s) excluído(s), $errorCount erro(s)',
            ),
            backgroundColor: errorCount == 0 ? Colors.green : Colors.orange,
          ),
        );

        setState(() {
          _selectedOrderIds.clear();
          _isSelectionMode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao excluir pedidos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleSelection(String orderId) {
    setState(() {
      if (_selectedOrderIds.contains(orderId)) {
        _selectedOrderIds.remove(orderId);
        if (_selectedOrderIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedOrderIds.add(orderId);
      }
    });
  }

  void _toggleSelectAll(List<SellerOrderModel> orders) {
    setState(() {
      if (_selectedOrderIds.length == orders.length) {
        _selectedOrderIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedOrderIds = orders.map((o) => o.id).toSet();
        _isSelectionMode = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode 
            ? '${_selectedOrderIds.length} selecionado(s)'
            : 'Pedidos Recebidos'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedOrderIds.clear();
                  });
                },
              )
            : null,
        actions: [
          PopupMenuButton<SellerOrderStatus?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _filterStatus = value);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('Todos')),
              const PopupMenuItem(value: SellerOrderStatus.novo, child: Text('Novos')),
              const PopupMenuItem(value: SellerOrderStatus.processando, child: Text('Processando')),
              const PopupMenuItem(value: SellerOrderStatus.enviado, child: Text('Enviados')),
              const PopupMenuItem(value: SellerOrderStatus.entregue, child: Text('Entregues')),
              const PopupMenuItem(value: SellerOrderStatus.reembolsoSolicitado, child: Text('Reembolsos Solicitados')),
              const PopupMenuItem(value: SellerOrderStatus.cancelado, child: Text('Cancelados')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<SellerOrderModel>>(
        future: _getFilteredOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Erro: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Tentar Novamente'),
                  ),
                ],
              ),
            );
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshOrders,
              child: ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Nenhum pedido encontrado',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshOrders,
            child: Column(
              children: [
                // Barra de ações em lote
                if (!_isSelectionMode)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.grey.shade100,
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Toque e segure para selecionar',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _toggleSelectAll(orders),
                          icon: const Icon(Icons.checklist, size: 18),
                          label: const Text('Selecionar Todos'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Lista de pedidos
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    itemBuilder: (_, i) {
                      final order = orders[i];
                      final isSelected = _selectedOrderIds.contains(order.id);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: isSelected ? Colors.deepPurple.shade50 : null,
                        elevation: isSelected ? 4 : 1,
                        child: InkWell(
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelection(order.id);
                            } else {
                              _showOrderDetails(order);
                            }
                          },
                          onLongPress: () {
                            setState(() {
                              _isSelectionMode = true;
                              _toggleSelection(order.id);
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Checkbox de seleção
                                if (_isSelectionMode)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Checkbox(
                                      value: isSelected,
                                      onChanged: (value) => _toggleSelection(order.id),
                                      activeColor: Colors.deepPurple,
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(order.status).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_getStatusIcon(order.status), size: 14, color: _getStatusColor(order.status)),
                                      const SizedBox(width: 4),
                                      Text(
                                        order.statusText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _getStatusColor(order.status),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '#${order.id}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Ícone de deletar (somente se não estiver em modo seleção)
                                if (!_isSelectionMode)
                                  InkWell(
                                    onTap: () => _deleteOrder(order),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Imagem do produto (80x80)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: order.productImage.startsWith('http')
                                      ? Image.network(
                                          order.productImage,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 80,
                                            height: 80,
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.image_not_supported, size: 40),
                                          ),
                                        )
                                      : Image.asset(
                                          order.productImage,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 80,
                                            height: 80,
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.image_not_supported, size: 40),
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order.productName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      // Mostrar APENAS opções selecionadas (não vazias)
                                      if (_hasOptions(order))
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            if (order.size != null && order.size!.isNotEmpty)
                                              _buildOptionChip('Tamanho: ${order.size!}'),
                                            if (order.color != null && order.color!.isNotEmpty)
                                              _buildOptionChip('Cor: ${order.color!}'),
                                            if (order.storage != null && order.storage!.isNotEmpty)
                                              _buildOptionChip('Armazenamento: ${order.storage!}'),
                                            if (order.age != null && order.age!.isNotEmpty)
                                              _buildOptionChip('Idade: ${order.age!}'),
                                            if (order.pantSize != null && order.pantSize!.isNotEmpty)
                                              _buildOptionChip('Calça: ${order.pantSize!}'),
                                            if (order.shoeSize != null && order.shoeSize!.isNotEmpty)
                                              _buildOptionChip('Calçado: ${order.shoeSize!}'),
                                          ],
                                        ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Qtd: ${order.quantity}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            // Informações do cliente
                            Row(
                              children: [
                                Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    order.customerName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  order.customerPhone,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt),
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                const Spacer(),
                                Text(
                                  '${order.total.toStringAsFixed(2)} MT',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _isSelectionMode && _selectedOrderIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _deleteSelectedOrders,
              backgroundColor: Colors.red,
              icon: const Icon(Icons.delete),
              label: Text('Excluir (${_selectedOrderIds.length})'),
            )
          : null,
    );
  }
}
