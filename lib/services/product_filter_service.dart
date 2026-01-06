import '../models/product_model.dart';

/// Enum para os tipos de subcategorias/filtros disponíveis
enum ProductFilterType {
  maisPopulares,
  maisComprados,
  maisBaratos,
  novos,
  promocoes,
  recomendados,
}

/// 🎯 Serviço DINÂMICO de filtragem de produtos  
/// TODAS as métricas vêm do Supabase (nada estático!)
/// 
/// Como funciona:
/// - Mais Populares: Baseado em popularity_score (calculado automaticamente)
/// - Mais Comprados: Baseado em sold_count (atualizado em vendas reais)
/// - Mais Baratos: Ordenação por preço
/// - Novos: Últimos 30 dias (baseado em created_at)
/// - Promoções: Produtos com old_price > price
/// - Recomendados: Combinação de métricas reais
class ProductFilterService {
  /// Número de dias para considerar um produto "novo"
  static const int _newProductDays = 30;

  /// Filtra produtos por categoria e aplica o filtro especificado
  /// 
  /// [allProducts] - Lista completa de produtos disponíveis
  /// [categoryName] - Nome da categoria ativa ('Início' para todos)
  /// [filterType] - Tipo de filtro a ser aplicado
  static List<ProductModel> filterProducts({
    required List<ProductModel> allProducts,
    required String categoryName,
    required ProductFilterType filterType,
  }) {
    // Primeiro, filtra por categoria
    final categoryFiltered = _filterByCategory(allProducts, categoryName);
    
    // Se não há produtos, retorna vazio
    if (categoryFiltered.isEmpty) {
      print('⚠️ Nenhum produto encontrado na categoria: $categoryName');
      return [];
    }
    
    // Aplica o filtro específico
    final filtered = _applyFilter(categoryFiltered, filterType);
    
    print('📊 Filtro "${filterTypeToString(filterType)}" em "$categoryName": ${filtered.length} produtos');
    return filtered;
  }
  
  /// Filtra produtos apenas por categoria
  static List<ProductModel> _filterByCategory(
    List<ProductModel> products,
    String categoryName,
  ) {
    // Se for "Início", retorna todos os produtos
    if (categoryName == 'Início' || categoryName.isEmpty) {
      return List<ProductModel>.from(products);
    }
    
    // Filtra por categoria específica (case-insensitive)
    return products
        .where((p) => p.category.toLowerCase() == categoryName.toLowerCase())
        .toList();
  }
  
  /// Aplica o filtro específico na lista de produtos
  /// 🎯 DINÂMICO - Prioriza dados reais do banco!
  /// ⚠️ FILTRO RIGOROSO - Só mostra produtos que atendem aos critérios
  static List<ProductModel> _applyFilter(
    List<ProductModel> products,
    ProductFilterType filterType,
  ) {
    List<ProductModel> list = [];
    
    switch (filterType) {
      case ProductFilterType.maisPopulares:
        // 📊 APENAS produtos com clicks_count > 0
        list = products.where((p) => (p.clicksCount ?? 0) > 0).toList();
        print('🔥 Filtrando Mais Populares: ${list.length} produtos com cliques');
        list.sort((a, b) {
          final aClicks = a.clicksCount ?? 0;
          final bClicks = b.clicksCount ?? 0;
          return bClicks.compareTo(aClicks);
        });
        return list;
        
      case ProductFilterType.maisComprados:
        // 🛒 APENAS produtos com sold_count > 0
        list = products.where((p) => p.soldCount > 0).toList();
        print('🛒 Filtrando Mais Comprados: ${list.length} produtos vendidos');
        list.sort((a, b) => b.soldCount.compareTo(a.soldCount));
        return list;
        
      case ProductFilterType.maisBaratos:
        // 💰 Todos os produtos (prioriza promoções)
        list = List<ProductModel>.from(products);
        print('💰 Filtrando Mais Baratos: ${list.length} produtos');
        list.sort((a, b) {
          // Produtos em promoção têm prioridade
          final aIsPromo = a.oldPrice != null && a.oldPrice! > 0;
          final bIsPromo = b.oldPrice != null && b.oldPrice! > 0;
          
          if (aIsPromo && !bIsPromo) return -1;
          if (!aIsPromo && bIsPromo) return 1;
          
          return a.price.compareTo(b.price);
        });
        return list;
        
      case ProductFilterType.novos:
        // 🆕 APENAS produtos criados nos últimos 30 dias
        final now = DateTime.now();
        list = products.where((p) {
          if (p.createdAt == null) return false;
          final daysSinceCreation = now.difference(p.createdAt!).inDays;
          return daysSinceCreation <= 30;
        }).toList();
        
        print('🆕 Filtrando Novos: ${list.length} produtos (< 30 dias)');
        list.sort((a, b) {
          if (a.createdAt == null && b.createdAt == null) return 0;
          if (a.createdAt == null) return 1;
          if (b.createdAt == null) return -1;
          return b.createdAt!.compareTo(a.createdAt!);
        });
        return list;
        
      case ProductFilterType.promocoes:
        // 🎁 APENAS produtos com old_price definido
        list = products.where((p) => p.oldPrice != null && p.oldPrice! > 0).toList();
        
        print('🎁 Filtrando Promoções: ${list.length} produtos');
        list.sort((a, b) {
          final discountA = _calculateDiscountPercentage(a);
          final discountB = _calculateDiscountPercentage(b);
          return discountB.compareTo(discountA);
        });
        
        return list;
        
      case ProductFilterType.recomendados:
        // ⭐ APENAS produtos com alguma métrica > 0
        list = products.where((p) => 
          (p.clicksCount ?? 0) > 0 || (p.viewsCount ?? 0) > 0 || p.soldCount > 0
        ).toList();
        
        print('⭐ Filtrando Recomendados: ${list.length} produtos com métricas');
        list.sort((a, b) {
          final aClicks = a.clicksCount ?? 0;
          final aViews = a.viewsCount ?? 0;
          final bClicks = b.clicksCount ?? 0;
          final bViews = b.viewsCount ?? 0;
          
          final scoreA = (aClicks * 0.4) + (aViews * 0.2) + (a.soldCount * 0.4);
          final scoreB = (bClicks * 0.4) + (bViews * 0.2) + (b.soldCount * 0.4);
          return scoreB.compareTo(scoreA);
        });
        
        return list;
    }
  }
  
  /// Calcula a porcentagem de desconto de um produto
  static double _calculateDiscountPercentage(ProductModel product) {
    if (product.oldPrice == null || product.oldPrice! <= product.price) {
      return 0.0;
    }
    return ((product.oldPrice! - product.price) / product.oldPrice!) * 100;
  }
  
  /// Pega o produto mais relevante para um filtro específico
  /// Útil para mostrar preview da subcategoria
  static ProductModel? getTopProduct({
    required List<ProductModel> allProducts,
    required String categoryName,
    required ProductFilterType filterType,
  }) {
    final filtered = filterProducts(
      allProducts: allProducts,
      categoryName: categoryName,
      filterType: filterType,
    );
    
    // Retorna o primeiro produto após filtragem
    return filtered.isNotEmpty ? filtered.first : null;
  }
  
  /// Converte string da subcategoria para FilterType
  static ProductFilterType? filterTypeFromString(String subcategory) {
    switch (subcategory.toLowerCase()) {
      case 'mais populares':
        return ProductFilterType.maisPopulares;
      case 'mais comprados':
        return ProductFilterType.maisComprados;
      case 'mais baratos':
        return ProductFilterType.maisBaratos;
      case 'novos':
        return ProductFilterType.novos;
      case 'promoções':
        return ProductFilterType.promocoes;
      case 'recomendados':
        return ProductFilterType.recomendados;
      default:
        return null;
    }
  }
  
  /// Converte FilterType para string legível
  static String filterTypeToString(ProductFilterType type) {
    switch (type) {
      case ProductFilterType.maisPopulares:
        return 'Mais populares';
      case ProductFilterType.maisComprados:
        return 'Mais comprados';
      case ProductFilterType.maisBaratos:
        return 'Mais baratos';
      case ProductFilterType.novos:
        return 'Novos';
      case ProductFilterType.promocoes:
        return 'Promoções';
      case ProductFilterType.recomendados:
        return 'Recomendados';
    }
  }
}
