class ChatMessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String message;
  final String? imageUrl;
  final DateTime createdAt;
  final String? replyToMessageId;
  final DateTime? readAt;
  final bool isAdminMessage;

  ChatMessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.message,
    this.imageUrl,
    required this.createdAt,
    this.replyToMessageId,
    this.readAt,
    this.isAdminMessage = false,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String,
      chatId: json['chat_id'] as String,
      senderId: json['sender_id'] as String,
      message: (json['message'] ?? '') as String,
      imageUrl: json['image_url'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      replyToMessageId: json['reply_to_message_id'] as String?,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at']?.toString() ?? '')
          : null,
      isAdminMessage:
          (json['is_admin_message'] as bool?) ?? false,
    );
  }
}
