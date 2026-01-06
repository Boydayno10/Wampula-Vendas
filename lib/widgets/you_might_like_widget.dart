import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../widgets/product_card.dart';

class YouMightLikeWidget extends StatelessWidget {
  final List<ProductModel> products;

  const YouMightLikeWidget({
    super.key,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    // Pegar até 6 produtos aleatórios para exibir em grid 2x3
    final displayProducts = products.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              const Icon(
                Icons.favorite,
                color: Colors.pinkAccent,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Você vai gostar',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.65,
            ),
            itemCount: displayProducts.length,
            itemBuilder: (context, index) {
              return ProductCard(product: displayProducts[index]);
            },
          ),
        ),
      ],
    );
  }
}
