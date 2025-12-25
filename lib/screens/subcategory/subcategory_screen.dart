import 'package:flutter/material.dart';
import '../../widgets/product_card.dart';
import '../../widgets/skeleton_loader.dart';
import '../../data/mock_products.dart';
import '../../models/product_model.dart';

// Critérios de ordenação das subcategorias
enum SubSortMode { populares, comprados, baratos, novos, promocoes, recomendados }

class SubCategoryScreen extends StatefulWidget {
  final String subCategory;
  final String category;
  final SubSortMode? sortMode;

  const SubCategoryScreen({
    super.key,
    required this.subCategory,
    required this.category,
    this.sortMode,
  });

  @override
  State<SubCategoryScreen> createState() => _SubCategoryScreenState();
}

class _SubCategoryScreenState extends State<SubCategoryScreen> {
  Future<void> _refreshSubcategory() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _filteredProductsForCategory();
    final sorted = _applySort(filteredProducts, widget.sortMode);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(widget.subCategory),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _refreshSubcategory,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: sorted.isEmpty
                  ? SliverFillRemaining(
                      child: const SkeletonLoader(itemCount: 6),
                    )
                  : SliverGrid(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return ProductCard(
                          key: ValueKey('subcategory_product_${sorted[index].id}'),
                          product: sorted[index],
                        );
                      }, childCount: sorted.length),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.65,
                          ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<ProductModel> _filteredProductsForCategory() {
    if (widget.category == 'Início') {
      final list = List<ProductModel>.from(mockProducts);
      list.shuffle();
      return list;
    }
    return mockProducts.where((p) => p.category == widget.category).toList();
  }

  List<ProductModel> _applySort(List<ProductModel> items, SubSortMode? mode) {
    final list = List<ProductModel>.from(items);
    switch (mode) {
      case SubSortMode.populares:
        list.sort((a, b) => b.popularity.compareTo(a.popularity));
        return list;
      case SubSortMode.comprados:
        list.sort((a, b) => b.soldCount.compareTo(a.soldCount));
        return list;
      case SubSortMode.baratos:
        list.sort((a, b) => a.price.compareTo(b.price));
        return list;
      case SubSortMode.novos:
        int parse(String v) => int.tryParse(v) ?? 0;
        list.sort((a, b) => parse(b.id).compareTo(parse(a.id)));
        return list;
      case SubSortMode.promocoes:
        list.sort((a, b) => a.price.compareTo(b.price));
        return list;
      case SubSortMode.recomendados:
        list.sort((a, b) => b.popularity.compareTo(a.popularity));
        return list;
      case null:
        return list;
    }
  }
}
