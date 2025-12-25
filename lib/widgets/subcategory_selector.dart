import 'package:flutter/material.dart';
import '../data/mock_products.dart';
import '../data/subcategories_data.dart';
import '../models/product_model.dart';
import '../screens/subcategory/subcategory_screen.dart';

class SubCategorySelector extends StatelessWidget {
  final String category;
  final ProductModel? popular;
  final ProductModel? bought;
  final ProductModel? cheap;

  const SubCategorySelector({
    super.key,
    required this.category,
    required this.popular,
    required this.bought,
    required this.cheap,
  });

  @override
  Widget build(BuildContext context) {
    final products = _productsForCategory();
    final newest = _pickNew(products);
    final promo = _pickPromo(products);
    final recommended = _pickRecommended(products);

    final items = subCategoryItems.map<_SubItem>((entry) {
      final label = entry['label']!;
      final fallbackImage = entry['image']!;

      final productImage = switch (label) {
        'Mais populares' => (popular?.images != null && popular!.images!.isNotEmpty) 
            ? popular!.images!.first : popular?.image,
        'Mais comprados' => (bought?.images != null && bought!.images!.isNotEmpty) 
            ? bought!.images!.first : bought?.image,
        'Mais baratos' => (cheap?.images != null && cheap!.images!.isNotEmpty) 
            ? cheap!.images!.first : cheap?.image,
        'Novos' => (newest != null && newest.images != null && newest.images!.isNotEmpty) 
            ? newest.images!.first : newest?.image,
        'Promoções' => (promo != null && promo.images != null && promo.images!.isNotEmpty) 
            ? promo.images!.first : promo?.image,
        'Recomendados' => (recommended != null && recommended.images != null && recommended.images!.isNotEmpty) 
            ? recommended.images!.first : recommended?.image,
        _ => null,
      };

      final sortMode = switch (label) {
        'Mais populares' => SubSortMode.populares,
        'Mais comprados' => SubSortMode.comprados,
        'Mais baratos' => SubSortMode.baratos,
        'Novos' => SubSortMode.novos,
        'Promoções' => SubSortMode.promocoes,
        'Recomendados' => SubSortMode.recomendados,
        _ => null,
      };

      return _SubItem(
        key: ValueKey('subcategory_$label'),
        label: label,
        image: productImage ?? fallbackImage,
        onTap: () => _goToSub(context, label, sortMode),
      );
    }).toList();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12), // só margem inferior
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Subcategorias",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, index) => items[index],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToSub(BuildContext context, String label, SubSortMode? mode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubCategoryScreen(
          category: category,
          subCategory: label,
          sortMode: mode,
        ),
      ),
    );
  }

  List<ProductModel> _productsForCategory() {
    if (category == 'Início') return List<ProductModel>.from(mockProducts);
    return mockProducts.where((p) => p.category == category).toList();
  }

  ProductModel? _pickNew(List<ProductModel> items) {
    if (items.isEmpty) return null;
    final copy = List<ProductModel>.from(items)
      ..sort((a, b) => (int.tryParse(b.id) ?? 0).compareTo(int.tryParse(a.id) ?? 0));
    return copy.first;
  }

  ProductModel? _pickPromo(List<ProductModel> items) {
    if (items.isEmpty) return null;
    final copy = List<ProductModel>.from(items)
      ..sort((a, b) => a.price.compareTo(b.price));
    return copy.first;
  }

  ProductModel? _pickRecommended(List<ProductModel> items) {
    if (items.isEmpty) return null;
    final copy = List<ProductModel>.from(items)
      ..sort((a, b) => b.popularity.compareTo(a.popularity));
    return copy.first;
  }
}

class _SubItem extends StatelessWidget {
  final String label;
  final String image;
  final VoidCallback onTap;

  const _SubItem({
    super.key,
    required this.label,
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: image.startsWith('http')
                ? Image.network(
                    image,
                    width: double.infinity,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 100,
                        color: Colors.grey[200],
                        child: Icon(Icons.image_not_supported, color: Colors.grey),
                      );
                    },
                  )
                : Image.asset(
                    image,
                    width: double.infinity,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 100,
                        color: Colors.grey[200],
                        child: Icon(Icons.image_not_supported, color: Colors.grey),
                      );
                    },
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
