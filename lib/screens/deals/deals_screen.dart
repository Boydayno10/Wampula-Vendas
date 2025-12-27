import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../widgets/product_card.dart';
import '../../widgets/dynamic_product_grid.dart';
import '../../services/seller_product_service.dart';
import '../../data/mock_products.dart';

class DealsScreen extends StatefulWidget {
  final ProductModel? initialProduct;

  const DealsScreen({super.key, this.initialProduct});

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ProductModel> _allProducts = [];
  List<ProductModel> _selectedProducts = [];
  List<ProductModel> _dealProducts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  static const int _pageSize = 8;
  static const Duration _loadMoreDelay = Duration(milliseconds: 900);
  int _visibleSelectedCount = _pageSize;
  int _visibleDealsCount = _pageSize;
  bool _isLoadingMoreSelected = false;
  bool _isLoadingMoreDeals = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProducts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    
    try {
      final products = await SellerProductService.getProductModels();
      
      if (mounted) {
        setState(() {
          _allProducts = products.isEmpty ? mockProducts : products;
          _selectedProducts = _getSelectedProducts();
          // Se veio um produto inicial (por exemplo, da Central de Combos), garante ele na frente
          if (widget.initialProduct != null) {
            _selectedProducts = _prioritizeInitialProduct(_selectedProducts);
          }
          _dealProducts = _getDealProducts();
          _isLoading = false;
          _visibleSelectedCount = _pageSize;
          _visibleDealsCount = _pageSize;
          _isLoadingMoreSelected = false;
          _isLoadingMoreDeals = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allProducts = mockProducts;
          _selectedProducts = _getSelectedProducts();
          if (widget.initialProduct != null) {
            _selectedProducts = _prioritizeInitialProduct(_selectedProducts);
          }
          _dealProducts = _getDealProducts();
          _isLoading = false;
          _visibleSelectedCount = _pageSize;
          _visibleDealsCount = _pageSize;
          _isLoadingMoreSelected = false;
          _isLoadingMoreDeals = false;
        });
      }
    }
  }

  List<ProductModel> _getSelectedProducts() {
    // Produtos selecionados com base em popularidade e vendas
    final shuffled = List<ProductModel>.from(_allProducts)
      ..sort((a, b) {
        final scoreA = (a.popularity * 0.6) + (a.soldCount * 0.4);
        final scoreB = (b.popularity * 0.6) + (b.soldCount * 0.4);
        return scoreB.compareTo(scoreA);
      });
    return shuffled.take(20).toList()..shuffle();
  }

  // Coloca o produto inicial (se ainda existir na lista) como primeiro item
  List<ProductModel> _prioritizeInitialProduct(List<ProductModel> list) {
    if (widget.initialProduct == null) return list;

    final initial = widget.initialProduct!;
    final existing = list.where((p) => p.id == initial.id).toList();

    // Se não está na lista de selecionados, apenas insere no início
    if (existing.isEmpty) {
      return [initial, ...list];
    }

    // Se já está, remove das posições atuais e coloca no início
    final without = list.where((p) => p.id != initial.id).toList();
    return [existing.first, ...without];
  }

  List<ProductModel> _getDealProducts() {
    // Produtos com desconto (que têm oldPrice)
    final dealsOnly = _allProducts.where((p) => p.oldPrice != null).toList();
    
    // Se não houver produtos com oldPrice, pegar produtos aleatórios
    if (dealsOnly.isEmpty) {
      return (List<ProductModel>.from(_allProducts)..shuffle()).take(15).toList();
    }
    
    // Ordenar por desconto (maior desconto primeiro)
    dealsOnly.sort((a, b) {
      final discountA = a.oldPrice != null ? ((a.oldPrice! - a.price) / a.oldPrice! * 100) : 0;
      final discountB = b.oldPrice != null ? ((b.oldPrice! - b.price) / b.oldPrice! * 100) : 0;
      return discountB.compareTo(discountA);
    });
    
    return dealsOnly;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Busca Smart, Cresça Rápido',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              // Barra de pesquisa
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(Icons.search, color: Colors.grey[600], size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Procure produtos...',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            border: InputBorder.none,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.trim().toLowerCase();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[700],
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified, size: 16),
                          SizedBox(width: 6),
                          Text('Selecionados'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_offer, size: 16),
                          SizedBox(width: 6),
                          Text('Central de Economia'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProductGrid(
                  _selectedProducts,
                  'Selecionados para você',
                  isDealsTab: false,
                ),
                _buildProductGrid(
                  _dealProducts,
                  'Descontos incríveis',
                  isDealsTab: true,
                ),
              ],
            ),
    );
  }

  Widget _buildProductGrid(
    List<ProductModel> products,
    String title, {
    required bool isDealsTab,
  }) {
    final visibleProducts = _searchQuery.isEmpty
        ? products
        : products.where((p) {
            final q = _searchQuery;
            return p.name.toLowerCase().contains(q) ||
                p.category.toLowerCase().contains(q) ||
                (p.storeName?.toLowerCase().contains(q) ?? false);
          }).toList();

    if (visibleProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhum produto disponível',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final total = visibleProducts.length;
    final currentVisible = isDealsTab ? _visibleDealsCount : _visibleSelectedCount;
    final clampedVisible = currentVisible.clamp(0, total) as int;
    final pagedProducts = total == 0
        ? <ProductModel>[]
        : visibleProducts.take(clampedVisible).toList();
    final isLoadingMore = isDealsTab ? _isLoadingMoreDeals : _isLoadingMoreSelected;

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (_isLoading || isLoadingMore) return false;
        if (scrollInfo.metrics.axis != Axis.vertical) return false;

        if (scrollInfo.metrics.extentAfter < 200 && total > clampedVisible) {
          setState(() {
            if (isDealsTab) {
              _isLoadingMoreDeals = true;
            } else {
              _isLoadingMoreSelected = true;
            }
          });

          Future.delayed(_loadMoreDelay, () {
            if (!mounted) return;
            setState(() {
              final next = clampedVisible + _pageSize;
              final newVisible = next > total ? total : next;
              if (isDealsTab) {
                _visibleDealsCount = newVisible;
                _isLoadingMoreDeals = false;
              } else {
                _visibleSelectedCount = newVisible;
                _isLoadingMoreSelected = false;
              }
            });
          });
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                const Icon(Icons.emoji_emotions, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
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
        // Grid dinâmico reutilizando o mesmo componente da home
        DynamicProductGrid(products: pagedProducts),
        const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
      ],
      ),
    );
  }
}
