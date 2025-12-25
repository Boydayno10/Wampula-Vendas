import 'package:flutter/material.dart';
import 'dart:io';
import '../../services/seller_product_service.dart';
import '../../services/auth_service.dart';
import '../../models/product_model.dart';
import '../../widgets/product_card.dart';

class SellerStoreScreen extends StatefulWidget {
  final String sellerId;
  final String storeName;

  const SellerStoreScreen({
    super.key,
    required this.sellerId,
    required this.storeName,
  });

  @override
  State<SellerStoreScreen> createState() => _SellerStoreScreenState();
}

class _SellerStoreScreenState extends State<SellerStoreScreen> {
  String _selectedSubcategory = 'Todos';
  List<ProductModel> _products = [];
  String _storeDescription = '';
  String? _storeBanner;
  late ScrollController _subcategoryScrollController;

  final List<String> _subcategories = [
    'Todos',
    'Mais Vendidos',
    'Populares',
    'Mais Baratos',
    'Novidades',
  ];

  @override
  void initState() {
    super.initState();
    _subcategoryScrollController = ScrollController();
    _loadProducts();
    _loadStoreInfo();
  }

  @override
  void dispose() {
    _subcategoryScrollController.dispose();
    super.dispose();
  }

  void _scrollToSubcategory(String subcategory) {
    final index = _subcategories.indexOf(subcategory);
    if (index == -1) return;
    
    // Calcula a posição aproximada (cada item tem ~120px de largura)
    final itemWidth = 120.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final targetOffset = (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2);
    
    if (_subcategoryScrollController.hasClients) {
      _subcategoryScrollController.animateTo(
        targetOffset.clamp(0.0, _subcategoryScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _loadProducts() async {
    final sellerProducts = await SellerProductService.getProductsBySeller(widget.sellerId);
    setState(() {
      _products = sellerProducts;
    });
  }

  void _loadStoreInfo() {
    // Se for a loja do usuário logado, pega as informações dele
    if (widget.sellerId == AuthService.currentUser.id) {
      setState(() {
        _storeDescription = AuthService.currentUser.storeDescription;
        _storeBanner = AuthService.currentUser.storeBanner;
      });
    }
  }

  List<ProductModel> get _filteredProducts {
    if (_selectedSubcategory == 'Todos') {
      return _products;
    }
    
    final sortedProducts = List<ProductModel>.from(_products);
    
    switch (_selectedSubcategory) {
      case 'Mais Vendidos':
        sortedProducts.sort((a, b) => b.soldCount.compareTo(a.soldCount));
        break;
      case 'Populares':
        sortedProducts.sort((a, b) => b.popularity.compareTo(a.popularity));
        break;
      case 'Mais Baratos':
        sortedProducts.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Novidades':
        // Assume que produtos mais recentes estão no final da lista
        return sortedProducts.reversed.toList();
      default:
        return sortedProducts;
    }
    
    return sortedProducts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // AppBar com banner da loja
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.black87),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Banner da loja
                  _storeBanner != null
                      ? _storeBanner!.startsWith('http')
                          ? Image.network(
                              _storeBanner!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.deepPurple,
                                        Colors.deepPurple.shade700,
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                          : null,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.deepPurple,
                                        Colors.deepPurple.shade700,
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                          : _storeBanner!.startsWith('assets/')
                              ? Image.asset(
                                  _storeBanner!,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(_storeBanner!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.deepPurple,
                                            Colors.deepPurple.shade700,
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.deepPurple,
                                Colors.deepPurple.shade700,
                              ],
                            ),
                          ),
                        ),
                  
                  // Overlay escuro para melhor legibilidade
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  
                  // Nome e descrição da loja
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.store,
                                color: Colors.deepPurple,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.storeName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          offset: Offset(0, 1),
                                          blurRadius: 3,
                                          color: Colors.black45,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_storeDescription.isNotEmpty)
                                    Text(
                                      _storeDescription,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        shadows: [
                                          Shadow(
                                            offset: Offset(0, 1),
                                            blurRadius: 3,
                                            color: Colors.black45,
                                          ),
                                        ],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Barra de subcategorias
          SliverPersistentHeader(
            pinned: true,
            delegate: _SubcategoryHeaderDelegate(
              subcategories: _subcategories,
              selectedSubcategory: _selectedSubcategory,
              scrollController: _subcategoryScrollController,
              onSelect: (subcategory) {
                setState(() {
                  _selectedSubcategory = subcategory;
                });
                // Centraliza a subcategoria selecionada
                Future.delayed(const Duration(milliseconds: 50), () {
                  _scrollToSubcategory(subcategory);
                });
              },
            ),
          ),

          // Produtos da loja
          _filteredProducts.isEmpty
              ? SliverFillRemaining(
                  child: Center(
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
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.all(8),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.65,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return ProductCard(
                          key: ValueKey('store_product_${_filteredProducts[index].id}'),
                          product: _filteredProducts[index],
                        );
                      },
                      childCount: _filteredProducts.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// Delegate para a barra de subcategorias
class _SubcategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<String> subcategories;
  final String selectedSubcategory;
  final Function(String) onSelect;
  final ScrollController scrollController;

  _SubcategoryHeaderDelegate({
    required this.subcategories,
    required this.selectedSubcategory,
    required this.onSelect,
    required this.scrollController,
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
    return Container(
      color: Colors.white,
      child: _buildCategoryBar(),
    );
  }

  Widget _buildCategoryBar() {
    return ListView.builder(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: subcategories.length,
      itemBuilder: (context, index) {
        final subcategory = subcategories[index];
        final isSelected = subcategory == selectedSubcategory;
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => onSelect(subcategory),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.deepPurple : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: Text(
                subcategory,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  bool shouldRebuild(_SubcategoryHeaderDelegate oldDelegate) {
    return oldDelegate.selectedSubcategory != selectedSubcategory;
  }
}
