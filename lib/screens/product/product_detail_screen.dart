import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import '../../utils/currency_utils.dart';

import '../../models/product_model.dart';
import '../../models/client_publicacao_model.dart';
import '../../models/chat_model.dart';
import '../../services/cart_service.dart';
import '../../services/seller_product_service.dart';
import '../../services/client_publicacao_service.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../checkout/checkout_screen.dart';
import '../cart/cart_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../widgets/notification_bell.dart';
import '../chat/chat_screen.dart';
import 'product_option_sheet.dart';
import '../../utils/auth_helper.dart';
import '../seller/seller_store_screen.dart';
import '../../widgets/wv_primary_button.dart';
import 'product_image_zoom_screen.dart';

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
  bool _isClientPublication = false;
  ClientPublicacaoModel? _clientPublication;
  ChatModel? _chat;
  bool _clientPublicationLoaded = false;

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
    _loadClientPublicationInfo();
  }

  Future<void> _loadClientPublicationInfo() async {
    try {
      final pub = await ClientPublicacaoService.getById(widget.product.id);
      if (!mounted) return;
      setState(() {
        _clientPublication = pub;
        _isClientPublication = pub != null;
        _clientPublicationLoaded = true;
      });
    } catch (e) {
      // Se não for publicação de cliente, ignorar erro silenciosamente
      print('Erro ao verificar publicação de cliente: $e');
      if (mounted) {
        setState(() {
          _clientPublicationLoaded = true;
        });
      }
    }
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

    // Só consideramos que há localização se o vendedor realmente salvou
    // latitude e longitude junto com a flag habilitada.
    final hasLocation =
        (sellerProduct?.hasLocationEnabled ?? false) &&
        sellerProduct?.storeLatitude != null &&
        sellerProduct?.storeLongitude != null;

    final double? storeLatitude = sellerProduct?.storeLatitude;
    final double? storeLongitude = sellerProduct?.storeLongitude;

    final storeAddress =
        sellerProduct?.storeAddress ??
        (hasLocation ? 'Localização disponível' : 'Endereço não disponível');

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
              // Track handler no topo
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Título
              const Text(
                'Transporte e Entrega',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              // Preço de Transporte
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_shipping,
                      color: Colors.deepPurple,
                      size: 32,
                    ),
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
                          CurrencyUtils.formatMt(transportPrice),
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

              // Mapa de Localização (se houver coordenadas válidas)
              if (hasLocation &&
                  storeLatitude != null &&
                  storeLongitude != null) ...[
                const SizedBox(height: 20),
                const Text(
                  'Localização da Loja',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  storeAddress,
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        // Para mobile usamos Google Maps nativo; em outras plataformas mantemos FlutterMap
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // Heurística simples: em mobile (Android/iOS) usamos GoogleMap
                            final platform = Theme.of(context).platform;
                            final useGoogleMap =
                                platform == TargetPlatform.android ||
                                platform == TargetPlatform.iOS;

                            if (useGoogleMap) {
                              return gmaps.GoogleMap(
                                initialCameraPosition: gmaps.CameraPosition(
                                  target: gmaps.LatLng(
                                    storeLatitude,
                                    storeLongitude,
                                  ),
                                  zoom: 15.5,
                                ),
                                markers: {
                                  gmaps.Marker(
                                    markerId: const gmaps.MarkerId(
                                      'store_location',
                                    ),
                                    position: gmaps.LatLng(
                                      storeLatitude,
                                      storeLongitude,
                                    ),
                                  ),
                                },
                                myLocationButtonEnabled: false,
                                zoomControlsEnabled: false,
                                compassEnabled: false,
                                // Usa modo satélite (híbrido: satélite + nomes de ruas)
                                mapType: gmaps.MapType.hybrid,
                                onTap: (pos) async {
                                  final uri = Uri.parse(
                                    'https://www.google.com/maps/search/?api=1&query=${storeLatitude.toStringAsFixed(6)},${storeLongitude.toStringAsFixed(6)}',
                                  );
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                              );
                            }

                            // Fallback para web/outros: FlutterMap com OpenStreetMap
                            return FlutterMap(
                              options: MapOptions(
                                initialCenter: latlng.LatLng(
                                  storeLatitude,
                                  storeLongitude,
                                ),
                                initialZoom: 16,
                                interactionOptions: const InteractionOptions(
                                  flags:
                                      InteractiveFlag.pinchZoom |
                                      InteractiveFlag.drag,
                                ),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  subdomains: const ['a', 'b', 'c'],
                                  userAgentPackageName:
                                      'com.example.wampulavendas',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: latlng.LatLng(
                                        storeLatitude,
                                        storeLongitude,
                                      ),
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.bottomCenter,
                                      child: const Icon(
                                        Icons.location_on,
                                        size: 40,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Nota importante (NB)
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

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _openFullScreenGallery(int initialIndex) {
    // Abre a nova tela de zoom com comportamento de "lupa"
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductImageZoomScreen(
          images: images,
          initialIndex: initialIndex,
          isClientPublication: _isClientPublication,
          onAddToCartOrTouch: _isClientPublication ? _handleTouch : _addToCart,
          onBuyNowOrChat: _isClientPublication ? _openChat : _buyNow,
        ),
      ),
    );
  }

  Future<void> _chooseOptions() async {
    // Buscar configurações do produto do vendedor
    final sellerProduct = await SellerProductService.getById(widget.product.id);

    // Quantidade já presente no carrinho para este produto (somando todas as linhas)
    final alreadyInCart = CartService.items
        .where((i) => i.id == widget.product.id)
        .fold<int>(0, (sum, i) => sum + i.quantity);

    final int productStock = sellerProduct?.stock ?? 0;
    final int remainingStock = productStock - alreadyInCart;

    // Logs para depuração de estoque
    print(
      '🧮 Estoque produto ${widget.product.id}: total=$productStock, noCarrinho=$alreadyInCart, restante=$remainingStock',
    );

    // Se o produto realmente não tiver estoque no banco
    if (productStock <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este produto está sem estoque no momento.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Se todo o estoque já estiver no carrinho deste usuário
    if (remainingStock <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Você já adicionou todo o estoque disponível deste produto ao carrinho (${alreadyInCart.toString()} unidades).',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

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
        // Estoque disponível considerando o que já está no carrinho
        stock: remainingStock,
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

  Future<void> _handleTouch() async {
    if (!_isClientPublication || _clientPublication == null) return;

    if (!AuthHelper.requireAuth(
      context,
      message: 'Faça login para dar um toque.',
    )) {
      return;
    }

    try {
      final ownerId = _clientPublication!.userId;

      // Dono da publicação nunca deve mandar toque para si mesmo
      if (ownerId == AuthService.currentUser.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Você é o dono desta publicação.')),
        );
        return;
      }

      // Registra toque
      await ChatService.registerTouch(
        publicationId: _clientPublication!.id,
        ownerId: ownerId,
      );

      // Cria/recupera chat e envia mensagem automática "Interessado"
      final chat = await ChatService.getOrCreateChat(
        publicationId: _clientPublication!.id,
        ownerId: ownerId,
      );

      await ChatService.sendMessage(
        chatId: chat.id,
        text: 'Olá, estou interessado na sua publicação.',
        replyToMessageId: null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Toque enviado ao dono da publicação.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao dar um toque: $e')));
    }
  }

  Future<void> _openChat() async {
    if (!_isClientPublication || _clientPublication == null) return;

    if (!AuthHelper.requireAuth(
      context,
      message: 'Faça login para conversar com o dono.',
    )) {
      return;
    }

    try {
      final ownerId = _clientPublication!.userId;

      // Dono da publicação não pode abrir chat consigo mesmo
      if (ownerId == AuthService.currentUser.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você não pode conversar consigo mesmo.'),
          ),
        );
        return;
      }

      final chat = await ChatService.getOrCreateChat(
        publicationId: _clientPublication!.id,
        ownerId: ownerId,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChatScreen(chatId: chat.id, publicationName: widget.product.name),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao abrir chat: $e')));
    }
  }

  // Aplica formatação simples de **negrito** e _itálico_ sobre o texto
  // usando os estilos padrão (isBoldDefault, isItalicDefault) e respeitando
  // quebras de linha, com alinhamento via TextAlign.
  Widget _buildFormattedDescription(
    String text,
    TextAlign textAlign,
    bool isBoldDefault,
    bool isItalicDefault,
  ) {
    final spans = <TextSpan>[];
    String buffer = '';
    bool isBold = isBoldDefault;
    bool isItalic = isItalicDefault;

    void pushBuffer() {
      if (buffer.isEmpty) return;
      spans.add(
        TextSpan(
          text: buffer,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      );
      buffer = '';
    }

    for (int i = 0; i < text.length; i++) {
      // Toggle de negrito com **
      if (i + 1 < text.length && text[i] == '*' && text[i + 1] == '*') {
        pushBuffer();
        isBold = !isBold;
        i++; // pular o segundo '*'
        continue;
      }

      // Toggle de itálico com _
      if (text[i] == '_') {
        pushBuffer();
        isItalic = !isItalic;
        continue;
      }

      buffer += text[i];
    }

    pushBuffer();

    return Text.rich(TextSpan(children: spans), textAlign: textAlign);
  }

  @override
  Widget build(BuildContext context) {
    if (!_clientPublicationLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = widget.product;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              // 🖼 IMAGEM PRINCIPAL EM SCROLL HORIZONTAL
              LayoutBuilder(
                builder: (context, constraints) {
                  // Aumenta a altura da imagem principal usando a largura
                  // como referência (layout mais alto que antes).
                  final imageHeight = constraints.maxWidth; // proporção 1:1
                  return SizedBox(
                    height: imageHeight,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: images.length,
                      onPageChanged: (index) =>
                          setState(() => currentIndex = index),
                      itemBuilder: (_, index) {
                        final imageUrl = images[index];
                        print('🎨 Renderizando imagem $index: $imageUrl');

                        // Verificar se é URL HTTP ou asset local
                        final Widget imageWidget;

                        if (imageUrl.startsWith('http')) {
                          imageWidget = Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 40,
                                ),
                              );
                            },
                          );
                        } else {
                          imageWidget = Image.asset(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 40,
                                ),
                              );
                            },
                          );
                        }

                        return GestureDetector(
                          onTap: () => _openFullScreenGallery(index),
                          child: imageWidget,
                        );
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
                                        child: const Icon(
                                          Icons.image,
                                          size: 20,
                                        ),
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
                                        child: const Icon(
                                          Icons.image,
                                          size: 20,
                                        ),
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
                      // Nome do produto (elemento mais forte da tela)
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Métricas: vendidos + visualizações (ou só visualizações para publicação)
                      Builder(
                        builder: (_) {
                          final sold = p.soldCount;
                          final views = p.viewsCount ?? 0;

                          final text = _isClientPublication
                              ? '$views visualizações'
                              : '$sold vendidos · $views visualizações';

                          return Text(
                            text,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      // Preço atual e antigo (logo abaixo do nome na hierarquia)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Preço atual em vermelho grande
                          Text(
                            CurrencyUtils.formatMt(p.price),
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (p.oldPrice != null) ...[
                            const SizedBox(width: 12),
                            // Preço antigo riscado menor
                            Text(
                              CurrencyUtils.formatMt(p.oldPrice!),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.lineThrough,
                                decorationThickness: 2,
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Opções do produto (desativadas para publicações de clientes)
                      InkWell(
                        onTap: _isClientPublication ? null : _chooseOptions,
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
                                    color: optionsChosen
                                        ? Colors.black
                                        : Colors.grey[600],
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
                              Expanded(child: Text('Transporte e entrega')),
                              Icon(Icons.arrow_forward_ios, size: 16),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Botão Loja do Vendedor / Loja indisponível
                      if (p.sellerId != null && p.sellerId!.isNotEmpty)
                        Builder(
                          builder: (_) {
                            final bool isClientPublication =
                                _isClientPublication ||
                                (p.category.toLowerCase() == 'temporarios');

                            final bool hasStore =
                                !isClientPublication &&
                                p.storeName != null &&
                                p.storeName!.trim().isNotEmpty;

                            if (hasStore) {
                              // Vendedor com loja configurada -> pode visitar
                              return InkWell(
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
                                    border: Border.all(
                                      color: Colors.deepPurple,
                                    ),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                              );
                            }

                            // Não é vendedor com loja (ex.: publicação de cliente)
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.store,
                                    size: 20,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Loja indisponível para este anúncio',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 20),

                      // Descrição (texto do produto ou da publicação)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isClientPublication
                                ? 'Descrição'
                                : 'Descrição do produto',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Divider(height: 1),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder(
                        future: SellerProductService.getById(p.id),
                        builder: (context, snapshot) {
                          final sellerProduct = snapshot.data;
                          final productDescription =
                              sellerProduct?.description ??
                              'Produto disponível no Wampula Vendas.\nEntrega segura no seu bairro.';

                          final alignment =
                              sellerProduct?.descriptionAlignment ?? 'left';
                          final textAlign = alignment == 'center'
                              ? TextAlign.center
                              : alignment == 'right'
                              ? TextAlign.right
                              : TextAlign.left;

                          final isBold =
                              sellerProduct?.descriptionBold ?? false;
                          final isItalic =
                              sellerProduct?.descriptionItalic ?? false;

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: _buildFormattedDescription(
                              productDescription,
                              textAlign,
                              isBold,
                              isItalic,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Barra superior sobreposta à imagem (voltar + notificações)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      iconTheme: const IconThemeData(color: Colors.white),
                    ),
                    child: NotificationBell(rootContext: context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
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
                    onPressed: _isClientPublication ? _handleTouch : _addToCart,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      _isClientPublication
                          ? 'Dar um Toque'
                          : 'Adicionar ao carrinho',
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: WVPrimaryButton(
                    label: _isClientPublication ? 'Conversar' : 'Comprar agora',
                    onPressed: _isClientPublication ? _openChat : _buyNow,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FullScreenImageGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final bool isClientPublication;
  final VoidCallback onAddToCartOrTouch;
  final VoidCallback onBuyNowOrChat;

  const FullScreenImageGallery({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.isClientPublication,
    required this.onAddToCartOrTouch,
    required this.onBuyNowOrChat,
  });

  @override
  State<FullScreenImageGallery> createState() => _FullScreenImageGalleryState();
}

class _FullScreenImageGalleryState extends State<FullScreenImageGallery> {
  late PageController _controller;
  late TransformationController _transformationController;
  late ValueNotifier<int> _currentPageNotifier;

  bool _isZoomed = false;
  bool _isZooming = false;
  double _viewportWidth = 0;
  double _viewportHeight = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);
    _currentPageNotifier = ValueNotifier<int>(widget.initialIndex);
    _controller.addListener(() {
      final page = _controller.page?.round() ?? widget.initialIndex;
      if (_currentPageNotifier.value != page) {
        _currentPageNotifier.value = page;
      }
    });
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _controller.dispose();
    _currentPageNotifier.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    if (_viewportWidth == 0 || _viewportHeight == 0) return;

    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();

    final bool zoomedNow = scale > 1.01;
    if (zoomedNow != _isZoomed) {
      setState(() {
        _isZoomed = zoomedNow;
      });
    }

    // Sem zoom, garantimos imagem centralizada sem translação
    if (scale <= 1.0) {
      if (matrix.storage[12] != 0 || matrix.storage[13] != 0) {
        final centered = Matrix4.identity()..scale(scale);
        _transformationController.value = centered;
      }
      return;
    }

    // Com zoom, permitimos apenas o suficiente para ver as bordas
    final double maxDx = (_viewportWidth * (scale - 1)) / 2;
    final double maxDy = (_viewportHeight * (scale - 1)) / 2;

    double dx = matrix.storage[12];
    double dy = matrix.storage[13];

    final double clampedDx = dx.clamp(-maxDx, maxDx);
    final double clampedDy = dy.clamp(-maxDy, maxDy);

    if (clampedDx != dx || clampedDy != dy) {
      matrix.storage[12] = clampedDx;
      matrix.storage[13] = clampedDy;
      _transformationController.value = matrix;
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    // Marca que um gesto de zoom/arrasto está em andamento.
    _isZooming = true;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    // O InteractiveViewer já cuida da atualização de escala/translação.
    // Mantemos esse método apenas para satisfazer o GestureDetector.
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (_isZooming) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isZooming = false;
          });
        }
      });
    }
  }

  void _handleDoubleTap() {
    // Duplo toque alterna entre zoom intermediário e sem zoom.
    if (_isZoomed) {
      _resetZoom();
    } else {
      setState(() {
        _isZoomed = true;
      });
      _transformationController.value = Matrix4.identity()..scale(2.5);
    }
  }

  void _resetZoom() {
    setState(() {
      _isZoomed = false;
    });
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final overlayPadding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Área de toque para fechar a galeria
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  // Fecha a galeria apenas se tocar fora da imagem
                  // Ou se tocar na imagem quando não estiver com zoom
                  if (!_isZoomed) {
                    Navigator.pop(context);
                  }
                },
                child: Container(color: Colors.transparent),
              ),
            ),

            // Imagem principal com zoom interativo (zoom + pan limitado)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _viewportWidth = constraints.maxWidth;
                  _viewportHeight = constraints.maxHeight;

                  return PageView.builder(
                    controller: _controller,
                    itemCount: widget.images.length,
                    onPageChanged: (_) {
                      // Resetar zoom ao trocar de imagem
                      _resetZoom();
                    },
                    itemBuilder: (_, index) {
                      final imageUrl = widget.images[index];

                      const fit = BoxFit.cover;

                      final Widget imageWidget = imageUrl.startsWith('http')
                          ? Image.network(
                              imageUrl,
                              fit: fit,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[800],
                                  child: Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey[400],
                                      size: 60,
                                    ),
                                  ),
                                );
                              },
                            )
                          : Image.asset(
                              imageUrl,
                              fit: fit,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[800],
                                  child: Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey[400],
                                      size: 60,
                                    ),
                                  ),
                                );
                              },
                            );

                      return GestureDetector(
                        onScaleStart: _handleScaleStart,
                        onScaleUpdate: _handleScaleUpdate,
                        onDoubleTapDown: (_) {},
                        onDoubleTap: _handleDoubleTap,
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          minScale: 1.0,
                          maxScale: 5.0,
                          panEnabled: true,
                          scaleEnabled: true,
                          boundaryMargin: EdgeInsets.zero,
                          clipBehavior: Clip.hardEdge,
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: imageWidget,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Barra superior: fechar (X) e compartilhar, nas mesmas posições do voltar/sino
            Positioned(
              top: overlayPadding.top,
              left: 8,
              right: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // X no lugar do botão voltar
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),

                  // Compartilhar no lugar do sininho
                  GestureDetector(
                    onTap: () {
                      // TODO: implementar partilha da imagem/produto
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.share,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Indicador de página abaixo da imagem, centralizado
            Positioned(
              left: 0,
              right: 0,
              bottom: overlayPadding.bottom + 72,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ValueListenableBuilder<int>(
                    valueListenable: _currentPageNotifier,
                    builder: (context, currentPage, child) {
                      return Text(
                        '${currentPage + 1} / ${widget.images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(12),
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
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onAddToCartOrTouch,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    widget.isClientPublication
                        ? 'Dar um Toque'
                        : 'Adicionar ao carrinho',
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: WVPrimaryButton(
                  label: widget.isClientPublication
                      ? 'Conversar'
                      : 'Comprar agora',
                  onPressed: widget.onBuyNowOrChat,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
