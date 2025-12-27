enum SellerOrderStatus { novo, processando, enviado, entregue, cancelado, reembolsoSolicitado }

class SellerOrderModel {
  final String id;
  final String sellerId;
  final String productId;
  final String productName;
  final String productImage;
  final double productPrice;
  final int quantity;
  final double total;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  SellerOrderStatus status;
  final DateTime createdAt;
  DateTime? processedAt;
  DateTime? deliveredAt;

  // Opções do produto
  final String? size;
  final String? color;
  final String? age;
  final String? storage;
  final String? pantSize;
  final String? shoeSize;

  // ID do pedido do cliente (para sincronização)
  final String? customerOrderId;
  String? refundReason; // Motivo do reembolso solicitado pelo cliente

  SellerOrderModel({
    required this.id,
    required this.sellerId,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.productPrice,
    required this.quantity,
    required this.total,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.status,
    required this.createdAt,
    this.processedAt,
    this.deliveredAt,
    this.size,
    this.color,
    this.age,
    this.storage,
    this.pantSize,
    this.shoeSize,
    this.customerOrderId,
    this.refundReason,
  });

  String get statusText {
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
}
