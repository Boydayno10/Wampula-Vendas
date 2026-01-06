class ClientPublicacaoModel {
  final String id;
  final String userId;
  String name;
  double price;
  double? promoPrice;
  List<String> images;
  bool active;
  bool hasLocationEnabled;
  String category;
  String? description;
  final DateTime createdAt;
  final DateTime? expiresAt;

  ClientPublicacaoModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.price,
    this.promoPrice,
    required this.images,
    this.active = true,
    this.hasLocationEnabled = false,
    this.category = 'Temporarios',
    this.description,
    DateTime? createdAt,
    this.expiresAt,
  }) : createdAt = createdAt ?? DateTime.now();

  DateTime get effectiveExpiresAt =>
      expiresAt ?? createdAt.add(const Duration(hours: 24));

  bool get isExpired => DateTime.now().isAfter(effectiveExpiresAt);

  factory ClientPublicacaoModel.fromJson(Map<String, dynamic> json) {
    final imagesValue = json['images'];
    final imagesList = imagesValue is List
        ? imagesValue.map((e) => e.toString()).toList()
        : <String>[];

    return ClientPublicacaoModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: (json['name'] ?? '') as String,
      price: (json['price'] as num).toDouble(),
      promoPrice: json['promo_price'] != null
          ? (json['promo_price'] as num).toDouble()
          : null,
      images: imagesList,
      active: (json['active'] ?? true) as bool,
      hasLocationEnabled: (json['has_location_enabled'] ?? false) as bool,
      category: (json['category'] ?? 'Temporarios') as String,
      description: json['description'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'price': price,
      'promo_price': promoPrice,
      'images': images,
      'active': active,
      'has_location_enabled': hasLocationEnabled,
      'category': category,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'expires_at': effectiveExpiresAt.toIso8601String(),
    };
  }

  ClientPublicacaoModel copyWith({
    String? name,
    double? price,
    Object? promoPrice = _undefined,
    List<String>? images,
    bool? active,
    bool? hasLocationEnabled,
    String? category,
    Object? description = _undefined,
    Object? expiresAt = _undefined,
  }) {
    return ClientPublicacaoModel(
      id: id,
      userId: userId,
      name: name ?? this.name,
      price: price ?? this.price,
      promoPrice: promoPrice == _undefined
          ? this.promoPrice
          : promoPrice as double?,
      images: images ?? this.images,
      active: active ?? this.active,
      hasLocationEnabled: hasLocationEnabled ?? this.hasLocationEnabled,
      category: category ?? this.category,
      description: description == _undefined
          ? this.description
          : description as String?,
      createdAt: createdAt,
      expiresAt: expiresAt == _undefined
          ? this.expiresAt
          : expiresAt as DateTime?,
    );
  }
}

class _undefined {
  const _undefined();
}
