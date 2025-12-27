import '../models/order_model.dart';
import '../models/product_model.dart';
import '../services/cart_service.dart';
import '../models/cart_item.dart';
import '../services/seller_product_service.dart';
import '../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderService {
  static final _supabase = Supabase.instance.client;
  static final OrderService _instance = OrderService._internal();
  OrderService._internal();
  factory OrderService() => _instance;

  final List<OrderModel> _orders = [];
  List<OrderModel> get orders => _orders;

  // Carregar pedidos do usuário do Supabase
  Future<List<OrderModel>> loadOrders() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];
      
      final response = await _supabase
          .from('orders')
          .select('*, order_items(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      _orders.clear();
      for (var orderJson in response as List) {
        final order = _orderFromJson(orderJson);
        _orders.add(order);
      }
      
      return _orders;
    } catch (e) {
      print('Erro ao carregar pedidos: $e');
      return _orders;
    }
  }

  // Buscar pedido individual atualizado do banco de dados
  Future<OrderModel?> getOrderById(String orderId) async {
    try {
      print('🔍 Buscando pedido atualizado: $orderId');
      
      final response = await _supabase
          .from('orders')
          .select('*, order_items(*)')
          .eq('id', orderId)
          .maybeSingle();
      
      if (response == null) {
        print('⚠️ Pedido não encontrado: $orderId');
        return null;
      }
      
      final order = _orderFromJson(response);
      print('✅ Pedido carregado - Status: ${order.status.name}');
      
      // Atualizar na lista local também
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index >= 0) {
        _orders[index] = order;
      }
      
      return order;
    } catch (e) {
      print('❌ Erro ao buscar pedido: $e');
      return null;
    }
  }

  Future<OrderModel> createOrder() async {
    final selected = CartService.items.where((i) => i.selected).toList();
    
    if (selected.isEmpty) {
      throw StateError('Nenhum item selecionado para criar pedido');
    }

    OrderModel? firstOrder; // retorna o primeiro para compatibilidade
    final userId = _supabase.auth.currentUser?.id;
    
    if (userId == null) {
      throw StateError('Usuário não autenticado');
    }

    for (final item in selected) {
      // Gerar ID sequencial usando função RPC do Supabase
      final orderId = await SellerProductService.getNextOrderId();
      
      try {
        // Criar pedido no Supabase
        await _supabase.from('orders').insert({
          'id': orderId,
          'user_id': userId,
          'total': item.price * item.quantity,
          'payment_method': 'M-Pesa',
          'status': OrderStatus.pendente.name,
        });
        
        // Criar item do pedido
        await _supabase.from('order_items').insert({
          'order_id': orderId,
          'product_id': item.id,
          'name': item.name,
          'image': item.image,
          'price': item.price,
          'quantity': item.quantity,
          'size': item.size,
          'color': item.color,
          'age': item.age,
          'storage': item.storage,
          'pant_size': item.pantSize,
          'shoe_size': item.shoeSize,
          'selected': true,
        });
        
        final order = OrderModel(
          id: orderId,
          items: [item],
          total: item.price * item.quantity,
          paymentMethod: 'M-Pesa',
          status: OrderStatus.pendente,
          createdAt: DateTime.now(),
        );

        _orders.add(order);

        // 🛒 CRIAR PEDIDO PARA O VENDEDOR POR ITEM
        await _createSellerOrdersFromCart([item], order.id);

        firstOrder ??= order;
      } catch (e) {
        print('Erro ao criar pedido: $e');
        throw e;
      }
    }

    CartService.removeSelected();

    // Mantém assinatura anterior, devolvendo o primeiro pedido criado
    return firstOrder!;
  }

  Future<void> setAndamento(OrderModel order) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': OrderStatus.andamento.name})
          .eq('id', order.id);
      
      order.status = OrderStatus.andamento;
    } catch (e) {
      print('Erro ao atualizar status: $e');
    }
  }

  Future<void> setEntregue(OrderModel order) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': OrderStatus.entregue.name})
          .eq('id', order.id);
      
      order.status = OrderStatus.entregue;
    } catch (e) {
      print('Erro ao atualizar status: $e');
    }
  }
  
  Future<void> confirmarEntrega(OrderModel order) async {
    try {
      print('✅ Cliente confirmando entrega do pedido: ${order.id}');
      
      await _supabase
          .from('orders')
          .update({
            'delivery_confirmed': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', order.id);
      
      order.deliveryConfirmed = true;
      
      // Notificar vendedor que o cliente confirmou o recebimento
      await _notifySellerDeliveryConfirmed(order);
      
      print('✅ Entrega confirmada e vendedor notificado');
    } catch (e) {
      print('❌ Erro ao confirmar entrega: $e');
    }
  }

  Future<void> _notifySellerDeliveryConfirmed(OrderModel order) async {
    try {
      print('📬 Notificando vendedor sobre entrega confirmada');
      print('📋 Pedido ID: ${order.id}');
      
      // Buscar seller_id através do seller_order - usar o mesmo ID
      final sellerOrderResponse = await _supabase
          .from('seller_orders')
          .select('seller_id')
          .eq('id', order.id)
          .maybeSingle();
      
      if (sellerOrderResponse == null) {
        print('⚠️ Pedido do vendedor não encontrado para ID: ${order.id}');
        return;
      }
      
      final sellerId = sellerOrderResponse['seller_id'];
      print('✅ Vendedor encontrado: $sellerId');
      
      // Criar notificação para o vendedor
      await _supabase.from('notifications').insert({
        'user_id': sellerId,
        'title': 'Entrega Confirmada! 🎉',
        'message': 'O cliente confirmou o recebimento do pedido #${order.id}',
        'type': 'pedido',
        'related_id': order.id,
      });
      
      print('📬 Notificação enviada ao vendedor com sucesso');
    } catch (e) {
      print('❌ Erro ao notificar vendedor: $e');
      throw e;
    }
  }

  Future<void> solicitarReembolso(OrderModel order, String reason) async {
    try {
      print('🔄 Cliente solicitando reembolso para pedido: ${order.id}');
      print('📝 Motivo: $reason');
      
      await _supabase
          .from('orders')
          .update({
            'status': OrderStatus.reembolsoSolicitado.name,
            'refund_reason': reason,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', order.id);
      
      order.status = OrderStatus.reembolsoSolicitado;
      order.refundReason = reason;
      
      print('✅ Reembolso registrado no pedido do cliente');
      
      // 🔥 SINCRONIZAR MOTIVO COM PEDIDO DO VENDEDOR
      await SellerProductService.syncRefundReasonFromCustomer(order.id, reason);
      
      print('✅ Motivo sincronizado com vendedor');
    } catch (e) {
      print('❌ Erro ao solicitar reembolso: $e');
    }
  }
  
  // 🔥 ATUALIZAR STATUS POR ID (CHAMADO PELO VENDEDOR)
  Future<void> updateStatusById(String orderId, OrderStatus newStatus) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': newStatus.name})
          .eq('id', orderId);
      
      final order = _orders.firstWhere((o) => o.id == orderId);
      order.status = newStatus;
    } catch (e) {
      print('Erro ao atualizar status: $e');
    }
  }

  // Cria pedido sem usar o carrinho (compra direta)
  Future<OrderModel> createOrderFromDirectPurchase({
    required ProductModel product,
    required int quantity,
    String? size,
    String? color,
    String? age,
    String? storage,
    String? pantSize,
    String? shoeSize,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    
    if (userId == null) {
      throw StateError('Usuário não autenticado');
    }
    
    final items = [
      CartItem(
        id: product.id,
        name: product.name,
        image: product.image,
        price: product.price,
        quantity: quantity,
        selected: true,
        size: size,
        color: color,
        age: age,
        storage: storage,
        pantSize: pantSize,
        shoeSize: shoeSize,
      ),
    ];

    final total = product.price * quantity;
    
    // Gerar ID sequencial usando função RPC do Supabase
    final orderId = await SellerProductService.getNextOrderId();

    try {
      // Criar pedido no Supabase
      await _supabase.from('orders').insert({
        'id': orderId,
        'user_id': userId,
        'total': total,
        'payment_method': 'M-Pesa',
        'status': OrderStatus.pendente.name,
      });
      
      // Criar item do pedido
      await _supabase.from('order_items').insert({
        'order_id': orderId,
        'product_id': product.id,
        'name': product.name,
        'image': product.image,
        'price': product.price,
        'quantity': quantity,
        'size': size,
        'color': color,
        'age': age,
        'storage': storage,
        'pant_size': pantSize,
        'shoe_size': shoeSize,
        'selected': true,
      });
      
      final order = OrderModel(
        id: orderId,
        items: items,
        total: total,
        paymentMethod: 'M-Pesa',
        status: OrderStatus.pendente,
        createdAt: DateTime.now(),
      );

      _orders.add(order);

      // 🛒 CRIAR PEDIDO PARA O VENDEDOR
      await _createSellerOrderFromProduct(product, quantity, size, color, age, storage, pantSize, shoeSize, order.id);

      return order;
    } catch (e) {
      print('Erro ao criar pedido: $e');
      throw e;
    }
  }

  // 🔥 MÉTODO PARA CRIAR PEDIDOS DO VENDEDOR A PARTIR DO CARRINHO
  Future<void> _createSellerOrdersFromCart(List<CartItem> items, String customerOrderId) async {
    final user = AuthService.currentUser;
    final customerAddress = 'Nampula, ${user.bairro}';
    
    for (final item in items) {
      // Buscar produto do vendedor pelo ID
      final sellerProduct = await SellerProductService.getProductById(item.id);
      if (sellerProduct != null) {
        // Criar pedido para o vendedor
        await SellerProductService.createOrder(
          productId: sellerProduct.id,
          quantity: item.quantity,
          customerName: user.name,
          customerPhone: user.phone,
          customerAddress: customerAddress,
          size: item.size,
          color: item.color,
          age: item.age,
          storage: item.storage,
          pantSize: item.pantSize,
          shoeSize: item.shoeSize,
          customerOrderId: customerOrderId,
        );
      }
    }
  }

  // 🔥 MÉTODO PARA CRIAR PEDIDO DO VENDEDOR A PARTIR DE COMPRA DIRETA
  Future<void> _createSellerOrderFromProduct(
    ProductModel product,
    int quantity,
    String? size,
    String? color,
    String? age,
    String? storage,
    String? pantSize,
    String? shoeSize,
    String customerOrderId,
  ) async {
    final user = AuthService.currentUser;
    final customerAddress = 'Nampula, ${user.bairro}';
    
    // Buscar produto do vendedor pelo ID
    final sellerProduct = await SellerProductService.getProductById(product.id);
    if (sellerProduct != null) {
      // Criar pedido para o vendedor
      await SellerProductService.createOrder(
        productId: sellerProduct.id,
        quantity: quantity,
        customerName: user.name,
        customerPhone: user.phone,
        customerAddress: customerAddress,
        size: size,
        color: color,
        age: age,
        storage: storage,
        pantSize: pantSize,
        shoeSize: shoeSize,
        customerOrderId: customerOrderId,
      );
    }
  }

  // Método auxiliar para converter JSON do Supabase
  OrderModel _orderFromJson(Map<String, dynamic> json) {
    final items = (json['order_items'] as List?)
        ?.map((itemJson) => CartItem(
              id: itemJson['product_id'] ?? '',
              name: itemJson['name'] ?? '',
              image: itemJson['image'] ?? '',
              price: (itemJson['price'] ?? 0).toDouble(),
              quantity: itemJson['quantity'] ?? 1,
              selected: itemJson['selected'] ?? true,
              size: itemJson['size'],
              color: itemJson['color'],
              age: itemJson['age'],
              storage: itemJson['storage'],
              pantSize: itemJson['pant_size'],
              shoeSize: itemJson['shoe_size'],
            ))
        .toList() ?? [];

    return OrderModel(
      id: json['id'],
      items: items,
      total: (json['total'] ?? 0).toDouble(),
      paymentMethod: json['payment_method'] ?? 'M-Pesa',
      status: OrderStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => OrderStatus.pendente,
      ),
      createdAt: DateTime.parse(json['created_at']),
      deliveryConfirmed: json['delivery_confirmed'] ?? false,
      refundReason: json['refund_reason'],
    );
  }
}

// Método statusLabel centralizado para evitar duplicação.
String statusLabel(OrderStatus status) {
  switch (status) {
    case OrderStatus.pendente:
      return 'Pendente';
    case OrderStatus.andamento:
      return 'Em andamento';
    case OrderStatus.entregue:
      return 'Entregue';
    case OrderStatus.reembolsoSolicitado:
      return 'Reembolso solicitado';
  }
}
