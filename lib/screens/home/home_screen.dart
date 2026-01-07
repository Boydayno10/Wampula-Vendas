import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/mock_products.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
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
import '../../widgets/notification_bell.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';
import '../client/minhas_publicacoes_screen.dart';
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
    // Se a lista filtrada da página estiver vazia, usa todos os produtos
    // carregados (ou mock) como base, para evitar o carrossel vazio
    var baseProducts = products;
    if (baseProducts.isEmpty) {
      baseProducts = _allProducts.isNotEmpty ? _allProducts : mockProducts;
    }

    // Se já temos no cache e a lista não está vazia, reutiliza
    if (_cachedCentralCombosProducts.containsKey(pageIndex)) {
      final cached = _cachedCentralCombosProducts[pageIndex]!;
      if (cached.isNotEmpty) {
        return cached;
      }
      // Se o cache estiver vazio (caso antigo), vamos recalcular abaixo
    }

    // IDs de produtos que o usuário já interagiu (view/click/search)
    final interactedIds = ProductAnalyticsService.userInteractedProductIds;

    // Produtos com desconto real (oldPrice > price)
    final discounted = baseProducts
      .where((p) => p.oldPrice != null && p.oldPrice! > p.price)
      .toList();

    List<ProductModel> result;

    if (discounted.isEmpty) {
      // Sem produtos em promoção, a Central de Combos fica vazia
      _cachedCentralCombosProducts[pageIndex] = const [];
      return const [];
    } else if (interactedIds.isEmpty) {
      // Se ainda não houve interação, apenas retorna produtos em promoção embaralhados
      result = List<ProductModel>.from(discounted);
    } else {
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

      result = [...interactedProducts, ...similarProducts];

      // Fallback: se não encontrar nenhum produto personalizado, volta para todos com desconto
      if (result.isEmpty) {
        result = List<ProductModel>.from(discounted);
      }
    }

    // Embaralha a lista para variar a ordem de exibição
    result.shuffle();

    // Não força quantidade mínima: 7 é apenas LIMITE, não obrigação.
    // Se só houver 1 combo elegível, o carrossel mostrará apenas 1.
    _cachedCentralCombosProducts[pageIndex] = result;
    return result;
  }

  int _currentIndex = 0;
  int _selectedCategory = 0;
  String _searchQuery = '';
  late PageController _pageController;
  List<ProductModel> _allProducts = [];
  List<ProductModel> _featuredProducts = [];
    List<CategoryModel> _visibleCategories = [];
    Map<int, List<ProductModel>> _cachedFilteredProducts =
      {}; // Cache dos produtos filtrados
    Map<int, List<ProductModel>> _cachedYouMightLikeProducts =
      {}; // Cache dos produtos "você vai gostar"
    Map<int, List<ProductModel>> _cachedCentralCombosProducts =
      {}; // Cache dos produtos "central de combos"
  // Quantidade de produtos visíveis por página (scroll infinito: +8 por vez)
  Map<int, int> _visibleProductCounts = {};
  // Estado de carregamento leve por página (spinner depois do texto central)
  Map<int, bool> _isLoadingMore = {};
  // Skeleton rápido ao alternar entre categorias/páginas
  Map<int, bool> _isPageSkeletonVisible = {};
  double _titleOpacity = 1.0;
  final ScrollController _nestedScrollController = ScrollController();
  double _lastScrollOffset = 0.0;
  bool _isScrollingUp = false;
  bool _isLoading = true;
  bool _isCategoriesLoading = true;

  /// Categorias que serão exibidas na Home (filtra categorias sem produtos)
  List<CategoryModel> get _categoriesForHome {
    // Se já calculamos categorias visíveis, usar essa lista
    if (_visibleCategories.isNotEmpty) {
      return _visibleCategories;
    }
    // Fallback: usa todas as categorias carregadas
    return CategoryService.categories;
  }

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
      // Primeiro, tenta carregar produtos em destaque definidos pelo admin
      List<ProductModel> featuredFromAdmin = [];
      if (products.isNotEmpty) {
        featuredFromAdmin = await _loadAdminFeaturedProducts(products);

        // Pré-carregar imagens dos produtos antes de exibir
        if (mounted) {
          await _precacheProductImages(products);
        }
      }

      if (mounted) {
        setState(() {
          _allProducts = products;
          _featuredProducts = featuredFromAdmin.isNotEmpty
              ? featuredFromAdmin
              : _selectRandomFeaturedProducts();
          _cachedFilteredProducts.clear(); // Limpar cache ao recarregar
          _cachedYouMightLikeProducts.clear(); // Limpar cache
          _cachedCentralCombosProducts.clear(); // Limpar cache
          _visibleProductCounts.clear(); // Reinicia paginação de produtos
          _isLoadingMore.clear(); // Limpa estado de carregamento leve
          _isPageSkeletonVisible.clear(); // Limpa skeleton por página
          _updateVisibleCategories(); // Atualiza categorias que aparecem na Home
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
          _isPageSkeletonVisible.clear(); // Limpa skeleton por página
          _updateVisibleCategories(); // Atualiza categorias visíveis mesmo com mock
          _isLoading = false;
        });
      }
    }
  }

  /// Atualiza lista de categorias exibidas na Home, ocultando as que não têm produtos
  void _updateVisibleCategories() {
    final allCategories = CategoryService.categories;

    if (allCategories.isEmpty) {
      _visibleCategories = [];
      _selectedCategory = 0;
      return;
    }

    final products = _allProducts;

    // Se não houver produtos, mantém apenas a categoria "Início" (ou a primeira)
    if (products.isEmpty) {
      final inicio = allCategories.firstWhere(
        (c) =>
            c.name.toLowerCase() == 'início' ||
            c.name.toLowerCase() == 'inicio',
        orElse: () => allCategories.first,
      );
      _visibleCategories = [inicio];
      _selectedCategory = 0;
      return;
    }

    final productCategories = products
        .map((p) => p.category.toLowerCase())
        .toSet();

    final filtered = <CategoryModel>[];
    for (final cat in allCategories) {
      final nameLower = cat.name.toLowerCase();

      // "Início" sempre aparece
      if (nameLower == 'início' || nameLower == 'inicio') {
        filtered.add(cat);
        continue;
      }

      // Outras categorias só aparecem se tiverem produtos
      if (productCategories.contains(nameLower)) {
        filtered.add(cat);
      }
    }

    _visibleCategories = filtered;

    // Garante que o índice selecionado é válido
    if (_selectedCategory >= _visibleCategories.length) {
      _selectedCategory = 0;
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
      appBar:
          (_currentIndex == 1 ||
              _currentIndex == 2 ||
              _currentIndex == 3 ||
              _currentIndex == 4)
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.white,
              title: Stack(
                children: [
                  // Título que desaparece
                  AnimatedOpacity(
                    opacity: _titleOpacity,
                    duration: const Duration(milliseconds: 100),
                    child: _currentIndex == 4
                        ? const Text(
                            'Perfil',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          )
                        : RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.black,
                              ),
                              children: const [
                                TextSpan(
                                  text: 'W',
                                  style: TextStyle(
                                    color: Colors.black,
                                  ),
                                ),
                                TextSpan(text: 'ampula '),
                                TextSpan(
                                  text: 'V',
                                  style: TextStyle(
                                    color: Colors.black,
                                  ),
                                ),
                                TextSpan(text: 'endas'),
                              ],
                            ),
                          ),
                  ),
                  // Barra de pesquisa que aparece
                  AnimatedOpacity(
                    opacity: _currentIndex == 0 ? (1.0 - _titleOpacity) : 0.0,
                    duration: const Duration(milliseconds: 100),
                    child: Row(
                      children: [
                        SizedBox(
                          height: 40,
                          width: 80,
                          child: Image.asset(
                            'assets/images/wampulavendas.png',
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
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
                  ),
                ],
              ),
              actions: [NotificationBell(rootContext: context)],
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

          // Verifica se precisa de autenticação apenas para a aba "Publicar" (índice 2)
          // Carrinho (3) e Perfil (4) ficam sempre acessíveis, mesmo sem login
          if (index == 2) {
            const message = 'Faça login para gerir suas publicações.';
            if (!AuthHelper.requireAuth(context, message: message)) {
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
            icon: _CenterPublishIcon(),
            label: 'Publicar',
          ),
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
                      categories: _categoriesForHome,
                      // Mantém skeleton da barra de categorias enquanto
                      // os produtos ainda estão carregando para tudo aparecer junto
                      isLoading: _isLoading,
                      onSelect: (index) {
                        setState(() {
                          _selectedCategory = index;
                          _pageController.jumpToPage(index);
                          _isPageSkeletonVisible[index] = true;
                        });

                        // Exibe um skeleton rápido para os produtos da nova aba
                        Future.delayed(const Duration(milliseconds: 350), () {
                          if (!mounted) return;
                          setState(() {
                            _isPageSkeletonVisible[index] = false;
                          });
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
                itemCount: _categoriesForHome.isEmpty
                    ? 1
                    : _categoriesForHome.length,
                onPageChanged: (page) {
                  setState(() {
                    _selectedCategory = page;
                    _isPageSkeletonVisible[page] = true;
                  });

                  Future.delayed(const Duration(milliseconds: 350), () {
                    if (!mounted) return;
                    setState(() {
                      _isPageSkeletonVisible[page] = false;
                    });
                  });
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
                          position:
                              Tween<Offset>(
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

        // Aba Minhas Publicações (índice 2)
        const MinhasPublicacoesScreen(),

        // Aba Carrinho (índice 3)
        CartScreen(onBackToHome: () => setState(() => _currentIndex = 0)),

        // Aba Perfil (índice 4)
        const ProfileScreen(),
      ],
    );
  }

  Widget _buildProductContent(int pageIndex) {
    final products = _filteredByCategory(pageIndex);
    // Sempre exibe produtos usando DynamicProductGrid, inclusive para categorias dinâmicas
    // Exemplo: se a categoria for "Central de Economia", filtra produtos econômicos e populares
    final categories = _categoriesForHome;

    final isEconomyCenter =
        categories.isNotEmpty &&
        categories[pageIndex].name.toLowerCase().contains('economia');
    final economyProducts = isEconomyCenter
        ? _getEconomicPopularProducts(products)
        : products;

    // Quantidade de produtos exibidos nesta página (scroll infinito)
    final totalProducts = economyProducts.length;
    final initialCount = 8;
    final currentVisible = _visibleProductCounts[pageIndex] ?? initialCount;
    final clampedVisible = currentVisible.clamp(0, totalProducts) as int;
    final visibleProducts = totalProducts == 0
        ? <ProductModel>[]
        : economyProducts.take(clampedVisible).toList();

    final isLoadingMore = _isLoadingMore[pageIndex] ?? false;
    final pageSkeleton = _isPageSkeletonVisible[pageIndex] ?? false;

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (_isLoading || isLoadingMore) return false;
        if (scrollInfo.metrics.axis != Axis.vertical) return false;

        // Quando chegar perto do final, carrega mais 8 produtos
        if (scrollInfo.metrics.extentAfter < 200 &&
            totalProducts > clampedVisible) {
          setState(() {
            _isLoadingMore[pageIndex] = true;
          });

          // Simula um carregamento leve e perceptível antes de mostrar mais 8 produtos
          Future.delayed(const Duration(milliseconds: 900), () {
            if (!mounted) return;
            setState(() {
              final next = clampedVisible + 8;
              _visibleProductCounts[pageIndex] = next > totalProducts
                  ? totalProducts
                  : next;
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

          /// Cabeçalho "Super ofertas" colado nas subcategorias
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(left: 16, right: 16, bottom: 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Super Ofertas',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.deepPurple,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    SizedBox(
                      width: 36,
                      height: 3,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          /// Subcategorias
          SliverToBoxAdapter(
            child: _isLoading
                // Skeleton apenas enquanto os dados ainda estão carregando
                ? const SubcategoryRowSkeleton(itemCount: 3)
                : SubCategorySelector(
                    category: categories.isNotEmpty
                        ? categories[pageIndex].name
                        : 'Início',
                    allProducts: _allProducts.isEmpty
                        ? mockProducts
                        : _allProducts,
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
                child: Text(
                  'Ofertas selecionadas para você',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),

          /// Loader leve abaixo do texto central quando estiver carregando mais produtos
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

          /// Grid dinâmico com produtos filtrados (com skeleton por página)
          (_isLoading || pageSkeleton)
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
    final categories = _categoriesForHome;

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

  /// Carrega produtos em destaque definidos pelo admin na tabela `featured_banners`.
  /// Respeita a janela de tempo (start_at <= agora <= end_at) e limita a 3 itens.
  Future<List<ProductModel>> _loadAdminFeaturedProducts(
    List<ProductModel> baseProducts,
  ) async {
    try {
      final client = Supabase.instance.client;
      // Usa horário local para comparar com start_at/end_at, já que o
      // admin configura as datas pelo horário da interface.
      final now = DateTime.now();

      final response = await client
          .from('featured_banners')
          .select('product_id, position, start_at, end_at, active')
          .eq('active', true)
          .order('position', ascending: true);

      if (response is! List || response.isEmpty) {
        return [];
      }

      // Lista de IDs em ordem de prioridade:
      // 1. Banners com janela de tempo válida (start_at <= agora <= end_at)
      // 2. Se não houver nenhum ativo pela janela, banners "pendentes"
      //    (sem horário definido: start_at e end_at nulos).
      final activeIds = <String>[];
      final pendingIds = <String>[];

      for (final row in response) {
        final productId = row['product_id']?.toString();
        if (productId == null || productId.isEmpty) continue;

        final startRaw = row['start_at'];
        final endRaw = row['end_at'];

        if (startRaw is String && startRaw.isNotEmpty &&
            endRaw is String && endRaw.isNotEmpty) {
          // Banner com janela definida: só entra se estiver dentro do período.
          try {
            final start = DateTime.parse(startRaw);
            final end = DateTime.parse(endRaw);
            final withinWindow = (start.isBefore(now) || start.isAtSameMomentAs(now)) &&
                (end.isAfter(now) || end.isAtSameMomentAs(now));
            if (withinWindow && !activeIds.contains(productId)) {
              activeIds.add(productId);
            }
          } catch (_) {
            // Se a data estiver inválida, simplesmente ignora este registro.
          }
        } else if ((startRaw == null || (startRaw is String && startRaw.isEmpty)) &&
            (endRaw == null || (endRaw is String && endRaw.isEmpty))) {
          // Banner pendente (sem datas): só usado como fallback quando não
          // houver nenhum com janela ativa.
          if (!pendingIds.contains(productId)) {
            pendingIds.add(productId);
          }
        }
      }

      final idsInOrder = activeIds.isNotEmpty ? activeIds : pendingIds;

      if (idsInOrder.isEmpty) return [];

      // Para banners configurados pelo admin, qualquer produto é elegível.
      // Se não houver bannerImage, o widget HomeBanner usa a imagem normal
      // do produto como fallback.
      final byId = <String, ProductModel>{
        for (final p in baseProducts) p.id: p,
      };
      final result = <ProductModel>[];

      for (final id in idsInOrder) {
        final p = byId[id];
        if (p != null) {
          result.add(p);
        }
        if (result.length >= 3) break;
      }

      return result;
    } catch (e) {
      // Em caso de erro, não quebra a Home; apenas volta para seleção automática.
      // ignore: avoid_print
      print('Erro ao carregar featured_banners: $e');
      return [];
    }
  }

  List<ProductModel> _selectRandomFeaturedProducts() {
    // Apenas produtos que realmente configuraram uma imagem de banner
    final products = _allProducts.isEmpty ? mockProducts : _allProducts;

    final bannerProducts = products
        .where((p) => p.bannerImage != null && p.bannerImage!.isNotEmpty)
        .toList();

    // Se não houver nenhum produto com banner, não exibe nada no carrossel
    if (bannerProducts.isEmpty) {
      return [];
    }

    final shuffled = List<ProductModel>.from(bannerProducts)..shuffle();
    return shuffled.take(3).toList();
  }
}

class _CenterPublishIcon extends StatelessWidget {
  const _CenterPublishIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.deepPurple,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(Icons.add, color: Colors.white, size: 22),
    );
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final int selectedIndex;
  final Function(int) onSelect;
  final bool isLoading;
  final List<CategoryModel> categories;

  _CategoryHeaderDelegate({
    required this.selectedIndex,
    required this.onSelect,
    required this.isLoading,
    required this.categories,
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
      categories: categories,
    );
  }

  @override
  bool shouldRebuild(_CategoryHeaderDelegate oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.isLoading != isLoading ||
        oldDelegate.categories != categories;
  }
}
