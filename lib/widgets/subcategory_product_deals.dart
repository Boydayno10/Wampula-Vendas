import 'package:flutter/material.dart';
import '../models/product_model.dart';
import 'skeleton_loader.dart';

class SubCategoryProductDeals extends StatelessWidget {
  final List<ProductModel> products;
  final void Function(ProductModel) onSelect;
  final bool isLoading;

  const SubCategoryProductDeals({
    super.key,
    required this.products,
    required this.onSelect,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SubCategoryDealsSkeleton();
    }

    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 170,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final p = products[index];
          return GestureDetector(
            key: ValueKey('subcategory_deal_${p.id}'),
            onTap: () => onSelect(p),
            child: SizedBox(
              width: 140,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: (() {
                        final imageUrl = (p.images != null && p.images!.isNotEmpty)
                            ? p.images!.first
                            : p.image;
                        
                        return imageUrl.startsWith('http')
                          ? Image.network(
                              imageUrl,
                              height: 90,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 90,
                                  color: Colors.grey[200],
                                  child: Icon(Icons.image_not_supported, color: Colors.grey),
                                );
                              },
                            )
                          : Image.asset(
                              imageUrl,
                              height: 90,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 90,
                                  color: Colors.grey[200],
                                  child: Icon(Icons.image_not_supported, color: Colors.grey),
                                );
                              },
                            );
                      })(),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${p.price.toStringAsFixed(0)} MT',
                            style: const TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
