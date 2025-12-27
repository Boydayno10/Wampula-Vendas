import 'product_model.dart';

class SellerProductModel {
  final String id;
  final String sellerId;
  String sellerStoreName; // Nome da loja do vendedor
  String name;
  double price;
  double? oldPrice; // Preço antigo (riscado) - opcional
  List<String> images; // Lista de imagens do produto
  String description;
  String category;
  int stock; // Estoque disponível
  bool active; // Se o produto está ativo para venda
  int soldCount; // Quantidade vendida
  double popularity; // Popularidade (0-100)
  int? clicksCount; // Número de cliques (nullable)
  int? viewsCount; // Número de visualizações (nullable)
  final DateTime createdAt;
  DateTime updatedAt;
  
  // Opções do produto
  List<String>? sizes; // Tamanhos disponíveis (ex: S, M, L, XL)
  List<String>? colors; // Cores disponíveis
  List<String>? ageGroups; // Faixas etárias (ex: 1-3M, 4-6M)
  List<String>? storageOptions; // Armazenamento (ex: 64GB, 128GB, 256GB)
  List<String>? pantSizes; // Tamanhos de calças (ex: 28, 30, 32)
  List<String>? shoeSizes; // Tamanhos de calçados (ex: 36, 37, 38)
  double transportPrice; // Preço do transporte
  bool hasSizeOption; // Se tem opção de tamanho
  bool hasColorOption; // Se tem opção de cor
  bool hasAgeOption; // Se tem opção de idade
  bool hasStorageOption; // Se tem opção de armazenamento
  bool hasPantSizeOption; // Se tem opção de tamanho de calça
  bool hasShoeSizeOption; // Se tem opção de tamanho de calçado
  
  // Localização da loja
  bool hasLocationEnabled; // Se habilitou mostrar localização
  double? storeLatitude; // Latitude da loja
  double? storeLongitude; // Longitude da loja
  String? storeAddress; // Endereço da loja

  SellerProductModel({
    required this.id,
    required this.sellerId,
    required this.sellerStoreName,
    required this.name,
    required this.price,
    this.oldPrice,
    required this.images,
    required this.description,
    required this.category,
    this.stock = 0,
    this.active = true,
    this.soldCount = 0,
    this.popularity = 0,
    this.clicksCount,
    this.viewsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.sizes,
    this.colors,
    this.ageGroups,
    this.storageOptions,
    this.pantSizes,
    this.shoeSizes,
    this.transportPrice = 50.0,
    this.hasSizeOption = false,
    this.hasColorOption = false,
    this.hasAgeOption = false,
    this.hasStorageOption = false,
    this.hasPantSizeOption = false,
    this.hasShoeSizeOption = false,
    this.hasLocationEnabled = false,
    this.storeLatitude,
    this.storeLongitude,
    this.storeAddress,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Converte para ProductModel para exibir na Home
  ProductModel toProductModel() {
    return ProductModel(
      id: id,
      name: name,
      price: price,
      oldPrice: oldPrice,
      image: images.isNotEmpty ? images.first : '',
      images: images,
      category: category,
      storeName: sellerStoreName,
      sellerId: sellerId,
      soldCount: soldCount,
      popularity: popularity,
      clicksCount: clicksCount,
      viewsCount: viewsCount,
      createdAt: createdAt,
    );
  }

  // Cria cópia com alterações
  SellerProductModel copyWith({
    String? sellerStoreName,
    String? name,
    double? price,
    Object? oldPrice = _Undefined, // Permite passar null explicitamente
    List<String>? images,
    String? description,
    String? category,
    int? stock,
    bool? active,
    int? soldCount,
    double? popularity,
    Object? sizes = _Undefined,
    Object? colors = _Undefined,
    Object? ageGroups = _Undefined,
    Object? storageOptions = _Undefined,
    Object? pantSizes = _Undefined,
    Object? shoeSizes = _Undefined,
    double? transportPrice,
    bool? hasSizeOption,
    bool? hasColorOption,
    bool? hasAgeOption,
    bool? hasStorageOption,
    bool? hasPantSizeOption,
    bool? hasShoeSizeOption,
    bool? hasLocationEnabled,
    Object? storeLatitude = _Undefined,
    Object? storeLongitude = _Undefined,
    Object? storeAddress = _Undefined,
  }) {
    return SellerProductModel(
      id: id,
      sellerId: sellerId,
      sellerStoreName: sellerStoreName ?? this.sellerStoreName,
      name: name ?? this.name,
      price: price ?? this.price,
      oldPrice: oldPrice == _Undefined ? this.oldPrice : oldPrice as double?,
      images: images ?? this.images,
      description: description ?? this.description,
      category: category ?? this.category,
      stock: stock ?? this.stock,
      active: active ?? this.active,
      soldCount: soldCount ?? this.soldCount,
      popularity: popularity ?? this.popularity,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      sizes: sizes == _Undefined ? this.sizes : sizes as List<String>?,
      colors: colors == _Undefined ? this.colors : colors as List<String>?,
      ageGroups: ageGroups == _Undefined ? this.ageGroups : ageGroups as List<String>?,
      storageOptions: storageOptions == _Undefined ? this.storageOptions : storageOptions as List<String>?,
      pantSizes: pantSizes == _Undefined ? this.pantSizes : pantSizes as List<String>?,
      shoeSizes: shoeSizes == _Undefined ? this.shoeSizes : shoeSizes as List<String>?,
      transportPrice: transportPrice ?? this.transportPrice,
      hasSizeOption: hasSizeOption ?? this.hasSizeOption,
      hasColorOption: hasColorOption ?? this.hasColorOption,
      hasAgeOption: hasAgeOption ?? this.hasAgeOption,
      hasStorageOption: hasStorageOption ?? this.hasStorageOption,
      hasPantSizeOption: hasPantSizeOption ?? this.hasPantSizeOption,
      hasShoeSizeOption: hasShoeSizeOption ?? this.hasShoeSizeOption,
      hasLocationEnabled: hasLocationEnabled ?? this.hasLocationEnabled,
      storeLatitude: storeLatitude == _Undefined ? this.storeLatitude : storeLatitude as double?,
      storeLongitude: storeLongitude == _Undefined ? this.storeLongitude : storeLongitude as double?,
      storeAddress: storeAddress == _Undefined ? this.storeAddress : storeAddress as String?,
    );
  }
}

// Classe auxiliar para diferenciar null explícito de não fornecido
class _Undefined {
  const _Undefined();
}
