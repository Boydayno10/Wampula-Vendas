class PublicationTouchModel {
  final String id;
  final String publicationId;
  final String userId;
  final String ownerId;
  final DateTime createdAt;

  PublicationTouchModel({
    required this.id,
    required this.publicationId,
    required this.userId,
    required this.ownerId,
    required this.createdAt,
  });

  factory PublicationTouchModel.fromJson(Map<String, dynamic> json) {
    return PublicationTouchModel(
      id: json['id'] as String,
      publicationId: json['publication_id'] as String,
      userId: json['user_id'] as String,
      ownerId: json['owner_id'] as String,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
