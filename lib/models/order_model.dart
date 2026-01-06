import 'package:wampula_vendas/models/cart_item.dart';

enum OrderStatus { pendente, andamento, entregue, reembolsoSolicitado }

// Estado específico do fluxo de reembolso.
// Mantém separado do status geral do pedido para facilitar filtros e exibição.
enum RefundStatus { none, requested, approved, denied }

class OrderModel {
  final String id;
  final List<CartItem> items;
  final double total;
  final String paymentMethod;
  OrderStatus status;
  final DateTime createdAt;
  bool deliveryConfirmed; // Se cliente confirmou recebimento
  String? refundReason; // Motivo do reembolso
  RefundStatus refundStatus;

  OrderModel({
    required this.id,
    required this.items,
    required this.total,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.deliveryConfirmed = false,
    this.refundReason,
    this.refundStatus = RefundStatus.none,
  });
}
