import 'package:flutter/material.dart';

import '../../widgets/wv_primary_button.dart';

class ProductImageZoomScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final bool isClientPublication;
  final VoidCallback onAddToCartOrTouch;
  final VoidCallback onBuyNowOrChat;

  const ProductImageZoomScreen({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.isClientPublication,
    required this.onAddToCartOrTouch,
    required this.onBuyNowOrChat,
  });

  @override
  State<ProductImageZoomScreen> createState() => _ProductImageZoomScreenState();
}

class _ProductImageZoomScreenState extends State<ProductImageZoomScreen> {
  late final TransformationController _transformationController;
  double _currentZoom = 1.0;
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onZoomChanged);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  void _onZoomChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    setState(() {
      _currentZoom = scale;
    });
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onZoomChanged);
    _transformationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_currentZoom > 1.0) {
      _transformationController.value = Matrix4.identity();
    } else {
      _transformationController.value = Matrix4.identity()..scale(2.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          // Página de imagens com zoom individual por página
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
                // Sempre resetar o zoom ao trocar de imagem
                _transformationController.value = Matrix4.identity();
              },
              itemBuilder: (context, index) {
                final imageUrl = widget.images[index];

                final Widget imageWidget = imageUrl.startsWith('http')
                    ? Image.network(imageUrl, fit: BoxFit.contain)
                    : Image.asset(imageUrl, fit: BoxFit.contain);

                return InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 1.0,
                  maxScale: 6.0,
                  panEnabled: true,
                  scaleEnabled: true,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  clipBehavior: Clip.none,
                  child: GestureDetector(
                    onDoubleTap: _handleDoubleTap,
                    child: Center(child: imageWidget),
                  ),
                );
              },
            ),
          ),

          // Botões flutuantes (X e compartilhar) alinhados ao topo
          Positioned(
            top: statusBarTop + 8,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.6),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          Positioned(
            top: statusBarTop + 8,
            right: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.6),
              child: IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () {
                  // TODO: implementar partilha da imagem/produto atual (_currentIndex)
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            boxShadow: [BoxShadow(blurRadius: 8, offset: Offset(0, -2))],
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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
