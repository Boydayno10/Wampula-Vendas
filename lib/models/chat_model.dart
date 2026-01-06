class ChatModel {
  final String id;
  final String? publicationId;
  final String user1Id;
  final String user2Id;
  final DateTime createdAt;
  final String? orderCode;

  ChatModel({
    required this.id,
    required this.publicationId,
    required this.user1Id,
    required this.user2Id,
    required this.createdAt,
    this.orderCode,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'] as String,
      publicationId: json['publication_id'] as String?,
      user1Id: json['user1_id'] as String,
      user2Id: json['user2_id'] as String,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      orderCode: json['order_code'] as String?,
    );
  }
}
