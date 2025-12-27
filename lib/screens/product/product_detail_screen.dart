import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../services/cart_service.dart';
import '../../services/seller_product_service.dart';
import '../../services/product_analytics_service.dart';
import '../checkout/checkout_screen.dart';
import '../cart/cart_screen.dart';
import 'product_option_sheet.dart';
import '../../utils/auth_helper.dart';
import '../seller/seller_store_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  String? selectedSize;
  String? selectedColor;
  String? selectedAge;
  String? selectedStorage;
  String? selectedPantSize;
  String? selectedShoeSize;
  int? selectedQuantity;
  bool optionsChosen = false;

  // 🆕 Lista de imagens do produto
  late List<String> images;
  late PageController _pageController;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    // Usar as imagens do produto ou fallback para a imagem principal
    images = widget.product.images != null && widget.product.images!.isNotEmpty
        ? widget.product.images!
        : [widget.product.image];
    
    print('🖼️ Product Detail - Total de imagens: ${images.length}');
    print('📸 URLs das imagens: $images');
    
    // 📊 Rastrear visualização do produto
    _trackProductView();
  }
  
  /// Registra visualização do produto no analytics
  Future<void> _trackProductView() async {
    await ProductAnalyticsService.trackProductView(widget.product.id);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _chooseTransport() async {
    // Buscar informações do produto do vendedor
    final sellerProduct = await SellerProductService.getById(widget.product.id);
    final transportPrice = sellerProduct?.transportPrice ?? 50.0;
    final hasLocation = sellerProduct?.hasLocationEnabled ?? false;
    final storeAddress = sellerProduct?.storeAddress ?? 'Endereço não disponível';
    final storeLatitude = sellerProduct?.storeLatitude ?? -25.969248;
    final storeLongitude = sellerProduct?.storeLongitude ?? 32.573292;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Transporte e Entrega',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              // Preço de Transporte
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping, color: Colors.deepPurple, size: 32),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transporte',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${transportPrice.toStringAsFixed(0)} MT',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Mapa de Localização (se habilitado)
              if (hasLocation) ...[
                const SizedBox(height: 20),
                const Text(
                  'Localização da Loja',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        // Placeholder do mapa com ícone
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 48,
                                color: Colors.deepPurple,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                storeAddress,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Lat: ${storeLatitude.toStringAsFixed(4)}, Lng: ${storeLongitude.toStringAsFixed(4)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Botão para abrir no mapa
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Abrir no Google Maps ou Apple Maps
                            },
                            icon: const Icon(Icons.map, size: 16),
                            label: const Text('Abrir'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 20),
              
              // Nota importante
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'NB: Chegue no local de entrega antes',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Botão de fechar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Entendi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseOptions() async {
    // Buscar configurações do produto do vendedor
    final sellerProduct = await SellerProductService.getById(widget.product.id);
    
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ProductOptionSheet(
        title: widget.product.name,
        image: widget.product.image,
        price: widget.product.price,
        initialSize: selectedSize,
        initialColor: selectedColor,
        initialAge: selectedAge,
        initialQuantity: selectedQuantity,
        availableSizes: sellerProduct?.sizes,
        availableColors: sellerProduct?.colors,
        availableAgeGroups: sellerProduct?.ageGroups,
        availableStorageOptions: sellerProduct?.storageOptions,
        availablePantSizes: sellerProduct?.pantSizes,
        availableShoeSizes: sellerProduct?.shoeSizes,
        hasSizeOption: sellerProduct?.hasSizeOption ?? false,
        hasColorOption: sellerProduct?.hasColorOption ?? false,
        hasAgeOption: sellerProduct?.hasAgeOption ?? false,
        hasStorageOption: sellerProduct?.hasStorageOption ?? false,
        hasPantSizeOption: sellerProduct?.hasPantSizeOption ?? false,
        hasShoeSizeOption: sellerProduct?.hasShoeSizeOption ?? false,
        stock: sellerProduct?.stock ?? 999,
      ),
    );

    if (result != null) {
      setState(() {
        selectedSize = result['size'];
        selectedColor = result['color'];
        selectedAge = result['age'];
        selectedStorage = result['storage'];
        selectedPantSize = result['pantSize'];
        selectedShoeSize = result['shoeSize'];
        selectedQuantity = result['quantity'];
        optionsChosen = true;
      });
    }
  }

  // void _openTransportSheet() {
  //   // Buscar preço de transporte do vendedor
  //   final sellerProduct = SellerProductService.getById(widget.product.id);
  //   
  //   showModalBottomSheet(
  //     context: context,
  //     backgroundColor: Colors.transparent,
  //     isScrollControlled: true,
  //     builder: (_) => FractionallySizedBox(
  //       heightFactor: 0.45,
  //       child: TransportSheet(
  //         transportPrice: sellerProduct?.transportPrice ?? 50.0,
  //       ),
  //     ),
  //   );
  // }

  void _addToCart() async {
    // Verifica autenticação antes de adicionar ao carrinho
    if (!AuthHelper.requireAuth(
      context,
      message: 'Faça login para adicionar produtos ao carrinho.',
    )) {
      return;
    }

    if (!optionsChosen) {
      await _chooseOptions();
      if (!optionsChosen) return;
    }

    CartService.addProduct(
      product: widget.product,
      quantity: selectedQuantity ?? 1,
      size: selectedSize,
      color: selectedColor,
      age: selectedAge,
      storage: selectedStorage,
      pantSize: selectedPantSize,
      shoeSize: selectedShoeSize,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Produto adicionado ao carrinho'),
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    CartScreen(onBackToHome: () => Navigator.pop(context)),
              ),
            );
          },
        ),
      ),
    );
  }

  void _buyNow() async {
    // Verifica autenticação antes de comprar
    if (!AuthHelper.requireAuth(
      context,
      message: 'Faça login para finalizar sua compra.',
    )) {
      return;
    }

    if (!optionsChosen) {
      await _chooseOptions();
      if (!optionsChosen) return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          product: widget.product,
          quantity: selectedQuantity,
          size: selectedSize,
          color: selectedColor,
          age: selectedAge,
          storage: selectedStorage,
          pantSize: selectedPantSize,
          shoeSize: selectedShoeSize,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),

      body: Column(
        children: [
          // 🖼 IMAGEM PRINCIPAL EM SCROLL HORIZONTAL
          LayoutBuilder(
            builder: (context, constraints) {
              final imageHeight = constraints.maxWidth * 0.8; // Altura proporcional
              return SizedBox(
                height: imageHeight > 320 ? 320 : imageHeight,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: images.length,
                  onPageChanged: (index) => setState(() => currentIndex = index),
                  itemBuilder: (_, index) {
                    final imageUrl = images[index];
                    print('🎨 Renderizando imagem $index: $imageUrl');
                    
                    // Verificar se é URL HTTP ou asset local
                    if (imageUrl.startsWith('http')) {
                      return Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          print('❌ Erro ao carregar imagem $index: $error');
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported, size: 64),
                          );
                        },
                      );
                    } else {
                      // Asset local
                      return Image.asset(
                        imageUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          print('❌ Erro ao carregar asset $index: $error');
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported, size: 64),
                          );
                        },
                      );
                    }
                  },
                ),
              );
            },
          ),

          // 🔽 MINIATURAS (THUMBNAILS) - Alinhadas à esquerda
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16),
            child: SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  final thumb = images[index];
                  final isActive = currentIndex == index;

                  return GestureDetector(
                    onTap: () {
                      setState(() => currentIndex = index);
                      // Anima para a página correspondente
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isActive ? Colors.deepPurple : Colors.grey,
                          width: isActive ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: thumb.startsWith('http')
                            ? Image.network(
                                thumb,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.image, size: 20),
                                  );
                                },
                              )
                            : Image.asset(
                                thumb,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.image, size: 20),
                                  );
                                },
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome do produto
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Quantidade vendida
                  Text(
                    '${p.soldCount} vendidos',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Preço atual e antigo
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Preço atual em vermelho grande
                      Text(
                        '${p.price.toStringAsFixed(0)} MT',
                        style: const TextStyle(
                          fontSize: 28,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (p.oldPrice != null) ...[
                        const SizedBox(width: 12),
                        // Preço antigo riscado menor
                        Text(
                          '${p.oldPrice!.toStringAsFixed(0)} MT',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.lineThrough,
                            decorationThickness: 2,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Opções do produto
                  InkWell(
                    onTap: _chooseOptions,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              optionsChosen
                                  ? "Tam: ${selectedSize ?? '-'}, Cor: ${selectedColor ?? '-'}"
                                  : "Selecione tamanho, cor e idade",
                              style: TextStyle(
                                color: optionsChosen ? Colors.black : Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Botão Transporte
                  InkWell(
                    onTap: _chooseTransport,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.local_shipping, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text('Transporte e entrega'),
                          ),
                          Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Botão Ver Loja do Vendedor
                  if (p.storeName != null && p.sellerId != null)
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SellerStoreScreen(
                              sellerId: p.sellerId!,
                              storeName: p.storeName!,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.1),
                          border: Border.all(color: Colors.deepPurple),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.store,
                              size: 20,
                              color: Colors.deepPurple,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Visitar Loja',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                  Text(
                                    p.storeName!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.deepPurple,
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Descrição do produto
                  const Text(
                    'Descrição',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder(
                    future: SellerProductService.getById(p.id),
                    builder: (context, snapshot) {
                      final productDescription = snapshot.data?.description ?? 
                          'Produto disponível no Wampula Vendas.\nEntrega segura no seu bairro.';
                      return Text(
                        productDescription,
                        style: const TextStyle(fontSize: 15),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _addToCart,
                  child: const Text('Adicionar ao carrinho'),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: ElevatedButton(
                  onPressed: _buyNow,
                  child: const Text('Comprar agora'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
