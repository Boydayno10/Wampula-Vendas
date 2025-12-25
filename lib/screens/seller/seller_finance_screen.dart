import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/seller_product_service.dart';
import '../../models/seller_finance_model.dart';

class SellerFinanceScreen extends StatefulWidget {
  const SellerFinanceScreen({super.key});

  @override
  State<SellerFinanceScreen> createState() => _SellerFinanceScreenState();
}

class _SellerFinanceScreenState extends State<SellerFinanceScreen> {
  Future<void> _refreshFinances() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {});
  }

  Future<void> _requestWithdrawal() async {
    final sellerId = AuthService.currentUser.id;
    final finance = await SellerProductService.getFinanceSummary(sellerId);

    if (finance.availableBalance <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não há saldo disponível para saque')),
        );
      }
      return;
    }

    final amountCtrl = TextEditingController();
    
    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Solicitar Saque'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo disponível: ${finance.availableBalance.toStringAsFixed(2)} MT',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Valor do Saque (MT)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'O valor será transferido para sua conta em até 2 dias úteis.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0 || amount > finance.availableBalance) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Valor inválido')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (result == true) {
      final amount = double.parse(amountCtrl.text);
      await SellerProductService.requestWithdrawal(sellerId, amount);
      setState(() {});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitação de saque realizada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Color _getTransactionColor(SellerTransaction transaction) {
    return transaction.isCredit ? Colors.green : Colors.red;
  }

  IconData _getTransactionIcon(SellerTransaction transaction) {
    switch (transaction.type) {
      case TransactionType.venda:
        return Icons.arrow_downward;
      case TransactionType.comissao:
        return Icons.arrow_upward;
      case TransactionType.saque:
        return Icons.account_balance_wallet;
      case TransactionType.reembolso:
        return Icons.undo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sellerId = AuthService.currentUser.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanças'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Como funciona?'),
                  content: const Text(
                    'A plataforma cobra uma comissão de 10% sobre cada venda realizada. '
                    'O saldo disponível pode ser sacado a qualquer momento e será '
                    'transferido para sua conta em até 2 dias úteis.\n\n'
                    'Vendas pendentes serão creditadas após a confirmação da entrega.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Entendi'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: Future.wait([
          SellerProductService.getFinanceSummary(sellerId),
          SellerProductService.getTransactionsBySeller(sellerId),
        ]).then((results) => {
          'finance': results[0],
          'transactions': results[1],
        }),
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

          final finance = snapshot.data!['finance'] as SellerFinanceSummary;
          final transactions = snapshot.data!['transactions'] as List<SellerTransaction>;

          return RefreshIndicator(
            onRefresh: _refreshFinances,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Card de Saldo Principal
                Card(
              color: Colors.deepPurple,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.account_balance_wallet, color: Colors.white70),
                        SizedBox(width: 8),
                        Text(
                          'Saldo Disponível',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${finance.availableBalance.toStringAsFixed(2)} MT',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: finance.availableBalance > 0 ? _requestWithdrawal : null,
                        icon: const Icon(Icons.account_balance),
                        label: const Text('Solicitar Saque'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.deepPurple,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Cards de Resumo
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.trending_up, color: Colors.green, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            '${finance.totalSales.toStringAsFixed(0)} MT',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Vendas Totais',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.hourglass_empty, color: Colors.orange, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            '${finance.pendingBalance.toStringAsFixed(0)} MT',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Pendente',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Card de Estatísticas
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resumo Detalhado',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFinanceRow(
                      Icons.shopping_cart,
                      'Total de Pedidos',
                      '${finance.totalOrders}',
                    ),
                    _buildFinanceRow(
                      Icons.check_circle,
                      'Pedidos Entregues',
                      '${finance.deliveredOrders}',
                    ),
                    _buildFinanceRow(
                      Icons.attach_money,
                      'Vendas Brutas',
                      '${finance.totalSales.toStringAsFixed(2)} MT',
                      color: Colors.green,
                    ),
                    _buildFinanceRow(
                      Icons.remove_circle,
                      'Comissões (-10%)',
                      '${finance.totalCommission.toStringAsFixed(2)} MT',
                      color: Colors.red,
                    ),
                    const Divider(height: 24),
                    _buildFinanceRow(
                      Icons.account_balance_wallet,
                      'Receita Líquida',
                      '${finance.netRevenue.toStringAsFixed(2)} MT',
                      color: Colors.deepPurple,
                      bold: true,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Extrato de Transações
            Row(
              children: [
                const Text(
                  'Extrato de Transações',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    // TODO: Implementar filtros de data
                  },
                  child: const Text('Filtrar'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (transactions.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'Nenhuma transação ainda',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...transactions.map((transaction) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getTransactionColor(transaction).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getTransactionIcon(transaction),
                        color: _getTransactionColor(transaction),
                      ),
                    ),
                    title: Text(transaction.typeText),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(transaction.description, style: const TextStyle(fontSize: 12)),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(transaction.createdAt),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    trailing: Text(
                      '${transaction.isCredit ? '+' : '-'}${transaction.amount.toStringAsFixed(2)} MT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _getTransactionColor(transaction),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    ),
    );
  }

  Widget _buildFinanceRow(IconData icon, String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
