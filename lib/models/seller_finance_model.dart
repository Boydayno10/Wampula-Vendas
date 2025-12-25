enum TransactionType { venda, comissao, saque, reembolso }

class SellerTransaction {
  final String id;
  final String sellerId;
  final TransactionType type;
  final double amount;
  final String description;
  final DateTime createdAt;
  final String? orderId;

  SellerTransaction({
    required this.id,
    required this.sellerId,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
    this.orderId,
  });

  String get typeText {
    switch (type) {
      case TransactionType.venda:
        return 'Venda';
      case TransactionType.comissao:
        return 'Comissão';
      case TransactionType.saque:
        return 'Saque';
      case TransactionType.reembolso:
        return 'Reembolso';
    }
  }

  bool get isCredit => type == TransactionType.venda;
  bool get isDebit => type == TransactionType.comissao || 
                       type == TransactionType.saque || 
                       type == TransactionType.reembolso;
}

class SellerFinanceSummary {
  final double totalSales; // Total de vendas
  final double totalCommission; // Total de comissões pagas
  final double availableBalance; // Saldo disponível
  final double pendingBalance; // Saldo pendente (pedidos não entregues)
  final int totalOrders; // Total de pedidos
  final int deliveredOrders; // Pedidos entregues

  SellerFinanceSummary({
    required this.totalSales,
    required this.totalCommission,
    required this.availableBalance,
    required this.pendingBalance,
    required this.totalOrders,
    required this.deliveredOrders,
  });

  double get netRevenue => totalSales - totalCommission;
}
