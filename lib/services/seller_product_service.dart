import '../models/product_model.dart';
import '../models/seller_product_model.dart';
import '../models/seller_order_model.dart';
import '../models/seller_finance_model.dart';
import '../models/order_model.dart';
import 'order_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellerProductService {
  static final _supabase = Supabase.instance.client;
  static final List<SellerProductModel> _items = [];
  static final List<SellerOrderModel> _orders = [];

  // CRUD de Produtos
  static Future<List<SellerProductModel>> bySeller(String sellerId) async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((json) => _productFromJson(json))
          .toList();
    } catch (e) {
      print('Erro ao buscar produtos: $e');
      return [];
    }
  }

  // Obter produtos do vendedor e convertê-los para ProductModel
  static Future<List<ProductModel>> getProductsBySeller(String sellerId) async {
    final products = await bySeller(sellerId);
    return products
        .where((p) => p.active)
        .map((p) => p.toProductModel())
        .toList();
  }

  static List<SellerProductModel> get allProducts => _items;

  static Future<void> add(SellerProductModel p) async {
    try {
      final data = _productToJson(p);
      await _supabase.from('products').insert(data);
      _items.add(p);
    } catch (e) {
      print('Erro ao adicionar produto: $e');
      throw e;
    }
  }

  static Future<void> update(SellerProductModel updated) async {
    try {
      print('🔄 Atualizando produto: ${updated.name}');
      print('💵 old_price sendo enviado: ${updated.oldPrice}');
      
      final data = _productToJson(updated);
      
      print('📦 Dados enviados para Supabase: $data');
      
      await _supabase
          .from('products')
          .update(data)
          .eq('id', updated.id);
      
      final index = _items.indexWhere((p) => p.id == updated.id);
      if (index >= 0) {
        _items[index] = updated;
      }
      
      print('✅ Produto atualizado com sucesso!');
    } catch (e) {
      print('❌ Erro ao atualizar produto: $e');
      throw e;
    }
  }

  static Future<void> remove(String id) async {
    try {
      await _supabase
          .from('products')
          .delete()
          .eq('id', id);
      
      _items.removeWhere((p) => p.id == id);
    } catch (e) {
      print('Erro ao remover produto: $e');
      throw e;
    }
  }

  static Future<SellerProductModel?> getById(String id) async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('id', id)
          .single();
      
      return _productFromJson(response);
    } catch (e) {
      print('Erro ao buscar produto: $e');
      return null;
    }
  }

  // Alias para compatibilidade
  static Future<SellerProductModel?> getProductById(String id) => getById(id);

  // Atualizar nome da loja em todos os produtos do vendedor
  static Future<void> updateSellerStoreName(String sellerId, String newStoreName) async {
    try {
      await _supabase
          .from('products')
          .update({'seller_store_name': newStoreName})
          .eq('seller_id', sellerId);
      
      for (var product in _items.where((p) => p.sellerId == sellerId)) {
        product.sellerStoreName = newStoreName;
      }
    } catch (e) {
      print('Erro ao atualizar nome da loja: $e');
    }
  }

  // Converte produtos do seller para ProductModel (para exibir na Home)
  static Future<List<ProductModel>> getProductModels() async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('active', true)
          .gt('stock', 0)
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((json) => _productFromJson(json).toProductModel())
          .toList();
    } catch (e) {
      print('Erro ao buscar produtos: $e');
      return [];
    }
  }

  // ===== GERAÇÃO DE IDs SEQUENCIAIS =====
  static Future<String> getNextOrderId() async {
    try {
      print('🔢 Gerando próximo ID de pedido...');
      
      final result = await _supabase.rpc('get_next_order_id');
      
      if (result != null && result is String) {
        print('✅ ID gerado: $result');
        return result;
      }
      
      // Fallback: gerar ID baseado em timestamp se RPC falhar
      final fallbackId = 'WP-${DateTime.now().millisecondsSinceEpoch}';
      print('⚠️ Usando ID fallback: $fallbackId');
      return fallbackId;
    } catch (e) {
      print('❌ Erro ao gerar ID: $e');
      // Fallback: gerar ID baseado em timestamp
      final fallbackId = 'WP-${DateTime.now().millisecondsSinceEpoch}';
      print('⚠️ Usando ID fallback após erro: $fallbackId');
      return fallbackId;
    }
  }

  // ===== PEDIDOS =====
  static Future<List<SellerOrderModel>> getOrdersBySeller(String sellerId) async {
    try {
      print('🔍 Buscando pedidos do vendedor: $sellerId');
      final response = await _supabase
          .from('seller_orders')
          .select()
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false);
      
      print('✅ Resposta do Supabase: ${response.length} pedidos encontrados');
      if (response.isEmpty) {
        print('⚠️ Nenhum pedido encontrado para o vendedor $sellerId');
      }
      
      return (response as List)
          .map((json) {
            try {
              return _orderFromJson(json);
            } catch (e) {
              print('❌ Erro ao converter pedido: $e');
              print('📦 JSON problemático: $json');
              rethrow;
            }
          })
          .toList();
    } catch (e) {
      print('❌ Erro ao buscar pedidos: $e');
      return [];
    }
  }

  static Future<void> updateOrderStatus(
    String orderId,
    SellerOrderStatus newStatus,
  ) async {
    try {
      print('🔄 Atualizando status do pedido $orderId para: ${newStatus.name}');
      
      final updateData = {
        'status': newStatus.name,
      };
      
      if (newStatus == SellerOrderStatus.processando) {
        updateData['processed_at'] = DateTime.now().toIso8601String();
      } else if (newStatus == SellerOrderStatus.entregue) {
        updateData['delivered_at'] = DateTime.now().toIso8601String();
      }
      
      // Atualizar no Supabase
      await _supabase
          .from('seller_orders')
          .update(updateData)
          .eq('id', orderId);
      
      print('✅ Status atualizado no banco de dados');
      
      // Buscar pedido atualizado para sincronizar com o cliente
      final response = await _supabase
          .from('seller_orders')
          .select()
          .eq('id', orderId)
          .single();
      
      final order = _orderFromJson(response);
      
      // Sincronizar com o pedido do cliente
      await _syncOrderStatusWithCustomer(order);
      
      print('✅ Pedido atualizado e sincronizado com sucesso');
    } catch (e) {
      print('❌ Erro ao atualizar status do pedido: $e');
      throw e;
    }
  }

  // 🔥 CRIA PEDIDO DO VENDEDOR (CHAMADO QUANDO CLIENTE COMPRA)
  static Future<void> createOrder({
    required String productId,
    required int quantity,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    String? size,
    String? color,
    String? age,
    String? storage,
    String? pantSize,
    String? shoeSize,
    String? customerOrderId,
  }) async {
    try {
      print('🛒 Criando pedido para produto: $productId');
      final product = await getById(productId);
      if (product == null) {
        print('❌ Produto não encontrado: $productId');
        return;
      }

      print('✅ Produto encontrado: ${product.name}');
      print('👤 Vendedor: ${product.sellerId}');

      // USAR O MESMO ID DO PEDIDO DO CLIENTE (ou gerar sequencial se não fornecido)
      final orderId = customerOrderId ?? await getNextOrderId();
      
      final orderData = {
        'id': orderId,
        'seller_id': product.sellerId,
        'product_id': productId,
        'customer_order_id': customerOrderId,
        'product_name': product.name,
        'product_image': product.images.isNotEmpty ? product.images.first : '',
        'product_price': product.price,
        'quantity': quantity,
        'total': product.price * quantity,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'delivery_address': customerAddress,
        'status': SellerOrderStatus.novo.name,
        'size': size,
        'color': color,
        'age': age,
        'storage': storage,
        'pant_size': pantSize,
        'shoe_size': shoeSize,
      };
      
      print('📦 Dados do pedido: $orderData');
      await _supabase.from('seller_orders').insert(orderData);
      print('✅ Pedido criado com sucesso: $orderId');
      
      // O trigger do Supabase já atualiza o estoque automaticamente
    } catch (e) {
      print('❌ Erro ao criar pedido: $e');
      print('📋 Stack trace: ${StackTrace.current}');
      throw e;
    }
  }

  // ===== FINANÇAS =====
  static Future<List<SellerTransaction>> getTransactionsBySeller(String sellerId) async {
    try {
      final response = await _supabase
          .from('seller_transactions')
          .select()
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((json) => _transactionFromJson(json))
          .toList();
    } catch (e) {
      print('Erro ao buscar transações: $e');
      return [];
    }
  }

  static Future<SellerFinanceSummary> getFinanceSummary(String sellerId) async {
    try {
      final response = await _supabase
          .rpc('get_seller_finance', params: {'p_seller_id': sellerId});
      
      if (response == null || response.isEmpty) {
        return SellerFinanceSummary(
          totalSales: 0,
          totalCommission: 0,
          availableBalance: 0,
          pendingBalance: 0,
          totalOrders: 0,
          deliveredOrders: 0,
        );
      }
      
      final data = response[0];
      return SellerFinanceSummary(
        totalSales: (data['total_earnings'] ?? 0).toDouble(),
        totalCommission: ((data['total_earnings'] ?? 0) * 0.1).toDouble(),
        availableBalance: (data['available_balance'] ?? 0).toDouble(),
        pendingBalance: (data['pending_balance'] ?? 0).toDouble(),
        totalOrders: (data['total_sales'] ?? 0).toInt(),
        deliveredOrders: (data['total_sales'] ?? 0).toInt(),
      );
    } catch (e) {
      print('Erro ao buscar resumo financeiro: $e');
      return SellerFinanceSummary(
        totalSales: 0,
        totalCommission: 0,
        availableBalance: 0,
        pendingBalance: 0,
        totalOrders: 0,
        deliveredOrders: 0,
      );
    }
  }

  static Future<void> requestWithdrawal(String sellerId, double amount) async {
    try {
      final result = await _supabase
          .rpc('process_withdrawal', params: {
            'p_seller_id': sellerId,
            'p_amount': amount,
          });
      
      if (result == false) {
        throw Exception('Saldo insuficiente');
      }
    } catch (e) {
      print('Erro ao solicitar saque: $e');
      throw e;
    }
  }

  // 🔥 SINCRONIZAR STATUS COM PEDIDO DO CLIENTE
  static Future<void> _syncOrderStatusWithCustomer(SellerOrderModel sellerOrder) async {
    try {
      // Mapear status do vendedor para status do cliente
      OrderStatus customerStatus;
      switch (sellerOrder.status) {
        case SellerOrderStatus.novo:
          customerStatus = OrderStatus.pendente;
          break;
        case SellerOrderStatus.processando:
        case SellerOrderStatus.enviado:
          customerStatus = OrderStatus.andamento;
          break;
        case SellerOrderStatus.entregue:
          customerStatus = OrderStatus.entregue;
          break;
        case SellerOrderStatus.cancelado:
        case SellerOrderStatus.reembolsoSolicitado:
          customerStatus = OrderStatus.reembolsoSolicitado;
          break;
      }
      
      print('🔄 Sincronizando status vendedor→cliente: ${sellerOrder.status.name} → ${customerStatus.name}');
      print('📋 Atualizando pedido ID: ${sellerOrder.id}');
      
      // Atualizar status do pedido do cliente no Supabase
      // Usar o mesmo ID (WP-xxx) pois ambas as tabelas compartilham o mesmo ID
      await _supabase
          .from('orders')
          .update({
            'status': customerStatus.name,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sellerOrder.id);
      
      print('✅ Status do cliente sincronizado: orders.id = ${sellerOrder.id}');
    } catch (e) {
      print('❌ Erro ao sincronizar status com cliente: $e');
      throw e;
    }
  }
  
  // 🔥 DELETAR PEDIDO (SINCRONIZADO ENTRE CLIENTE E VENDEDOR)
  static Future<void> deleteOrder(String orderId) async {
    try {
      print('🗑️ Deletando pedido: $orderId');
      
      // Usar função RPC do Supabase para deletar completamente
      final result = await _supabase.rpc(
        'delete_order_complete',
        params: {'order_id_param': orderId},
      );
      
      if (result == true) {
        print('✅ Pedido deletado com sucesso: $orderId');
      } else {
        throw Exception('Falha ao deletar pedido');
      }
    } catch (e) {
      print('❌ Erro ao deletar pedido: $e');
      throw e;
    }
  }
  
  // 🔥 APROVAR REEMBOLSO (VENDEDOR APROVA E DEVOLVE DINHEIRO)
  static Future<void> approveRefund(String orderId) async {
    try {
      print('✅ Vendedor aprovando reembolso: $orderId');
      
      // Atualizar status do pedido do vendedor para cancelado
      await _supabase
          .from('seller_orders')
          .update({
            'status': SellerOrderStatus.cancelado.name,
          })
          .eq('id', orderId);
      
      // Atualizar status do pedido do cliente para reembolsado
      await _supabase
          .from('orders')
          .update({
            'status': OrderStatus.reembolsoSolicitado.name,
          })
          .eq('id', orderId);
      
      // Buscar seller_id para criar transação de reembolso
      final sellerOrder = await _supabase
          .from('seller_orders')
          .select('seller_id, total')
          .eq('id', orderId)
          .single();
      
      final sellerId = sellerOrder['seller_id'];
      final total = (sellerOrder['total'] ?? 0).toDouble();
      
      // Criar transação de reembolso (débito no saldo do vendedor)
      await _supabase.from('seller_transactions').insert({
        'seller_id': sellerId,
        'type': 'reembolso',
        'amount': total,
        'description': 'Reembolso aprovado - Pedido #$orderId',
        'order_id': orderId,
      });
      
      // Atualizar saldo do vendedor
      await _supabase.rpc('update_seller_balance_refund', params: {
        'p_seller_id': sellerId,
        'p_amount': total,
      });
      
      // Criar notificação para o cliente
      final order = await _supabase
          .from('orders')
          .select('user_id')
          .eq('id', orderId)
          .single();
      
      final clientId = order['user_id'];
      print('👤 Cliente ID: $clientId');
      
      await _supabase.from('notifications').insert({
        'user_id': clientId,
        'title': '✅ Reembolso Aprovado',
        'message': 'Seu reembolso do pedido #$orderId foi aprovado! O valor será devolvido em breve.',
        'type': 'pedido',
        'related_id': orderId,
      });
      
      print('🔔 Notificação criada para cliente: $clientId');
      print('✅ Reembolso aprovado e cliente notificado');
    } catch (e) {
      print('❌ Erro ao aprovar reembolso: $e');
      throw e;
    }
  }
  
  // 🔥 NEGAR REEMBOLSO (VENDEDOR RECUSA)
  static Future<void> denyRefund(String orderId, String reason) async {
    try {
      print('❌ Vendedor negando reembolso: $orderId');
      
      // Reverter status do pedido do vendedor para o anterior
      await _supabase
          .from('seller_orders')
          .update({
            'status': SellerOrderStatus.entregue.name,
            'refund_reason': null,
          })
          .eq('id', orderId);
      
      // Reverter status do pedido do cliente
      await _supabase
          .from('orders')
          .update({
            'status': OrderStatus.entregue.name,
            'refund_reason': 'Negado: $reason',
          })
          .eq('id', orderId);
      
      // Criar notificação para o cliente
      final order = await _supabase
          .from('orders')
          .select('user_id')
          .eq('id', orderId)
          .single();
      
      final clientId = order['user_id'];
      print('👤 Cliente ID: $clientId');
      
      await _supabase.from('notifications').insert({
        'user_id': clientId,
        'title': '❌ Reembolso Negado',
        'message': 'Seu reembolso do pedido #$orderId foi negado. Motivo: $reason',
        'type': 'pedido',
        'related_id': orderId,
      });
      
      print('🔔 Notificação criada para cliente: $clientId');
      print('✅ Reembolso negado e cliente notificado');
    } catch (e) {
      print('❌ Erro ao negar reembolso: $e');
      throw e;
    }
  }

  // 🔥 SINCRONIZAR MOTIVO DO REEMBOLSO DO CLIENTE PARA VENDEDOR
  static Future<void> syncRefundReasonFromCustomer(String customerOrderId, String reason) async {
    try {
      print('🔄 Sincronizando motivo de reembolso cliente→vendedor');
      print('📋 Pedido ID: $customerOrderId');
      print('📝 Motivo: $reason');
      
      // Atualizar no Supabase - usar o mesmo ID (WP-xxx)
      await _supabase
          .from('seller_orders')
          .update({
            'refund_reason': reason,
            'status': SellerOrderStatus.reembolsoSolicitado.name,
          })
          .eq('id', customerOrderId);
      
      print('✅ Motivo de reembolso sincronizado: seller_orders.id = $customerOrderId');
      
      // 🔔 CRIAR NOTIFICAÇÃO PARA O VENDEDOR
      try {
        // Buscar seller_id do pedido
        final sellerOrder = await _supabase
            .from('seller_orders')
            .select('seller_id')
            .eq('id', customerOrderId)
            .maybeSingle();
        
        if (sellerOrder != null) {
          final sellerId = sellerOrder['seller_id'];
          
          // Criar notificação
          await _supabase.from('notifications').insert({
            'user_id': sellerId,
            'title': '💰 Reembolso Solicitado',
            'message': 'Cliente solicitou reembolso do pedido #$customerOrderId. Motivo: $reason',
            'type': 'pedido',
            'related_id': customerOrderId,
          });
          
          print('🔔 Notificação enviada ao vendedor: $sellerId');
        }
      } catch (notifError) {
        print('⚠️ Erro ao criar notificação: $notifError');
      }
    } catch (e) {
      print('❌ Erro ao sincronizar motivo de reembolso: $e');
      throw e;
    }
  }

  // ===== MÉTODOS AUXILIARES DE CONVERSÃO JSON =====
  
  static SellerProductModel _productFromJson(Map<String, dynamic> json) {
    return SellerProductModel(
      id: json['id'] ?? '',
      sellerId: json['seller_id'] ?? '',
      sellerStoreName: json['seller_store_name'] ?? 'Loja',
      name: json['name'] ?? 'Produto',
      price: (json['price'] ?? 0).toDouble(),
      oldPrice: json['old_price'] != null ? (json['old_price']).toDouble() : null,
      images: json['images'] != null ? List<String>.from(json['images']) : [],
      description: json['description'] ?? '',
      category: json['category'] ?? 'Outros',
      stock: json['stock'] ?? 0,
      active: json['active'] ?? true,
      soldCount: json['sold_count'] ?? 0,
      popularity: (json['popularity'] ?? 0).toDouble(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : DateTime.now(),
      sizes: json['sizes'] != null ? List<String>.from(json['sizes']) : null,
      colors: json['colors'] != null ? List<String>.from(json['colors']) : null,
      ageGroups: json['age_groups'] != null ? List<String>.from(json['age_groups']) : null,
      storageOptions: json['storage_options'] != null ? List<String>.from(json['storage_options']) : null,
      pantSizes: json['pant_sizes'] != null ? List<String>.from(json['pant_sizes']) : null,
      shoeSizes: json['shoe_sizes'] != null ? List<String>.from(json['shoe_sizes']) : null,
      transportPrice: (json['transport_price'] ?? 50.0).toDouble(),
      hasSizeOption: json['has_size_option'] ?? false,
      hasColorOption: json['has_color_option'] ?? false,
      hasAgeOption: json['has_age_option'] ?? false,
      hasStorageOption: json['has_storage_option'] ?? false,
      hasPantSizeOption: json['has_pant_size_option'] ?? false,
      hasShoeSizeOption: json['has_shoe_size_option'] ?? false,
      hasLocationEnabled: json['has_location_enabled'] ?? false,
      storeLatitude: json['store_latitude'] != null ? (json['store_latitude']).toDouble() : null,
      storeLongitude: json['store_longitude'] != null ? (json['store_longitude']).toDouble() : null,
      storeAddress: json['store_address'],
      clicksCount: json['clicks_count'] ?? 0,
      viewsCount: json['views_count'] ?? 0,
    );
  }

  static Map<String, dynamic> _productToJson(SellerProductModel product) {
    return {
      'id': product.id,
      'seller_id': product.sellerId,
      'seller_store_name': product.sellerStoreName,
      'name': product.name,
      'price': product.price,
      'old_price': product.oldPrice, // Envia null explicitamente quando não há promoção
      'image': product.images.isNotEmpty ? product.images.first : '', // Compatibilidade com banco
      'images': product.images,
      'description': product.description,
      'category': product.category,
      'stock': product.stock,
      'active': product.active,
      'sold_count': product.soldCount,
      'popularity': product.popularity,
      'sizes': product.sizes,
      'colors': product.colors,
      'age_groups': product.ageGroups,
      'storage_options': product.storageOptions,
      'pant_sizes': product.pantSizes,
      'shoe_sizes': product.shoeSizes,
      'transport_price': product.transportPrice,
      'has_size_option': product.hasSizeOption,
      'has_color_option': product.hasColorOption,
      'has_age_option': product.hasAgeOption,
      'has_storage_option': product.hasStorageOption,
      'has_pant_size_option': product.hasPantSizeOption,
      'has_shoe_size_option': product.hasShoeSizeOption,
      'has_location_enabled': product.hasLocationEnabled,
      'store_latitude': product.storeLatitude,
      'store_longitude': product.storeLongitude,
      'store_address': product.storeAddress,
      'updated_at': DateTime.now().toIso8601String(), // Atualiza timestamp
    };
  }

  static SellerOrderModel _orderFromJson(Map<String, dynamic> json) {
    return SellerOrderModel(
      id: json['id'] ?? '',
      sellerId: json['seller_id'] ?? '',
      productId: json['product_id'] ?? '',
      productName: json['product_name'] ?? 'Produto sem nome',
      productImage: json['product_image'] ?? '',
      productPrice: (json['product_price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 1,
      total: (json['total'] ?? 0).toDouble(),
      customerName: json['customer_name'] ?? 'Cliente',
      customerPhone: json['customer_phone'] ?? '',
      deliveryAddress: json['delivery_address'] ?? '',
      status: SellerOrderStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SellerOrderStatus.novo,
      ),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      processedAt: json['processed_at'] != null ? DateTime.parse(json['processed_at']) : null,
      deliveredAt: json['delivered_at'] != null ? DateTime.parse(json['delivered_at']) : null,
      size: json['size'],
      color: json['color'],
      age: json['age'],
      storage: json['storage'],
      pantSize: json['pant_size'],
      shoeSize: json['shoe_size'],
      customerOrderId: json['customer_order_id'],
      refundReason: json['refund_reason'],
    );
  }

  static SellerTransaction _transactionFromJson(Map<String, dynamic> json) {
    return SellerTransaction(
      id: json['id'],
      sellerId: json['seller_id'],
      type: TransactionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TransactionType.venda,
      ),
      amount: (json['amount']).toDouble(),
      description: json['description'],
      createdAt: DateTime.parse(json['created_at']),
      orderId: json['order_id'],
    );
  }
}
