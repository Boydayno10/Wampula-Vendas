import 'dart:async';
import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../screens/product/product_detail_screen.dart';

class HomeBanner extends StatefulWidget {
  final List<ProductModel> featuredProducts;

  const HomeBanner({super.key, required this.featuredProducts});

  @override
  State<HomeBanner> createState() => _HomeBannerState();
}

class _HomeBannerState extends State<HomeBanner> with SingleTickerProviderStateMixin {
  final PageController _controller = PageController();
  int _currentPage = 0;
  Timer? _timer;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    
    // Animação shimmer para o skeleton
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    // Só inicia o timer se houver produtos
    if (widget.featuredProducts.isNotEmpty) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (_controller.hasClients) {
          _currentPage = (_currentPage + 1) % widget.featuredProducts.length;
          _controller.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Banner um pouco mais alto (≈ +20%), com limite superior mais generoso
    final bannerHeight = (screenWidth * 0.55).clamp(160.0, 220.0);
    
    // Se não houver produtos em destaque, exibe skeleton
    if (widget.featuredProducts.isEmpty) {
      return AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          return Container(
            height: bannerHeight,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [
                  _shimmerController.value - 0.3,
                  _shimmerController.value,
                  _shimmerController.value + 0.3,
                ],
                colors: [
                  Colors.grey[300]!,
                  Colors.grey[100]!,
                  Colors.grey[300]!,
                ],
              ),
            ),
          );
        },
      );
    }
    
    return Column(
      children: [
        SizedBox(
          height: bannerHeight,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.featuredProducts.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              final product = widget.featuredProducts[index];
              return GestureDetector(
                key: ValueKey('banner_product_${product.id}'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(product: product),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.deepPurple.shade50,
                  ),
                  child: Stack(
                    children: [
                      // Imagem do produto - ocupando todo o banner
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: (() {
                          final imageUrl = (product.images != null && product.images!.isNotEmpty)
                              ? product.images!.first
                              : product.image;
                          
                          return imageUrl.startsWith('http')
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: Icon(Icons.image, color: Colors.grey, size: bannerHeight * 0.3),
                                  );
                                },
                              )
                            : Image.asset(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: Icon(Icons.image, color: Colors.grey, size: bannerHeight * 0.3),
                                  );
                                },
                              );
                        })(),
                      ),
                      // Badge "Em Destaque"
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '⭐ Em Destaque',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Info do produto na parte inferior
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${product.price.toStringAsFixed(2)} MT',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 6),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.featuredProducts.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? Colors.deepPurple
                    : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
