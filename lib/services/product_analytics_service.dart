import 'package:supabase_flutter/supabase_flutter.dart';

/// 📊 Serviço de Analytics para rastrear comportamento do usuário
/// Todas as métricas são enviadas para o Supabase em tempo real
class ProductAnalyticsService {
  static final _supabase = Supabase.instance.client;

  /// IDs de produtos que o usuário já interagiu nesta sessão
  static final Set<String> _userInteractedProductIds = <String>{};

  /// Lista somente leitura com os produtos já interagidos
  static Set<String> get userInteractedProductIds => _userInteractedProductIds;

  /// Limpa as interações do usuário em memória (por exemplo, no logout)
  static void clearUserInteractions() {
    _userInteractedProductIds.clear();
  }

  /// 👁️ Registra visualização quando usuário abre detalhes do produto
  static Future<void> trackProductView(String productId) async {
    try {
      _userInteractedProductIds.add(productId);
      print('📊 Rastreando visualização: $productId');
      await _supabase.rpc(
        'track_product_view',
        params: {'product_id': productId},
      );
      print('✅ Visualização registrada');
    } catch (e) {
      print('❌ Erro ao rastrear visualização: $e');
    }
  }

  /// 🖱️ Registra clique quando usuário clica no card do produto
  static Future<void> trackProductClick(String productId) async {
    try {
      _userInteractedProductIds.add(productId);
      print('📊 Rastreando clique: $productId');
      await _supabase.rpc(
        'track_product_click',
        params: {'product_id': productId},
      );
      print('✅ Clique registrado');
    } catch (e) {
      print('❌ Erro ao rastrear clique: $e');
    }
  }

  /// 🔍 Registra quando produto aparece em resultado de pesquisa
  static Future<void> trackProductSearch(String productId) async {
    try {
      _userInteractedProductIds.add(productId);
      print('📊 Rastreando busca: $productId');
      await _supabase.rpc(
        'track_product_search',
        params: {'product_id': productId},
      );
      print('✅ Busca registrada');
    } catch (e) {
      print('❌ Erro ao rastrear busca: $e');
    }
  }

  /// 📝 Registra pesquisa do usuário (termo e quantidade de resultados)
  static Future<void> logSearch({
    required String searchTerm,
    required int resultsCount,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      print(
        '📊 Registrando pesquisa: "$searchTerm" ($resultsCount resultados)',
      );
      await _supabase.rpc(
        'log_search',
        params: {
          'p_user_id': userId,
          'p_search_term': searchTerm,
          'p_results_count': resultsCount,
        },
      );
      print('✅ Pesquisa registrada');
    } catch (e) {
      print('❌ Erro ao registrar pesquisa: $e');
    }
  }

  /// 🔥 Registra múltiplos produtos que aparecem em pesquisa (batch)
  static Future<void> trackSearchResults(List<String> productIds) async {
    if (productIds.isEmpty) return;

    try {
      print('📊 Rastreando ${productIds.length} produtos nos resultados');
      // Envia em paralelo para performance
      await Future.wait(
        productIds.map((id) => trackProductSearch(id)),
        eagerError: false, // Continua mesmo se alguns falharem
      );
      print('✅ Todos os produtos rastreados');
    } catch (e) {
      print('❌ Erro ao rastrear resultados: $e');
    }
  }

  /// 🎯 Calcula score de popularidade de um produto
  static Future<double> calculatePopularityScore(String productId) async {
    try {
      print('📊 Calculando popularidade: $productId');
      final result = await _supabase.rpc(
        'calculate_popularity_score',
        params: {'product_id': productId},
      );

      final score = (result as num?)?.toDouble() ?? 0.0;
      print('✅ Score calculado: $score');
      return score;
    } catch (e) {
      print('❌ Erro ao calcular popularidade: $e');
      return 0.0;
    }
  }

  /// 📈 Obtém produtos mais populares (por categoria ou todos)
  static Future<List<Map<String, dynamic>>> getMostPopularProducts({
    String? category,
    int limit = 10,
  }) async {
    try {
      print(
        '📊 Buscando produtos mais populares${category != null ? " em $category" : ""}',
      );
      final result = await _supabase.rpc(
        'get_most_popular_products',
        params: {'p_category': category, 'p_limit': limit},
      );

      print('✅ ${(result as List).length} produtos populares encontrados');
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('❌ Erro ao buscar produtos populares: $e');
      return [];
    }
  }

  /// 🏆 Obtém produtos mais vendidos (por categoria ou todos)
  static Future<List<Map<String, dynamic>>> getBestSellingProducts({
    String? category,
    int limit = 10,
  }) async {
    try {
      print(
        '📊 Buscando produtos mais vendidos${category != null ? " em $category" : ""}',
      );
      final result = await _supabase.rpc(
        'get_best_selling_products',
        params: {'p_category': category, 'p_limit': limit},
      );

      print('✅ ${(result as List).length} produtos mais vendidos encontrados');
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('❌ Erro ao buscar produtos mais vendidos: $e');
      return [];
    }
  }

  /// 🆕 Obtém produtos novos (últimos X dias)
  static Future<List<Map<String, dynamic>>> getNewProducts({
    String? category,
    int days = 30,
    int limit = 10,
  }) async {
    try {
      print(
        '📊 Buscando produtos novos (últimos $days dias)${category != null ? " em $category" : ""}',
      );
      final result = await _supabase.rpc(
        'get_new_products',
        params: {'p_category': category, 'p_days': days, 'p_limit': limit},
      );

      print('✅ ${(result as List).length} produtos novos encontrados');
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('❌ Erro ao buscar produtos novos: $e');
      return [];
    }
  }

  /// 📊 Obtém estatísticas de um produto
  static Future<Map<String, dynamic>?> getProductStats(String productId) async {
    try {
      print('📊 Buscando estatísticas: $productId');
      final result = await _supabase
          .from('products')
          .select(
            'views_count, clicks_count, search_count, sold_count, popularity_score, created_at, last_viewed_at',
          )
          .eq('id', productId)
          .maybeSingle();

      if (result != null) {
        print('✅ Estatísticas encontradas');
        return result;
      }

      print('⚠️ Produto não encontrado');
      return null;
    } catch (e) {
      print('❌ Erro ao buscar estatísticas: $e');
      return null;
    }
  }

  /// 🔥 Obtém termos de pesquisa mais populares
  static Future<List<Map<String, dynamic>>> getPopularSearchTerms({
    int limit = 10,
  }) async {
    try {
      print('📊 Buscando termos mais pesquisados');
      final result = await _supabase
          .from('search_logs')
          .select('search_term, created_at')
          .order('created_at', ascending: false)
          .limit(limit);

      print('✅ ${(result as List).length} termos globais encontrados');
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('❌ Erro ao buscar termos populares: $e');
      return [];
    }
  }

  /// 👤 Obtém termos de pesquisa populares PERSONALIZADOS por usuário
  ///
  /// - Usa o histórico da tabela search_logs filtrando por user_id
  /// - Calcula a frequência dos termos em memória e ordena por contagem
  /// - Limita ao número pedido e retorna no mesmo formato de getPopularSearchTerms
  static Future<List<Map<String, dynamic>>> getUserPopularSearchTerms({
    int limit = 10,
    int historyLimit = 200,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print(
          '⚠️ Usuário não autenticado, retornando lista vazia de termos personalizados',
        );
        return [];
      }

      print('📊 Buscando termos mais pesquisados do usuário $userId');

      final result = await _supabase
          .from('search_logs')
          .select('search_term, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(historyLimit);

      final rows = List<Map<String, dynamic>>.from(result as List);
      if (rows.isEmpty) {
        print('⚠️ Nenhum termo encontrado para o usuário');
        return [];
      }

      // Conta frequência de cada termo
      final Map<String, int> counts = {};
      for (final row in rows) {
        final term = (row['search_term'] as String?)?.trim();
        if (term == null || term.isEmpty) continue;
        counts[term] = (counts[term] ?? 0) + 1;
      }

      if (counts.isEmpty) {
        print('⚠️ Não há termos válidos após processamento');
        return [];
      }

      final sorted =
          counts.entries
              .map((e) => {'search_term': e.key, 'count': e.value})
              .toList()
            ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      final limited = sorted.take(limit).toList();
      print('✅ ${limited.length} termos personalizados encontrados');
      return limited;
    } catch (e) {
      print('❌ Erro ao buscar termos personalizados do usuário: $e');
      return [];
    }
  }

  /// 📈 Debug: Exibe métricas de um produto no console
  static Future<void> debugProductMetrics(String productId) async {
    try {
      final stats = await getProductStats(productId);
      if (stats == null) {
        print('❌ Produto não encontrado: $productId');
        return;
      }

      print('═══════════════════════════════════');
      print('📊 MÉTRICAS DO PRODUTO');
      print('═══════════════════════════════════');
      print('🆔 ID: $productId');
      print('👁️ Visualizações: ${stats['views_count'] ?? 0}');
      print('🖱️ Cliques: ${stats['clicks_count'] ?? 0}');
      print('🔍 Pesquisas: ${stats['search_count'] ?? 0}');
      print('🛒 Vendidos: ${stats['sold_count'] ?? 0}');
      print('⭐ Score: ${stats['popularity_score'] ?? 0}');
      print('📅 Criado: ${stats['created_at']}');
      print('👀 Última visualização: ${stats['last_viewed_at'] ?? "Nunca"}');
      print('═══════════════════════════════════');
    } catch (e) {
      print('❌ Erro ao exibir métricas: $e');
    }
  }
}
