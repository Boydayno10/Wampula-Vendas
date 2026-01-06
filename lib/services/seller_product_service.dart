import '../models/product_model.dart';
import '../models/seller_product_model.dart';
import '../models/client_publicacao_model.dart';
import '../models/seller_order_model.dart';
import '../models/seller_finance_model.dart';
import '../models/order_model.dart';
import '../utils/order_status_utils.dart';
import 'order_service.dart';
import 'chat_service.dart';
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

      return (response as List).map((json) => _productFromJson(json)).toList();
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

  /// Busca subcategorias específicas de uma categoria
  /// Tabela: category_subcategories
  /// Retorna mapas com pelo menos: id, category_name, name, description
  static Future<List<Map<String, dynamic>>> getCategorySubcategories(
    String categoryName,
  ) async {
    try {
      final response = await _supabase
          .from('category_subcategories')
          .select()
          .eq('category_name', categoryName)
          .eq('active', true)
          .order('display_order', ascending: true);

      return (response as List).map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao buscar category_subcategories para "$categoryName": $e');
      return [];
    }
  }

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

      await _supabase.from('products').update(data).eq('id', updated.id);

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
      await _supabase.from('products').delete().eq('id', id);

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
  static Future<void> updateSellerStoreName(
    String sellerId,
    String newStoreName,
  ) async {
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
      // 1) Busca todos os produtos ativos no banco
      final response = await _supabase
          .from('products')
          .select()
          .eq('active', true)
          .gt('stock', 0)
          .order('created_at', ascending: false);

      final allProducts = (response as List)
          .map((json) => _productFromJson(json))
          .toList();

      if (allProducts.isEmpty) {
        return [];
      }

      // 2) Pega todos os seller_ids distintos
      final sellerIds = allProducts
          .map((p) => p.sellerId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (sellerIds.isEmpty) {
        return [];
      }

      // 3) Busca no Supabase quais perfis ainda são vendedores
      //    Isso garante que produtos de ex‑vendedores não apareçam mais na Home
        final profilesResponse = await _supabase
          .from('profiles')
          .select('id, is_seller')
          .inFilter('id', sellerIds);

      final activeSellerIds = <String>{};
      for (final row in profilesResponse as List) {
        final id = row['id'] as String?;
        final isSeller = row['is_seller'] == true;
        if (id != null && isSeller) {
          activeSellerIds.add(id);
        }
      }

      // 4) Carrega informações de expiração das publicações de clientes
      //    (categoria "Temporarios") para nunca exibir itens expirados.
      final temporariosIds = allProducts
          .where((p) => p.category.toLowerCase() == 'temporarios')
          .map((p) => p.id)
          .toSet()
          .toList();

        // IDs de publicações de cliente (existem em client_publications)
        final clientPublicationIds = <String>{};
        // Subconjunto das acima que ainda NÃO expiraram
        final nonExpiredClientPublicationIds = <String>{};

      if (temporariosIds.isNotEmpty) {
        try {
          final pubsResponse = await _supabase
              .from('client_publications')
              .select()
              .inFilter('id', temporariosIds);

          for (final row in pubsResponse as List) {
            final pub = ClientPublicacaoModel.fromJson(
              row as Map<String, dynamic>,
            );
            // Marca que este ID de produto está ligado a uma
            // publicação de cliente (controlada por expiração).
            clientPublicationIds.add(pub.id);

            // Apenas publicações de cliente NÃO expiradas devem
            // continuar aparecendo para outros usuários.
            if (!pub.isExpired) {
              nonExpiredClientPublicationIds.add(pub.id);
            }
          }
        } catch (e) {
          // Em caso de erro, por segurança não adicionamos nenhuma
          // publicação de cliente (evitando exibir expiradas).
          print(
            'Erro ao carregar publicações de clientes para filtro de expiração: $e',
          );
        }
      }

      // 5) Mantém:
      //    - produtos de vendedores ATIVOS (inclusive categoria "Temporarios")
      //    - publicações de clientes NÃO EXPIRADAS (que têm linha em client_publications)
      final filtered = allProducts.where((p) {
        final isTemporarios = p.category.toLowerCase() == 'temporarios';

        // Se for um produto da categoria "Temporarios" E existir uma
        // publicação correspondente em client_publications, então é
        // uma publicação de cliente e deve respeitar expiração.
        if (isTemporarios && clientPublicationIds.contains(p.id)) {
          return nonExpiredClientPublicationIds.contains(p.id);
        }

        // Caso contrário (não é publicação de cliente), aplica apenas
        // a regra normal de vendedor ativo.
        final sellerStillActive = activeSellerIds.contains(p.sellerId);
        return sellerStillActive;
      }).toList();

      return filtered.map((p) => p.toProductModel()).toList();
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
  static Future<List<SellerOrderModel>> getOrdersBySeller(
    String sellerId,
  ) async {
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

      return (response as List).map((json) {
        try {
          return _orderFromJson(json);
        } catch (e) {
          print('❌ Erro ao converter pedido: $e');
          print('📦 JSON problemático: $json');
          rethrow;
        }
      }).toList();
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

      final updateData = {'status': newStatus.name};

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

      // Notificar cliente sobre mudança de status
      await _notifyCustomerStatusChange(order, newStatus);
    } catch (e) {
      print('❌ Erro ao atualizar status do pedido: $e');
      throw e;
    }
  }

  // 🔔 Notificar cliente quando o status do pedido mudar no painel do vendedor
  static Future<void> _notifyCustomerStatusChange(
    SellerOrderModel sellerOrder,
    SellerOrderStatus newStatus,
  ) async {
    try {
      // Usar o mesmo ID compartilhado entre seller_orders e orders
      final customerOrderId = sellerOrder.customerOrderId ?? sellerOrder.id;

      // Buscar o usuário (cliente) dono do pedido
      final orderRow = await _supabase
          .from('orders')
          .select('user_id')
          .eq('id', customerOrderId)
          .maybeSingle();

      if (orderRow == null || orderRow['user_id'] == null) {
        print(
          '⚠️ Pedido do cliente não encontrado para notificação: $customerOrderId',
        );
        return;
      }

      final customerId = orderRow['user_id'] as String;

      String? title;
      String? message;
      String type = 'pedido';

      switch (newStatus) {
        case SellerOrderStatus.novo:
          // Já existe notificação de novo pedido; não repetir.
          return;
        case SellerOrderStatus.processando:
          title = 'Seu pedido está em processamento';
          message =
              'O vendedor começou a preparar o seu pedido #$customerOrderId.';
          break;
        case SellerOrderStatus.enviado:
          title = 'Seu pedido foi enviado';
          message = 'Seu pedido #$customerOrderId está a caminho.';
          break;
        case SellerOrderStatus.entregue:
          // Entrega já é tratada por trigger no banco (notify_order_status_change).
          // Evitar duplicar notificação aqui.
          return;
        case SellerOrderStatus.cancelado:
          title = 'Seu pedido foi cancelado';
          message = 'O vendedor cancelou o pedido #$customerOrderId.';
          break;
        case SellerOrderStatus.reembolsoSolicitado:
          title = 'Reembolso solicitado';
          message =
              'O status do pedido #$customerOrderId foi alterado para reembolso solicitado.';
          break;
      }

      if (title == null || message == null) {
        return;
      }

      await _supabase.from('notifications').insert({
        'user_id': customerId,
        'title': title,
        'message': message,
        'type': type,
        'related_id': customerOrderId,
      });

      print(
        '📬 Notificação de status enviada para o cliente: $customerOrderId',
      );
    } catch (e) {
      print('❌ Erro ao notificar cliente sobre status do pedido: $e');
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
  static Future<List<SellerTransaction>> getTransactionsBySeller(
    String sellerId,
  ) async {
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
      final response = await _supabase.rpc(
        'get_seller_finance',
        params: {'p_seller_id': sellerId},
      );

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
      final result = await _supabase.rpc(
        'process_withdrawal',
        params: {'p_seller_id': sellerId, 'p_amount': amount},
      );

      if (result == false) {
        throw Exception('Saldo insuficiente');
      }
    } catch (e) {
      print('Erro ao solicitar saque: $e');
      throw e;
    }
  }

  // 🔥 SINCRONIZAR STATUS COM PEDIDO DO CLIENTE
  static Future<void> _syncOrderStatusWithCustomer(
    SellerOrderModel sellerOrder,
  ) async {
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

      // Garantir que usamos sempre o ID do pedido do cliente
      final customerOrderId = sellerOrder.customerOrderId ?? sellerOrder.id;

      print(
        '🔄 Sincronizando status vendedor→cliente: ${sellerOrder.status.name} → ${customerStatus.name}',
      );
      print('📋 Atualizando pedido ID: $customerOrderId');

      // Atualizar status do pedido do cliente no Supabase
      // Usar o mesmo ID (WP-xxx) pois ambas as tabelas compartilham o mesmo ID
      await _supabase
          .from('orders')
          .update({
            'status': orderStatusToDb(customerStatus),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', customerOrderId);

      print('✅ Status do cliente sincronizado: orders.id = $customerOrderId');
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

  /// Buscar o ID do vendedor a partir de um pedido (cliente ou vendedor).
  /// Usa tanto seller_orders.id quanto seller_orders.customer_order_id
  /// para garantir compatibilidade.
  static Future<String?> getSellerIdByOrderId(String orderId) async {
    try {
      final row = await _supabase
          .from('seller_orders')
          .select('seller_id')
          .or('id.eq.$orderId,customer_order_id.eq.$orderId')
          .limit(1)
          .maybeSingle();

      if (row == null || row['seller_id'] == null) {
        return null;
      }

      return row['seller_id'] as String;
    } catch (e) {
      print('❌ Erro ao buscar seller_id para pedido $orderId: $e');
      return null;
    }
  }

  // 🔥 APROVAR REEMBOLSO (VENDEDOR APROVA E DEVOLVE DINHEIRO)
  static Future<void> approveRefund(String orderId) async {
    try {
      print('✅ Vendedor aprovando reembolso: $orderId');

      // Atualizar status do pedido do vendedor para cancelado
      await _supabase
          .from('seller_orders')
          .update({'status': SellerOrderStatus.cancelado.name})
          .eq('id', orderId);

      // Buscar pedido do vendedor para descobrir seller_id, total e customer_order_id
      final sellerOrderRow = await _supabase
          .from('seller_orders')
          .select('seller_id, total, customer_order_id')
          .eq('id', orderId)
          .maybeSingle();

      if (sellerOrderRow == null || sellerOrderRow['seller_id'] == null) {
        print(
          '⚠️ Pedido do vendedor não encontrado ao aprovar reembolso: $orderId',
        );
        return;
      }

      final String customerOrderId =
          (sellerOrderRow['customer_order_id'] as String?) ?? orderId;

      // Buscar informações do pedido do cliente (inclui motivo inicial)
      final orderRow = await _supabase
          .from('orders')
          .select('user_id, refund_reason')
          .eq('id', customerOrderId)
          .maybeSingle();

      if (orderRow == null || orderRow['user_id'] == null) {
        print(
          '⚠️ Pedido do cliente não encontrado ao aprovar reembolso: $customerOrderId',
        );
        return;
      }

      final clientId = orderRow['user_id'];
      final originalReason = (orderRow['refund_reason'] as String?) ?? '';

      // Atualizar status do pedido do cliente para "reembolso em processamento"
      // usando o mesmo enum (reembolsoSolicitado) mas marcando refund_reason
      // com prefixo "Aprovado:" para que a UI mostre o texto correto.
      await _supabase
          .from('orders')
          .update({
            'status': orderStatusToDb(OrderStatus.reembolsoSolicitado),
            // Mantemos o padrão atual de texto, mas garantimos
            // que o prefixo "Aprovado:" exista para que RefundStatus
            // seja derivado corretamente.
            'refund_reason': originalReason.isEmpty
                ? 'Aprovado: Reembolso será processado'
                : (originalReason.startsWith('Aprovado:')
                      ? originalReason
                      : 'Aprovado: $originalReason'),
          })
          .eq('id', customerOrderId);

      final sellerId = sellerOrderRow['seller_id'];
      final total = (sellerOrderRow['total'] ?? 0).toDouble();

      // Criar transação de reembolso (débito no saldo do vendedor)
      await _supabase.from('seller_transactions').insert({
        'seller_id': sellerId,
        'type': 'reembolso',
        'amount': total,
        'description': 'Reembolso aprovado - Pedido #$orderId',
        'order_id': orderId,
      });

      // Atualizar saldo do vendedor
      await _supabase.rpc(
        'update_seller_balance_refund',
        params: {'p_seller_id': sellerId, 'p_amount': total},
      );

      // Criar notificação para o cliente
      print('👤 Cliente ID: $clientId');

      await _supabase.from('notifications').insert({
        'user_id': clientId,
        'title': '✅ Reembolso Aprovado',
        'message':
            'Seu reembolso do pedido #$orderId foi aprovado! O valor será devolvido em breve.',
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
  // Retorna opcionalmente o chatId criado/recuperado para conversa com o cliente
  static Future<String?> denyRefund(String orderId, String reason) async {
    String? chatId;
    try {
      print('❌ Vendedor negando reembolso: $orderId');

      // Atualizar status do pedido do vendedor para cancelado (pedido cancelado do ponto de vista do vendedor)
      await _supabase
          .from('seller_orders')
          .update({
            // Guardar o motivo da recusa aqui; o trigger em
            // sync_order_status_to_customer irá propagar para
            // orders.refund_reason com prefixo "Negado: ...".
            'status': SellerOrderStatus.cancelado.name,
            'refund_reason': reason,
          })
          .eq('id', orderId);

      // Descobrir o ID do pedido do cliente (customer_order_id pode ser diferente)
      final sellerOrderRow = await _supabase
          .from('seller_orders')
          .select('customer_order_id')
          .eq('id', orderId)
          .maybeSingle();

      final String customerOrderId =
          (sellerOrderRow?['customer_order_id'] as String?) ?? orderId;

      // Criar notificação para o cliente
      final order = await _supabase
          .from('orders')
          .select('user_id')
          .eq('id', customerOrderId)
          .maybeSingle();

      if (order == null || order['user_id'] == null) {
        print(
          '⚠️ Pedido do cliente não encontrado ao negar reembolso: $orderId',
        );
        return chatId;
      }

      final clientId = order['user_id'];
      print('👤 Cliente ID: $clientId');

      await _supabase.from('notifications').insert({
        'user_id': clientId,
        'title': '❌ Reembolso Negado',
        'message':
            'Seu reembolso do pedido #$orderId foi negado. Motivo: $reason',
        'type': 'pedido',
        'related_id': orderId,
      });

      print('🔔 Notificação criada para cliente: $clientId');
      print('✅ Reembolso negado e cliente notificado');

      // 💬 Iniciar conversa de chat automática com o cliente sobre o reembolso negado
      try {
        final autoMessage =
            'Olá! Sobre o seu pedido #$orderId:\n'
            'Seu pedido de reembolso foi negado. Motivo: $reason.\n'
            'Se tiver alguma dúvida, pode responder por aqui e vamos conversar.';

        // currentUser (vendedor) conversa diretamente com o cliente (clientId)
        // e associamos o chat ao código do pedido (orderId)
        final chat = await ChatService.getOrCreateDirectChatWithUser(
          otherUserId: clientId,
          orderCode: orderId,
        );

        await ChatService.sendMessage(chatId: chat.id, text: autoMessage);

        chatId = chat.id;
        print(
          '💬 Chat direto criado/atualizado para reembolso negado: ${chat.id}',
        );
      } catch (chatError) {
        // Qualquer erro no chat não deve impedir a negação do reembolso
        print(
          '⚠️ Erro ao criar/enviar mensagem de chat para reembolso negado: $chatError',
        );
      }
    } catch (e) {
      print('❌ Erro ao negar reembolso: $e');
      throw e;
    }

    return chatId;
  }

  // 🔥 SINCRONIZAR MOTIVO DO REEMBOLSO DO CLIENTE PARA VENDEDOR
  static Future<void> syncRefundReasonFromCustomer(
    String customerOrderId,
    String reason,
  ) async {
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

      print(
        '✅ Motivo de reembolso sincronizado: seller_orders.id = $customerOrderId',
      );

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
            'message':
                'Cliente solicitou reembolso do pedido #$customerOrderId. Motivo: $reason',
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
      oldPrice: json['old_price'] != null
          ? (json['old_price']).toDouble()
          : null,
      images: json['images'] != null ? List<String>.from(json['images']) : [],
      bannerImage: json['banner_image'] as String?,
      description: json['description'] ?? '',
      category: json['category'] ?? 'Outros',
      // Usa coluna category_subcategory_id (nome atual no banco)
      // Mantém compatibilidade caso, no futuro, exista também subcategory_id
      categorySubcategoryId:
          json['category_subcategory_id'] ?? json['subcategory_id'],
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
      ageGroups: json['age_groups'] != null
          ? List<String>.from(json['age_groups'])
          : null,
      storageOptions: json['storage_options'] != null
          ? List<String>.from(json['storage_options'])
          : null,
      pantSizes: json['pant_sizes'] != null
          ? List<String>.from(json['pant_sizes'])
          : null,
      shoeSizes: json['shoe_sizes'] != null
          ? List<String>.from(json['shoe_sizes'])
          : null,
      transportPrice: (json['transport_price'] ?? 50.0).toDouble(),
      hasSizeOption: json['has_size_option'] ?? false,
      hasColorOption: json['has_color_option'] ?? false,
      hasAgeOption: json['has_age_option'] ?? false,
      hasStorageOption: json['has_storage_option'] ?? false,
      hasPantSizeOption: json['has_pant_size_option'] ?? false,
      hasShoeSizeOption: json['has_shoe_size_option'] ?? false,
      hasLocationEnabled: json['has_location_enabled'] ?? false,
      storeLatitude: json['store_latitude'] != null
          ? (json['store_latitude']).toDouble()
          : null,
      storeLongitude: json['store_longitude'] != null
          ? (json['store_longitude']).toDouble()
          : null,
      storeAddress: json['store_address'],
      clicksCount: json['clicks_count'] ?? 0,
      viewsCount: json['views_count'] ?? 0,
      descriptionAlignment: (json['description_alignment'] ?? 'left')
          .toString(),
      descriptionBold: json['description_bold'] ?? false,
      descriptionItalic: json['description_italic'] ?? false,
    );
  }

  static Map<String, dynamic> _productToJson(SellerProductModel product) {
    return {
      'id': product.id,
      'seller_id': product.sellerId,
      'seller_store_name': product.sellerStoreName,
      'name': product.name,
      'price': product.price,
      'old_price':
          product.oldPrice, // Envia null explicitamente quando não há promoção
      'image': product.images.isNotEmpty
          ? product.images.first
          : '', // Compatibilidade com banco
      'images': product.images,
      'banner_image': product.bannerImage,
      'description': product.description,
      'description_alignment': product.descriptionAlignment,
      'description_bold': product.descriptionBold,
      'description_italic': product.descriptionItalic,
      'category': product.category,
      'category_subcategory_id': product.categorySubcategoryId,
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
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'])
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'])
          : null,
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
