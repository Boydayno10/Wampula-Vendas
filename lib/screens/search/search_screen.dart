import 'package:flutter/material.dart';
import '../../data/mock_products.dart';
import '../../models/product_model.dart';
import '../../widgets/product_card.dart';
import '../../widgets/dynamic_product_grid.dart';
import '../../services/seller_product_service.dart';
import '../../services/product_analytics_service.dart';

class SearchScreen extends StatefulWidget {
  final String searchQuery;
  const SearchScreen({super.key, this.searchQuery = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const int _pageSize = 8;
  static const Duration _loadMoreDelay = Duration(milliseconds: 900);

  late TextEditingController _searchController;
  String _currentQuery = '';
  bool _showResults = false;
  List<ProductModel> _allProducts = [];
  bool _isLoading = true;
  List<String> _popularSearches = [];
  List<ProductModel> _recommendedForUser = [];
  int _visibleResultsCount = _pageSize;
  bool _isLoadingMoreResults = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
    _currentQuery = widget.searchQuery;
    _loadProducts();
    _loadPopularSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    setState(() {
      _currentQuery = query;
      _showResults = query.isNotEmpty;
      _visibleResultsCount = _pageSize;
      _isLoadingMoreResults = false;
    });

    // 📊 Registrar pesquisa e rastrear produtos encontrados
    if (query.isNotEmpty) {
      _trackSearch(query);
    }
  }

  /// Rastreia a pesquisa no analytics
  Future<void> _trackSearch(String query) async {
    final base = _getSourceProducts();
    final results = base.where((product) {
      return product.name.toLowerCase().contains(query.toLowerCase());
    }).toList();

    // Registrar o termo de pesquisa
    await ProductAnalyticsService.logSearch(
      searchTerm: query,
      resultsCount: results.length,
    );

    // Rastrear produtos que aparecem nos resultados (primeiros 10)
    final productIds = results.take(10).map((p) => p.id).toList();
    if (productIds.isNotEmpty) {
      ProductAnalyticsService.trackSearchResults(productIds);
    }

    // Atualiza recomendações personalizadas baseadas nesta busca
    _updateRecommendations();
  }

  /// Carrega produtos reais do backend (fallback para mockProducts se vazio)
  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);

    try {
      final products = await SellerProductService.getProductModels();
      if (!mounted) return;
      setState(() {
        _allProducts = products.isNotEmpty ? products : mockProducts;
        _isLoading = false;
        _visibleResultsCount = _pageSize;
        _isLoadingMoreResults = false;
        _updateRecommendations();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _allProducts = mockProducts;
        _isLoading = false;
        _visibleResultsCount = _pageSize;
        _isLoadingMoreResults = false;
        _updateRecommendations();
      });
    }
  }

  /// Lista base usada para todas as buscas (reais ou mock)
  List<ProductModel> _getSourceProducts() {
    if (_allProducts.isNotEmpty) return _allProducts;
    return mockProducts;
  }

  Future<void> _refreshSearch() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {});
  }

  /// Carrega termos de pesquisa populares do Supabase (fallback local)
  Future<void> _loadPopularSearches() async {
    try {
      final rows = await ProductAnalyticsService.getPopularSearchTerms(limit: 9);
      final terms = rows
          .map((e) => (e['search_term'] as String?)?.trim())
          .where((e) => e != null && e!.isNotEmpty)
          .cast<String>()
          .toList();

      if (terms.isNotEmpty && mounted) {
        setState(() {
          _popularSearches = terms;
        });
        return;
      }
    } catch (_) {
      // Se der erro, cai no fallback abaixo
    }

    // Fallback: usa nomes de produtos locais
    final base = _getSourceProducts();
    if (base.isNotEmpty && mounted) {
      final local = base.map((e) => e.name).toSet().take(9).toList();
      setState(() {
        _popularSearches = local;
      });
    }
  }

  /// Recalcula produtos recomendados com base nas interações do usuário
  void _updateRecommendations() {
    final base = _getSourceProducts();
    if (base.isEmpty) {
      _recommendedForUser = [];
      return;
    }

    final interactedIds = ProductAnalyticsService.userInteractedProductIds;

    // Se não houver histórico, recomenda alguns produtos aleatórios
    if (interactedIds.isEmpty) {
      final copy = List<ProductModel>.from(base)..shuffle();
      _recommendedForUser = copy.take(3).toList();
      return;
    }

    final interactedProducts = base
        .where((p) => interactedIds.contains(p.id))
        .toList();

    // Se não achar pelo ID (inconsistência), volta pro aleatório
    if (interactedProducts.isEmpty) {
      final copy = List<ProductModel>.from(base)..shuffle();
      _recommendedForUser = copy.take(3).toList();
      return;
    }

    final categories = interactedProducts
        .map((p) => p.category.toLowerCase())
        .toSet();

    final similar = base.where((p) =>
      !interactedIds.contains(p.id) &&
      categories.contains(p.category.toLowerCase()),
    );

    final combined = [
      ...interactedProducts,
      ...similar,
    ];

    combined.shuffle();
    _recommendedForUser = combined.take(3).toList();
  }

  List<String> _getSuggestions() {
    if (_currentQuery.isEmpty) return [];

    final base = _getSourceProducts();
    if (base.isEmpty) return [];

    final suggestions = base
        .where(
          (p) => p.name.toLowerCase().contains(_currentQuery.toLowerCase()),
        )
        .map((p) => p.name)
        .toSet()
        .take(9)
        .toList();

    return suggestions;
  }

  /// 🔥 Gera textos recomendados (nomes de produtos em texto)
  List<String> _getRecommendedTexts() {
    if (_popularSearches.isNotEmpty) return _popularSearches;

    final base = _getSourceProducts();
    if (base.isEmpty) return [];
    return base.map((e) => e.name).toSet().take(9).toList();
  }

  /// 🔥 Produtos recomendados visualmente
  List<ProductModel> _getRecommendedProducts() {
    if (_recommendedForUser.isNotEmpty) {
      return _recommendedForUser;
    }

    final base = _getSourceProducts();
    if (base.isEmpty) return [];

    final products = base.toList()..shuffle();
    return products.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final base = _getSourceProducts();
    final suggestions = _getSuggestions();
    final results = base.where((product) {
      return product.name.toLowerCase().contains(_currentQuery.toLowerCase());
    }).toList();

    final recommendedTexts = _getRecommendedTexts();
    final recommendedProducts = _getRecommendedProducts();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(Icons.search, color: Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Procure produtos baratos...',
                    hintStyle: TextStyle(fontSize: 15, color: Colors.grey[600]),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _currentQuery = value;
                      _showResults = false;
                    });
                  },
                  onSubmitted: (value) {
                    _performSearch(value);
                  },
                ),
              ),
              if (_currentQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _currentQuery = '';
                      _showResults = false;
                    });
                  },
                  child: Icon(Icons.close, size: 20, color: Colors.grey[600]),
                ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
      body: _currentQuery.isEmpty
          ? _buildRecommendedBlock(recommendedTexts, recommendedProducts)
          : _showResults
          ? _buildResults(results)
          : _buildSuggestions(suggestions),
    );
  }

  /// 🔥 BLOCO COMPLETO DE RECOMENDAÇÕES
  Widget _buildRecommendedBlock(List<String> texts, List<ProductModel> products) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(14),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                const Text(
                  '  Pesquisas populares',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                // 🟣 Lista de textos recomendados
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: texts
                      .map(
                        (t) => GestureDetector(
                          onTap: () {
                            _searchController.text = t;
                            _performSearch(t);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Text(
                              t,
                              style: TextStyle(
                                color: Colors.deepPurple.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),

                const SizedBox(height: 22),

                const Text(
                  '  Recomendados para você',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // Grid dinâmico reutilizando o mesmo componente da home
        DynamicProductGrid(products: products),

        const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
      ],
    );
  }

  /// 🟡 sugestões ao digitar
  Widget _buildSuggestions(List<String> suggestions) {
    if (suggestions.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma sugestão encontrada',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (_, index) {
        final suggestion = suggestions[index];
        return ListTile(
          leading: const Icon(Icons.search, color: Colors.grey),
          title: Text(suggestion),
          onTap: () {
            _searchController.text = suggestion;
            _performSearch(suggestion);
          },
        );
      },
    );
  }

  /// 🟢 resultados finais
  Widget _buildResults(List<ProductModel> results) {
    if (results.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum produto encontrado',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final total = results.length;
    final clampedVisible = _visibleResultsCount.clamp(0, total) as int;
    final visible = total == 0
        ? <ProductModel>[]
        : results.take(clampedVisible).toList();
    final isLoadingMore = _isLoadingMoreResults;

    return RefreshIndicator(
      onRefresh: _refreshSearch,
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (_isLoading || !_showResults || isLoadingMore) return false;
          if (scrollInfo.metrics.axis != Axis.vertical) return false;

          if (scrollInfo.metrics.extentAfter < 200 && total > clampedVisible) {
            setState(() {
              _isLoadingMoreResults = true;
            });

            Future.delayed(_loadMoreDelay, () {
              if (!mounted) return;
              setState(() {
                final next = clampedVisible + _pageSize;
                _visibleResultsCount =
                    next > total ? total : next;
                _isLoadingMoreResults = false;
              });
            });
          }
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Carregando mais produtos...',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            DynamicProductGrid(products: visible),
          ],
        ),
      ),
    );
  }
}
