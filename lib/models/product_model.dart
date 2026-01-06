class ProductModel {
  final String id;
  final String name;
  final double price;
  final double? oldPrice; // Preço antigo (riscado) - opcional
  final String image;
  final List<String>? images; // Lista completa de imagens
  // Imagem horizontal para banner de destaque (opcional)
  final String? bannerImage;
  final String category;
  // Subcategoria específica escolhida pelo vendedor (ligada à categoria)
  final String? categorySubcategoryId;
  final String? storeName; // Nome da loja do vendedor
  final String? sellerId; // ID do vendedor

  // Métricas para ordenar subcategorias
  final int soldCount;
  final double popularity;
  final int? clicksCount; // Número de cliques no produto (nullable)
  final int? viewsCount; // Número de visualizações (nullable)
  final DateTime? createdAt; // Data de criação do produto

  final Map<String, String>? colorImages;

  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    this.oldPrice,
    required this.image,
    this.images,
    this.bannerImage,
    required this.category,
    this.categorySubcategoryId,
    this.storeName,
    this.sellerId,
    this.soldCount = 0,
    this.popularity = 0,
    this.clicksCount,
    this.viewsCount,
    this.createdAt,
    this.colorImages,
  });

  /// Constrói ProductModel diretamente a partir do JSON da tabela `products`.
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'];
    List<String>? images;
    if (rawImages is List) {
      images = rawImages.map((e) => e.toString()).toList();
    }

    return ProductModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      price: (json['price'] is num)
          ? (json['price'] as num).toDouble()
          : double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      oldPrice: json['old_price'] == null
          ? null
          : (json['old_price'] is num)
          ? (json['old_price'] as num).toDouble()
          : double.tryParse(json['old_price'].toString()),
      image: (json['image'] ?? '').toString(),
      images: images,
      bannerImage: json['banner_image'] as String?,
      category: (json['category'] ?? '').toString(),
      categorySubcategoryId: json['category_subcategory_id']?.toString(),
      storeName: json['seller_store_name']?.toString(),
      sellerId: json['seller_id']?.toString(),
      soldCount: (json['sold_count'] is num)
          ? (json['sold_count'] as num).toInt()
          : int.tryParse(json['sold_count']?.toString() ?? '0') ?? 0,
      popularity: (json['popularity'] is num)
          ? (json['popularity'] as num).toDouble()
          : double.tryParse(json['popularity']?.toString() ?? '0') ?? 0,
      clicksCount: json['clicks_count'] == null
          ? null
          : (json['clicks_count'] as num).toInt(),
      viewsCount: json['views_count'] == null
          ? null
          : (json['views_count'] as num).toInt(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      colorImages: null,
    );
  }
}
