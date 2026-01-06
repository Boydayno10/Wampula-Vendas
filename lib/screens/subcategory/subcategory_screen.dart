import 'package:flutter/material.dart';
import '../../widgets/product_card.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/dynamic_product_grid.dart';
import '../../models/product_model.dart';
import '../../services/product_filter_service.dart';
import '../../services/product_analytics_service.dart';
import '../notifications/notifications_screen.dart';
import '../../widgets/notification_bell.dart';
import '../../utils/auth_helper.dart';

class SubCategoryScreen extends StatefulWidget {
  final String subCategory;
  final String category;
  final ProductFilterType? filterType;
  final String? categorySubcategoryId;
  final List<ProductModel> allProducts;

  const SubCategoryScreen({
    super.key,
    required this.subCategory,
    required this.category,
    this.filterType,
    this.categorySubcategoryId,
    required this.allProducts,
  });

  @override
  State<SubCategoryScreen> createState() => _SubCategoryScreenState();
}

class _SubCategoryScreenState extends State<SubCategoryScreen> {
  bool _isLoading = true;
  List<ProductModel> _filteredProducts = [];
  static const int _pageSize = 8;
  static const Duration _loadMoreDelay = Duration(milliseconds: 900);
  int _visibleCount = _pageSize;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  /// 📊 Carrega produtos aplicando filtro dinâmico
  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);

    try {
      // Primeiro, garantir que estamos apenas na categoria correta
      List<ProductModel> base = widget.allProducts;
      if (widget.category.isNotEmpty &&
          widget.category.toLowerCase() != 'início' &&
          widget.category.toLowerCase() != 'inicio') {
        base = base
            .where(
              (p) =>
                  p.category.toLowerCase().trim() ==
                  widget.category.toLowerCase().trim(),
            )
            .toList();
      }

      List<ProductModel> filtered;

      if (widget.categorySubcategoryId != null &&
          widget.categorySubcategoryId!.isNotEmpty) {
        // Subcategoria ESPECÍFICA da categoria (ex: Feminino, Móveis, etc.)
        filtered = base
            .where(
              (p) => p.categorySubcategoryId == widget.categorySubcategoryId,
            )
            .toList();
      } else if (widget.filterType != null) {
        // Subcategoria GLOBAL (Mais populares, Mais comprados, ...)
        filtered = ProductFilterService.filterProducts(
          allProducts: base,
          // Usa 'Início' porque a categoria já foi aplicada em base
          categoryName: 'Início',
          filterType: widget.filterType!,
        );
      } else {
        // Fallback: apenas produtos da categoria
        filtered = base;
      }

      print(
        '🎯 Subcategoria "${widget.subCategory}" em "${widget.category}": ${filtered.length} produtos',
      );

      setState(() {
        _filteredProducts = filtered;
        _isLoading = false;
        _visibleCount = _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      print('❌ Erro ao carregar produtos da subcategoria: $e');
      setState(() {
        _filteredProducts = [];
        _isLoading = false;
        _visibleCount = _pageSize;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refreshSubcategory() async {
    await _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(widget.subCategory),
        actions: [NotificationBell(rootContext: context)],
      ),

      body: RefreshIndicator(
        onRefresh: _refreshSubcategory,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _filteredProducts.isEmpty
            ? _buildEmptyState()
            : _buildProductGrid(),
      ),
    );
  }

  /// Widget quando não há produtos
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Nenhum produto encontrado',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tente outra subcategoria',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// Grid de produtos
  Widget _buildProductGrid() {
    final total = _filteredProducts.length;
    final clampedVisible = _visibleCount.clamp(0, total) as int;
    final visible = total == 0
        ? <ProductModel>[]
        : _filteredProducts.take(clampedVisible).toList();
    final isLoadingMore = _isLoadingMore;

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (_isLoading || isLoadingMore) return false;
        if (scrollInfo.metrics.axis != Axis.vertical) return false;

        if (scrollInfo.metrics.extentAfter < 200 && total > clampedVisible) {
          setState(() {
            _isLoadingMore = true;
          });

          Future.delayed(_loadMoreDelay, () {
            if (!mounted) return;
            setState(() {
              final next = clampedVisible + _pageSize;
              _visibleCount = next > total ? total : next;
              _isLoadingMore = false;
            });
          });
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          // Informação da categoria e filtro
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 20,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.category,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_filteredProducts.length} produto${_filteredProducts.length != 1 ? 's' : ''} encontrado${_filteredProducts.length != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
          DynamicProductGrid(products: visible),
        ],
      ),
    );
  }
}
