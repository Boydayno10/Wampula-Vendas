class ProductModel {
  final String id;
  final String name;
  final double price;
  final double? oldPrice; // Preço antigo (riscado) - opcional
  final String image;
  final List<String>? images; // Lista completa de imagens
  final String category;
  final String? storeName; // Nome da loja do vendedor
  final String? sellerId; // ID do vendedor

  // Métricas para ordenar subcategorias
  final int soldCount;
  final double popularity;

  final Map<String, String>? colorImages;

  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    this.oldPrice,
    required this.image,
    this.images,
    required this.category,
    this.storeName,
    this.sellerId,
    this.soldCount = 0,
    this.popularity = 0,
    this.colorImages,
  });
}
