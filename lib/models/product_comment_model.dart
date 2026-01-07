class ProductCommentModel {
  final String id;
  final String productId;
  final String userId;
  final String userName;
  final int? rating; // 1 a 5 (opcional)
  final String? parentId; // comentário pai (para respostas)
  final String? imageUrl; // imagem opcional anexada
  final String text;
  final DateTime createdAt;

  ProductCommentModel({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    this.rating,
    this.parentId,
    this.imageUrl,
    required this.text,
    required this.createdAt,
  });

  factory ProductCommentModel.fromJson(Map<String, dynamic> json) {
    return ProductCommentModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      userId: json['user_id'] as String,
      userName: (json['user_name'] ?? '') as String,
      rating: json['rating'] as int?,
      parentId: json['parent_id'] as String?,
      imageUrl: json['image_url'] as String?,
      text: (json['text'] ?? '') as String,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
