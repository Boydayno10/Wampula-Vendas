import 'package:flutter/material.dart';

import '../../data/mock_products.dart';
import '../../models/product_model.dart';
import '../../services/seller_product_service.dart';
import '../../services/category_service.dart';
import '../../widgets/category_bar.dart';
import '../../widgets/home_banner.dart';
import '../../widgets/product_card.dart';
import '../../widgets/subcategory_selector.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/central_combos_widget.dart';
import '../../widgets/you_might_like_widget.dart';
import '../../widgets/dynamic_product_grid.dart';
import '../../services/product_analytics_service.dart';
import '../cart/cart_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';
import '../../utils/auth_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Filtra produtos econômicos e populares para o Centro de Economia
  List<ProductModel> _getEconomicPopularProducts(List<ProductModel> products) {
    // Simulação: filtra produtos econômicos (preço baixo)
    // e com bom desempenho (vendas/cliques altos).
    // Substitua por lógica real usando analytics do Supabase.
    final thresholdPrice = 100; // Ex.: máximo para ser considerado econômico
    final thresholdSales = 5; // Ex.: mínimo de vendas
    final thresholdClicks = 15; // Ex.: mínimo de cliques/popularidade
    return products
        .where(
          (p) =>
              p.price <= thresholdPrice &&
              (p.soldCount >= thresholdSales ||
                  p.popularity >= thresholdClicks),
        )
        .toList();
  }

  // Retorna produtos "você vai gostar" embaralhados (cacheia para manter posições fixas)
  List<ProductModel> _getYouMightLikeProducts(
    int pageIndex,
    List<ProductModel> products,
  ) {
    if (_cachedYouMightLikeProducts.containsKey(pageIndex)) {
      return _cachedYouMightLikeProducts[pageIndex]!;
    }
    final shuffled = List<ProductModel>.from(products)..shuffle();
    _cachedYouMightLikeProducts[pageIndex] = shuffled;
    return shuffled;
  }

  // Retorna produtos "central de combos" que o usuário já interagiu (view/click) e tem desconto
  List<ProductModel> _getCentralCombosProducts(
    int pageIndex,
    List<ProductModel> products,
  ) {
    if (_cachedCentralCombosProducts.containsKey(pageIndex)) {
      return _cachedCentralCombosProducts[pageIndex]!;
    }
    // IDs de produtos que o usuário já interagiu (view/click/search)
    final interactedIds = ProductAnalyticsService.userInteractedProductIds;

    // Produtos com desconto
    final discounted = products.where((p) => p.oldPrice != null).toList();

    // Se ainda não houve interação, apenas retorna produtos em promoção
    if (interactedIds.isEmpty) {
      discounted.shuffle();
      _cachedCentralCombosProducts[pageIndex] = discounted;
      return discounted;
    }

    // Produtos que o usuário já interagiu
    final interactedProducts = discounted
        .where((p) => interactedIds.contains(p.id))
        .toList();

    // Se existir pelo menos um, também traz "semelhantes" pela categoria
    final interactedCategories = interactedProducts
        .map((p) => p.category.toLowerCase())
        .toSet();

    final similarProducts = discounted.where(
      (p) =>
          !interactedIds.contains(p.id) &&
          interactedCategories.contains(p.category.toLowerCase()),
    );

    final filtered = [...interactedProducts, ...similarProducts];
    filtered.shuffle();
    _cachedCentralCombosProducts[pageIndex] = filtered;
    return filtered;
  }

  int _currentIndex = 0;
  int _selectedCategory = 0;
  String _searchQuery = '';
  late PageController _pageController;
  List<ProductModel> _allProducts = [];
  List<ProductModel> _featuredProducts = [];
  Map<int, List<ProductModel>> _cachedFilteredProducts =
      {}; // Cache dos produtos filtrados
  Map<int, List<ProductModel>> _cachedYouMightLikeProducts =
      {}; // Cache dos produtos "você vai gostar"
  Map<int, List<ProductModel>> _cachedCentralCombosProducts =
      {}; // Cache dos produtos "central de combos"
    // Quantidade de produtos visíveis por página (scroll infinito: +8 por vez)
    Map<int, int> _visibleProductCounts = {};
    // Estado de carregamento leve por página (spinner depois de "Vais gramar")
    Map<int, bool> _isLoadingMore = {};
  double _titleOpacity = 1.0;
  final ScrollController _nestedScrollController = ScrollController();
  double _lastScrollOffset = 0.0;
  bool _isScrollingUp = false;
  bool _isLoading = true;
  bool _isCategoriesLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedCategory);
    _loadCategoriesAndProducts();
  }

  Future<void> _loadCategoriesAndProducts() async {
    setState(() {
      _isLoading = true;
      _isCategoriesLoading = true;
    });

    // Carregar categorias primeiro
    await CategoryService.loadCategories();

    // Atualizar estado quando categorias estiverem carregadas
    if (mounted) {
      setState(() => _isCategoriesLoading = false);
    }

    // Depois carregar produtos
    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await SellerProductService.getProductModels();

      // Pré-carregar imagens dos produtos antes de exibir
      if (products.isNotEmpty && mounted) {
        await _precacheProductImages(products);
      }

      if (mounted) {
        setState(() {
          _allProducts = products;
          _featuredProducts = _selectRandomFeaturedProducts();
          _cachedFilteredProducts.clear(); // Limpar cache ao recarregar
          _cachedYouMightLikeProducts.clear(); // Limpar cache
          _cachedCentralCombosProducts.clear(); // Limpar cache
          _visibleProductCounts.clear(); // Reinicia paginação de produtos
          _isLoadingMore.clear(); // Limpa estado de carregamento leve
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erro ao carregar produtos: $e');
      // Se falhar, usa produtos mock
      if (mounted) {
        setState(() {
          _allProducts = mockProducts;
          _cachedYouMightLikeProducts.clear(); // Limpar cache
          _cachedCentralCombosProducts.clear(); // Limpar cache
          _featuredProducts = _selectRandomFeaturedProducts();
          _cachedFilteredProducts.clear(); // Limpar cache
          _visibleProductCounts.clear(); // Reinicia paginação de produtos
          _isLoadingMore.clear(); // Limpa estado de carregamento leve
          _isLoading = false;
        });
      }
    }
  }

  /// Pré-carrega as imagens dos produtos para evitar loading visual
  Future<void> _precacheProductImages(List<ProductModel> products) async {
    final imagesToCache = <String>{};

    // Pegar primeira imagem de cada produto (máximo 20 para não demorar muito)
    for (var product in products.take(20)) {
      final imageUrl = (product.images != null && product.images!.isNotEmpty)
          ? product.images!.first
          : product.image;

      if (imageUrl.startsWith('http')) {
        imagesToCache.add(imageUrl);
      }
    }

    // Pré-carregar imagens em paralelo
    await Future.wait(
      imagesToCache.map((url) => precacheImage(NetworkImage(url), context)),
      eagerError: false, // Continua mesmo se algumas imagens falharem
    );
  }

  @override
  void dispose() {
    _nestedScrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshHome() async {
    await _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: (_currentIndex == 1 || _currentIndex == 2 || _currentIndex == 3)
          ? null
          : AppBar(
              title: Stack(
                children: [
                  // Título que desaparece
                  AnimatedOpacity(
                    opacity: _titleOpacity,
                    duration: const Duration(milliseconds: 100),
                    child: Text(
                      _currentIndex == 3 ? 'Perfil' : 'Wampula Vendas',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Barra de pesquisa que aparece
                  AnimatedOpacity(
                    opacity: _currentIndex == 0 ? (1.0 - _titleOpacity) : 0.0,
                    duration: const Duration(milliseconds: 100),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _currentIndex = 1);
                      },
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Icon(
                              Icons.search,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Procure produtos baratos...',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_none),
                  onPressed: () {
                    AuthHelper.executeWithAuth(context, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    }, message: 'Faça login para ver suas notificações.');
                  },
                ),
              ],
            ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          // Se clicar no ícone Home (índice 0) e já estiver na Home, recarregar
          if (index == 0 && _currentIndex == 0) {
            _loadProducts();
            return;
          }

          // Verifica se precisa de autenticação para as abas restritas
          if (index == 2 || index == 3) {
            // Carrinho ou Perfil
            if (!AuthHelper.requireAuth(
              context,
              message: index == 2
                  ? 'Faça login para acessar seu carrinho.'
                  : 'Faça login para acessar seu perfil.',
            )) {
              return; // Não muda de aba se não autenticado
            }
          }
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Início',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Pesquisa'),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            label: 'Carrinho',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return IndexedStack(
      index: _currentIndex,
      children: [
        // Aba Home (índice 0)
        RefreshIndicator(
          onRefresh: _refreshHome,
          child: NotificationListener<ScrollNotification>(
            onNotification: (scrollInfo) {
              // Calcula a opacidade baseada no scroll apenas quando está realmente rolando
              if (scrollInfo.metrics.axis == Axis.vertical &&
                  scrollInfo is ScrollUpdateNotification) {
                final scrollOffset = scrollInfo.metrics.pixels;
                final maxScroll = 240.0; // Altura do banner

                // Detecta direção do scroll
                _isScrollingUp = scrollOffset > _lastScrollOffset;
                _lastScrollOffset = scrollOffset;

                // Calcula a nova opacidade
                final newOpacity = (1.0 - (scrollOffset / maxScroll)).clamp(
                  0.0,
                  1.0,
                );

                // Só atualiza se a opacidade mudou significativamente
                if ((_titleOpacity - newOpacity).abs() > 0.01) {
                  setState(() {
                    _titleOpacity = newOpacity;
                  });
                }
              }

              // Auto-snap quando o usuário parar de scrollar
              if (scrollInfo is ScrollEndNotification) {
                final scrollOffset = scrollInfo.metrics.pixels;
                final maxScroll = 240.0;

                // Se estiver na zona intermediária (entre 10% e 90% da transição)
                if (scrollOffset > maxScroll * 0.1 &&
                    scrollOffset < maxScroll * 0.9) {
                  double targetOffset;

                  // Se estava scrollando para cima, completa para cima (mostra search bar)
                  // Se estava scrollando para baixo, completa para baixo (mostra banner)
                  if (_isScrollingUp) {
                    targetOffset = maxScroll; // Completa para cima
                  } else {
                    targetOffset =
                        0.0; // Volta para baixo (mostra banner completo)
                  }

                  // Anima suavemente para o target usando o controller
                  _nestedScrollController.animateTo(
                    targetOffset,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                }
              }

              return false;
            },
            child: NestedScrollView(
              controller: _nestedScrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  /// Banner colapsável global (mesmo para todas as categorias)
                  SliverAppBar(
                    expandedHeight: 240,
                    pinned: false,
                    floating: false,
                    snap: false,
                    flexibleSpace: FlexibleSpaceBar(
                      background: HomeBanner(
                        featuredProducts: _featuredProducts,
                      ),
                    ),
                  ),

                  /// Categorias fixas
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _CategoryHeaderDelegate(
                      selectedIndex: _selectedCategory,
                      // Mantém skeleton da barra de categorias enquanto
                      // os produtos ainda estão carregando para tudo aparecer junto
                      isLoading: _isLoading,
                      onSelect: (index) {
                        setState(() {
                          _selectedCategory = index;
                          _pageController.jumpToPage(index);
                        });
                      },
                    ),
                  ),
                ];
              },
              body: PageView.builder(
                controller: _pageController,
                // Garante ao menos 1 página mesmo enquanto categorias carregam,
                // para que os skeletons de subcategorias e Central de Combos
                // apareçam junto com o banner e a barra de categorias.
                itemCount: CategoryService.categories.isEmpty
                    ? 1
                    : CategoryService.categories.length,
                onPageChanged: (page) {
                  setState(() => _selectedCategory = page);
                },
                itemBuilder: (_, pageIndex) {
                  // Transição suave entre skeleton e conteúdo
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.02),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: _buildProductContent(pageIndex),
                  );
                },
              ),
            ),
          ),
        ),

        // Aba Pesquisa (índice 1)
        SearchScreen(searchQuery: _searchQuery),

        // Aba Carrinho (índice 2)
        CartScreen(onBackToHome: () => setState(() => _currentIndex = 0)),

        // Aba Perfil (índice 3)
        const ProfileScreen(),
      ],
    );
  }

  Widget _buildProductContent(int pageIndex) {
    final products = _filteredByCategory(pageIndex);
    // Sempre exibe produtos usando DynamicProductGrid, inclusive para categorias dinâmicas
    // Exemplo: se a categoria for "Central de Economia", filtra produtos econômicos e populares
    final isEconomyCenter =
        CategoryService.categories.isNotEmpty &&
        CategoryService.categories[pageIndex].name.toLowerCase().contains(
          'economia',
        );
    final economyProducts = isEconomyCenter
        ? _getEconomicPopularProducts(products)
        : products;

    // Quantidade de produtos exibidos nesta página (scroll infinito)
    final totalProducts = economyProducts.length;
    final initialCount = 8;
    final currentVisible = _visibleProductCounts[pageIndex] ?? initialCount;
    final clampedVisible = currentVisible.clamp(0, totalProducts) as int;
    final visibleProducts =
        totalProducts == 0 ? <ProductModel>[] : economyProducts.take(clampedVisible).toList();

    final isLoadingMore = _isLoadingMore[pageIndex] ?? false;

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (_isLoading || isLoadingMore) return false;
        if (scrollInfo.metrics.axis != Axis.vertical) return false;

        // Quando chegar perto do final, carrega mais 8 produtos
        if (scrollInfo.metrics.extentAfter < 200 && totalProducts > clampedVisible) {
          setState(() {
            _isLoadingMore[pageIndex] = true;
          });

          // Simula um carregamento leve e perceptível antes de mostrar mais 8 produtos
          Future.delayed(const Duration(milliseconds: 900), () {
            if (!mounted) return;
            setState(() {
              final next = clampedVisible + 8;
              _visibleProductCounts[pageIndex] =
                  next > totalProducts ? totalProducts : next;
              _isLoadingMore[pageIndex] = false;
            });
          });
        }
        return false;
      },
      child: CustomScrollView(
        key: ValueKey('products_$pageIndex'),
        slivers: [
        /// Espaçamento no topo
        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        /// Subcategorias
        SliverToBoxAdapter(
          child: _isLoading
              // Skeleton enquanto os produtos/categorias ainda estão carregando
              ? const SubcategoryRowSkeleton(itemCount: 3)
              : SubCategorySelector(
                  category: CategoryService.categories.isNotEmpty
                      ? CategoryService.categories[pageIndex].name
                      : 'Início',
                  allProducts:
                      _allProducts.isEmpty ? mockProducts : _allProducts,
                ),
        ),

        /// Central de Combos (apenas na categoria Início)
        if (pageIndex == 0)
          SliverToBoxAdapter(
            child: _isLoading
                ? const CentralCombosSkeleton()
                : CentralCombosWidget(
                    products: _getCentralCombosProducts(pageIndex, products),
                  ),
          ),

        /// Espaçamento antes do grid dinâmico
        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        /// Texto central antes dos produtos (todas as categorias)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Center(
              child: Text('Vais gramar', style: TextStyle(fontSize: 14)),
            ),
          ),
        ),

        /// Loader leve abaixo de "Vais gramar" quando estiver carregando mais produtos
        if (!_isLoading && isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: 8),
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

        /// Grid dinâmico com produtos filtrados
        _isLoading
            ? const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SkeletonLoader(itemCount: 6),
                ),
              )
            : DynamicProductGrid(products: visibleProducts),

        /// Espaçamento final
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
      ),
    );
  }

  List<ProductModel> _filteredByCategory(int index) {
    // Se está carregando, retornar lista vazia (skeleton será mostrado)
    if (_isLoading) {
      return [];
    }

    // Se já temos em cache, retornar do cache
    if (_cachedFilteredProducts.containsKey(index)) {
      return _cachedFilteredProducts[index]!;
    }

    final products = _allProducts.isEmpty ? mockProducts : _allProducts;
    final categories = CategoryService.categories;

    // Se não há categorias ainda, retornar todos os produtos
    if (categories.isEmpty) {
      return products;
    }

    List<ProductModel> filtered;
    if (index == 0) {
      // Primeira categoria (Início) mostra todos os produtos embaralhados
      final list = List<ProductModel>.from(products);
      list.shuffle();
      filtered = list;
    } else {
      // Outras categorias filtram por nome da categoria
      final categoryName = categories[index].name;
      filtered = products
          .where((p) => p.category.toLowerCase() == categoryName.toLowerCase())
          .toList();
    }

    // Guardar no cache
    _cachedFilteredProducts[index] = filtered;
    return filtered;
  }

  ProductModel? _pickPopular(List<ProductModel> items) {
    if (items.isEmpty) return null;
    final copy = List<ProductModel>.from(items)
      ..sort((a, b) => b.popularity.compareTo(a.popularity));
    return copy.first;
  }

  ProductModel? _pickBought(List<ProductModel> items) {
    if (items.isEmpty) return null;
    final copy = List<ProductModel>.from(items)
      ..sort((a, b) => b.soldCount.compareTo(a.soldCount));
    return copy.first;
  }

  ProductModel? _pickCheap(List<ProductModel> items) {
    if (items.isEmpty) return null;
    final copy = List<ProductModel>.from(items)
      ..sort((a, b) => a.price.compareTo(b.price));
    return copy.first;
  }

  List<ProductModel> _selectRandomFeaturedProducts() {
    final products = _allProducts.isEmpty ? mockProducts : _allProducts;
    final shuffled = List<ProductModel>.from(products)..shuffle();
    return shuffled.take(3).toList();
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final int selectedIndex;
  final Function(int) onSelect;
  final bool isLoading;

  _CategoryHeaderDelegate({
    required this.selectedIndex,
    required this.onSelect,
    required this.isLoading,
  });

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return CategoryBar(
      selectedIndex: selectedIndex,
      onSelect: onSelect,
      isLoading: isLoading,
    );
  }

  @override
  bool shouldRebuild(_CategoryHeaderDelegate oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.isLoading != isLoading;
  }
}
