import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_model.dart';
import '../models/chat_message_model.dart';
import '../models/publication_touch_model.dart';
import 'auth_service.dart';
import 'image_upload_service.dart';

class ChatService {
  static final _supabase = Supabase.instance.client;

  static Future<ChatModel> getOrCreateChat({
    required String publicationId,
    required String ownerId,
  }) async {
    final currentUserId = AuthService.currentUser.id;
    if (currentUserId.isEmpty) {
      throw Exception('Usuário não autenticado');
    }

    final userA = currentUserId;
    final userB = ownerId;

    final response = await _supabase
        .from('chats')
        .select()
        .eq('publication_id', publicationId)
        .or(
          'and(user1_id.eq.$userA,user2_id.eq.$userB),and(user1_id.eq.$userB,user2_id.eq.$userA)',
        )
        .limit(1);

    if (response is List && response.isNotEmpty) {
      return ChatModel.fromJson(response.first as Map<String, dynamic>);
    }

    final insertResponse = await _supabase
        .from('chats')
        .insert({
          'publication_id': publicationId,
          'user1_id': userA,
          'user2_id': userB,
        })
        .select()
        .single();

    return ChatModel.fromJson(insertResponse as Map<String, dynamic>);
  }

  /// Cria ou retorna um chat direto entre o usuário atual e outro usuário,
  /// sem depender de publicação específica (usado, por exemplo, para pedidos).
  static Future<ChatModel> getOrCreateDirectChatWithUser({
    required String otherUserId,
    String? orderCode,
  }) async {
    final currentUserId = AuthService.currentUser.id;
    if (currentUserId.isEmpty) {
      throw Exception('Usuário não autenticado');
    }

    final userA = currentUserId;
    final userB = otherUserId;

    final response = await _supabase
        .from('chats')
        .select()
        .or(
          'and(user1_id.eq.$userA,user2_id.eq.$userB),and(user1_id.eq.$userB,user2_id.eq.$userA)',
        )
        .limit(1);

    if (response is List && response.isNotEmpty) {
      final existing = ChatModel.fromJson(
        response.first as Map<String, dynamic>,
      );

      // Se passarmos um código de pedido e o chat ainda não tiver,
      // associamos este chat a esse pedido.
      if (orderCode != null &&
          orderCode.isNotEmpty &&
          existing.orderCode == null) {
        try {
          await _supabase
              .from('chats')
              .update({'order_code': orderCode})
              .eq('id', existing.id);
        } catch (_) {}
      }

      return existing;
    }

    final insertResponse = await _supabase
        .from('chats')
        .insert({
          'user1_id': userA,
          'user2_id': userB,
          'publication_id': null,
          if (orderCode != null && orderCode.isNotEmpty)
            'order_code': orderCode,
        })
        .select()
        .single();

    return ChatModel.fromJson(insertResponse as Map<String, dynamic>);
  }

  static Future<List<ChatMessageModel>> loadMessages(String chatId) async {
    final response = await _supabase
        .from('chat_messages')
        .select()
        .eq('chat_id', chatId)
        .order('created_at', ascending: true);

    if (response is! List) return [];

    return response
        .map((json) => ChatMessageModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Stream<List<ChatMessageModel>> messagesStream(String chatId) {
    return _supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .map((rows) {
          final list = rows
              .map(
                (json) =>
                    ChatMessageModel.fromJson(json as Map<String, dynamic>),
              )
              .toList();
          // Garante que as mensagens fiquem sempre do mais antigo para o mais novo
          list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return list;
        });
  }

  /// Marca mensagens recebidas deste chat como lidas (para o usuário atual)
  static Future<void> markMessagesAsRead(String chatId) async {
    final currentUserId = AuthService.currentUser.id;
    if (currentUserId.isEmpty) {
      return;
    }

    try {
      await _supabase.rpc(
        'mark_chat_messages_as_read',
        params: {'p_chat_id': chatId},
      );
    } catch (e) {
      // Não quebra a tela de chat se der erro
      print('Erro ao marcar mensagens como lidas: $e');
    }
  }

  // Buscar chat por ID
  static Future<ChatModel?> getChatById(String chatId) async {
    final response = await _supabase
        .from('chats')
        .select()
        .eq('id', chatId)
        .maybeSingle();

    if (response == null) return null;
    return ChatModel.fromJson(response as Map<String, dynamic>);
  }

  // Buscar nome da publicação ligada ao chat
  static Future<String?> getPublicationName(String publicationId) async {
    final row = await _supabase
        .from('client_publications')
        .select('name')
        .eq('id', publicationId)
        .maybeSingle();

    if (row == null || row is! Map<String, dynamic>) return null;
    return row['name'] as String?;
  }

  static Future<void> sendMessage({
    required String chatId,
    required String text,
    String? imageUrl,
    String? replyToMessageId,
  }) async {
    final senderId = AuthService.currentUser.id;
    if (senderId.isEmpty) {
      throw Exception('Usuário não autenticado');
    }

    if (text.trim().isEmpty && (imageUrl == null || imageUrl.isEmpty)) {
      return;
    }

    // Inserir mensagem no chat
    await _supabase.from('chat_messages').insert({
      'chat_id': chatId,
      'sender_id': senderId,
      'message': text.trim(),
      'image_url': imageUrl,
      'reply_to_message_id': replyToMessageId,
    });

    // Criar notificação para o outro participante do chat
    try {
      final chatRow = await _supabase
          .from('chats')
          .select('user1_id, user2_id, publication_id')
          .eq('id', chatId)
          .maybeSingle();

      if (chatRow != null && chatRow is Map<String, dynamic>) {
        final user1Id = chatRow['user1_id'] as String;
        final user2Id = chatRow['user2_id'] as String;
        final publicationId = chatRow['publication_id'] as String?;

        final recipientId = senderId == user1Id ? user2Id : user1Id;

        if (recipientId.isNotEmpty && recipientId != senderId) {
          // Buscar nome de quem enviou a mensagem
          String senderName = 'Alguém';
          try {
            final profileRow = await _supabase
                .from('profiles')
                .select('name')
                .eq('id', senderId)
                .maybeSingle();

            if (profileRow != null &&
                profileRow is Map<String, dynamic> &&
                profileRow['name'] != null) {
              senderName = profileRow['name'] as String;
            }
          } catch (_) {
            // Se der erro, mantém nome genérico
          }

          // Buscar informações da publicação para montar o "assunto" da notificação
          String subject = 'Nova conversa';
          try {
            if (publicationId != null) {
              final pubRow = await _supabase
                  .from('client_publications')
                  .select('name, description')
                  .eq('id', publicationId)
                  .maybeSingle();

              if (pubRow != null && pubRow is Map<String, dynamic>) {
                final name = (pubRow['name'] ?? '') as String;
                final desc = (pubRow['description'] ?? '') as String;

                final shortName = name.length > 35
                    ? name.substring(0, 35) + '…'
                    : name;
                String shortDesc = '';
                if (desc.isNotEmpty) {
                  shortDesc = desc.length > 40
                      ? desc.substring(0, 40) + '…'
                      : desc;
                }

                subject = shortDesc.isNotEmpty
                    ? '$shortName - $shortDesc'
                    : shortName;
              }
            }
          } catch (_) {
            // Se der erro, usa assunto genérico
          }

          var preview = text.trim();
          if (preview.isEmpty && imageUrl != null && imageUrl.isNotEmpty) {
            preview = 'Nova imagem no chat';
          }

          // Nome e mensagem abreviados para caber bem na lista
          final shortSender = senderName.length > 25
              ? senderName.substring(0, 25) + '…'
              : senderName;
          final shortPreview = preview.length > 40
              ? preview.substring(0, 40) + '…'
              : preview;

          // Corpo da notificação em três linhas: nome do remetente + mensagem
          final body = '$shortSender\n$shortPreview';

          // Verificar se já existe notificação para este chat
          final existing = await _supabase
              .from('notifications')
              .select('id, read, unread_count')
              .eq('user_id', recipientId)
              .eq('related_id', chatId)
              .eq('type', 'chat')
              .maybeSingle();

          if (existing != null && existing is Map<String, dynamic>) {
            final currentUnread = existing['unread_count'] as int? ?? 0;
            final wasRead = existing['read'] as bool? ?? false;
            final newUnread = wasRead ? 1 : currentUnread + 1;

            await _supabase
                .from('notifications')
                .update({
                  'title': subject,
                  'message': body,
                  'read': false,
                  'unread_count': newUnread,
                  'created_at': DateTime.now().toIso8601String(),
                })
                .eq('id', existing['id'] as String);
          } else {
            await _supabase.from('notifications').insert({
              'user_id': recipientId,
              'title': subject,
              'message': body,
              'type': 'chat',
              'related_id': chatId,
              'unread_count': 1,
            });
          }
        }
      }
    } catch (e) {
      // Apenas loga, não quebra o envio da mensagem
      print('Erro ao criar notificação de chat: $e');
    }
  }

  /// Editar o texto de uma mensagem já enviada (apenas texto)
  static Future<void> editMessage({
    required String messageId,
    required String newText,
  }) async {
    final senderId = AuthService.currentUser.id;
    if (senderId.isEmpty) {
      throw Exception('Usuário não autenticado');
    }

    final text = newText.trim();
    if (text.isEmpty) {
      throw Exception('Mensagem não pode ser vazia.');
    }

    await _supabase
        .from('chat_messages')
        .update({'message': text})
        .eq('id', messageId)
        .eq('sender_id', senderId);
  }

  /// Apagar definitivamente uma mensagem para os dois participantes
  static Future<void> deleteMessageForBoth({
    required String messageId,
    String? imageUrl,
  }) async {
    final userId = AuthService.currentUser.id;
    if (userId.isEmpty) {
      throw Exception('Usuário não autenticado');
    }

    try {
      // Remove a imagem do Storage (se existir)
      if (imageUrl != null && imageUrl.isNotEmpty) {
        await ImageUploadService.deleteImage(imageUrl);
      }
    } catch (e) {
      // Se falhar a remoção da imagem, apenas registra o erro
      print('Erro ao deletar imagem do chat: $e');
    }

    await _supabase
        .from('chat_messages')
        .delete()
        // Garante que só o remetente consiga apagar para os dois
        .eq('id', messageId)
        .eq('sender_id', userId);
  }

  static Future<String> uploadChatImage(String localPath) async {
    // Usa o bucket dedicado para imagens de chat
    return ImageUploadService.uploadImage(localPath, folder: 'chat-images');
  }

  static Future<PublicationTouchModel> registerTouch({
    required String publicationId,
    required String ownerId,
  }) async {
    final currentUserId = AuthService.currentUser.id;
    if (currentUserId.isEmpty) {
      throw Exception('Usuário não autenticado');
    }

    final response = await _supabase
        .from('publication_touches')
        .insert({
          'publication_id': publicationId,
          'user_id': currentUserId,
          'owner_id': ownerId,
        })
        .select()
        .single();

    return PublicationTouchModel.fromJson(response as Map<String, dynamic>);
  }
}
