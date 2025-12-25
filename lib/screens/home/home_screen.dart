import 'package:flutter/material.dart';

import '../../data/mock_products.dart';
import '../../models/product_model.dart';
import '../../services/seller_product_service.dart';
import '../../widgets/category_bar.dart';
import '../../widgets/home_banner.dart';
import '../../widgets/product_card.dart';
import '../../widgets/subcategory_selector.dart';
import '../../widgets/skeleton_loader.dart';
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
  int _currentIndex = 0;
  int _selectedCategory = 0;
  String _searchQuery = '';
  late PageController _pageController;
  List<ProductModel> _allProducts = [];
  List<ProductModel> _featuredProducts = [];
  Map<int, List<ProductModel>> _cachedFilteredProducts = {}; // Cache dos produtos filtrados
  double _titleOpacity = 1.0;
  final ScrollController _nestedScrollController = ScrollController();
  double _lastScrollOffset = 0.0;
  bool _isScrollingUp = false;
  bool _isLoading = true;

  final List<String> categories = const [
    'Início',
    'Eletrónicos',
    'Família',
    'Alimentos',
    'Beleza',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedCategory);
    _loadProducts();
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
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erro ao carregar produtos: $e');
      // Se falhar, usa produtos mock
      if (mounted) {
        setState(() {
          _allProducts = mockProducts;
          _featuredProducts = _selectRandomFeaturedProducts();
          _cachedFilteredProducts.clear(); // Limpar cache
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
      appBar: _currentIndex == 2 || _currentIndex == 1
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
                    AuthHelper.executeWithAuth(
                      context,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                      },
                      message: 'Faça login para ver suas notificações.',
                    );
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
              if (scrollInfo.metrics.axis == Axis.vertical && scrollInfo is ScrollUpdateNotification) {
                final scrollOffset = scrollInfo.metrics.pixels;
                final maxScroll = 210.0; // Altura do banner
                
                // Detecta direção do scroll
                _isScrollingUp = scrollOffset > _lastScrollOffset;
                _lastScrollOffset = scrollOffset;
                
                // Calcula a nova opacidade
                final newOpacity = (1.0 - (scrollOffset / maxScroll)).clamp(0.0, 1.0);
                
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
                final maxScroll = 210.0;
                
                // Se estiver na zona intermediária (entre 10% e 90% da transição)
                if (scrollOffset > maxScroll * 0.1 && scrollOffset < maxScroll * 0.9) {
                  double targetOffset;
                  
                  // Se estava scrollando para cima, completa para cima (mostra search bar)
                  // Se estava scrollando para baixo, completa para baixo (mostra banner)
                  if (_isScrollingUp) {
                    targetOffset = maxScroll; // Completa para cima
                  } else {
                    targetOffset = 0.0; // Volta para baixo (mostra banner completo)
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
                  expandedHeight: 210,
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
              itemCount: categories.length,
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
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        )),
                        child: child,
                      ),
                    );
                  },
                  child: _isLoading
                      ? const Padding(
                          key: ValueKey('skeleton'),
                          padding: EdgeInsets.all(12.0),
                          child: SkeletonLoader(itemCount: 6),
                        )
                      : _buildProductContent(pageIndex),
                );
              },
            ),
          ),
        ),
        ),
        
        // Aba Pesquisa (índice 1)
        SearchScreen(searchQuery: _searchQuery),
        
        // Aba Carrinho (índice 2)
        CartScreen(
          onBackToHome: () => setState(() => _currentIndex = 0),
        ),
        
        // Aba Perfil (índice 3)
        const ProfileScreen(),
      ],
    );
  }

  Widget _buildProductContent(int pageIndex) {
    final products = _filteredByCategory(pageIndex);
    
    // Se não há produtos, mostra mensagem
    if (products.isEmpty) {
      return Center(
        key: const ValueKey('empty'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum produto encontrado',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    final topCount = products.length > 4 ? 4 : products.length;

    return CustomScrollView(
      key: ValueKey('products_$pageIndex'),
      slivers: [
        /// Espaçamento no topo para evitar que produtos fiquem escondidos
        const SliverToBoxAdapter(
          child: SizedBox(height: 12),
        ),
        
        /// Grid 1 (4 primeiros)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, i) => ProductCard(
                key: ValueKey('product_${products[i].id}'),
                product: products[i],
              ),
              childCount: topCount,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.65,
            ),
          ),
        ),

        /// Subcategorias
        SliverToBoxAdapter(
          child: SubCategorySelector(
            category: categories[pageIndex],
            popular: _pickPopular(products),
            bought: _pickBought(products),
            cheap: _pickCheap(products),
          ),
        ),

        /// Grid 2 (resto)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, i) => ProductCard(
                key: ValueKey('product_${products[topCount + i].id}'),
                product: products[topCount + i],
              ),
              childCount: products.length - topCount,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.65,
            ),
          ),
        ),
      ],
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
    
    List<ProductModel> filtered;
    if (index == 0) {
      final list = List<ProductModel>.from(products);
      list.shuffle();
      filtered = list;
    } else {
      filtered = products.where((p) => p.category == categories[index]).toList();
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

  _CategoryHeaderDelegate({
    required this.selectedIndex,
    required this.onSelect,
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
    return CategoryBar(selectedIndex: selectedIndex, onSelect: onSelect);
  }

  @override
  bool shouldRebuild(_CategoryHeaderDelegate oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex;
  }
}
