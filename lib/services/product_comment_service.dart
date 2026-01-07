import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_comment_model.dart';
import 'auth_service.dart';

class ProductCommentService {
  static final _supabase = Supabase.instance.client;

  /// Lista comentários de um produto/publicação (mais recentes primeiro)
  static Future<List<ProductCommentModel>> getByProduct(String productId) async {
    try {
      final response = await _supabase
          .from('product_comments')
          .select()
          .eq('product_id', productId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => ProductCommentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao buscar comentários do produto $productId: $e');
      return [];
    }
  }

  /// Cria um novo comentário para o produto/publicação atual
  static Future<void> addComment({
    required String productId,
    required String text,
    int? rating,
    String? parentId,
    String? imageUrl,
  }) async {
    try {
      final user = AuthService.currentUser;

      await _supabase.from('product_comments').insert({
        'product_id': productId,
        'user_id': user.id,
        'user_name': user.name,
        'rating': rating,
        'parent_id': parentId,
        'image_url': imageUrl,
        'text': text,
      });
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao adicionar comentário para $productId: $e');
      rethrow;
    }
  }

  /// Atualiza o texto/imagem de um comentário existente (apenas conteúdo)
  static Future<void> updateComment({
    required String commentId,
    required String text,
    String? imageUrl,
  }) async {
    try {
      await _supabase
          .from('product_comments')
          .update({
            'text': text,
            'image_url': imageUrl,
          })
          .eq('id', commentId);
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao atualizar comentário $commentId: $e');
      rethrow;
    }
  }

  /// Remove um comentário específico (usado pelo dono da publicação ou autor)
  static Future<void> deleteComment(String commentId) async {
    try {
      await _supabase
          .from('product_comments')
          .delete()
          .eq('id', commentId);
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao deletar comentário $commentId: $e');
      rethrow;
    }
  }

  /// Busca reações (curtidas/descurtidas) para uma lista de comentários
  /// Retorna um mapa: commentId -> { 'likes': int, 'dislikes': int, 'myReaction': 'like'|'dislike'|null }
  static Future<Map<String, Map<String, dynamic>>> getReactionsForComments(
    List<String> commentIds,
  ) async {
    if (commentIds.isEmpty) return {};

    try {
      final currentUserId = AuthService.currentUser.id;

      final response = await _supabase
          .from('product_comment_reactions')
          .select()
          .inFilter('comment_id', commentIds);

      final result = <String, Map<String, dynamic>>{};

      for (final row in response as List) {
        final commentId = row['comment_id'] as String;
        final userId = row['user_id'] as String;
        final type = (row['type'] ?? '') as String; // 'like' ou 'dislike'

        final entry = result.putIfAbsent(commentId, () {
          return {
            'likes': 0,
            'dislikes': 0,
            'myReaction': null,
          };
        });

        if (type == 'like') {
          entry['likes'] = (entry['likes'] as int) + 1;
        } else if (type == 'dislike') {
          entry['dislikes'] = (entry['dislikes'] as int) + 1;
        }

        if (userId == currentUserId) {
          entry['myReaction'] = type;
        }
      }

      return result;
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao buscar reações dos comentários: $e');
      return {};
    }
  }

  /// Alterna reação (curtir/descurtir) para o comentário atual
  static Future<void> toggleReaction({
    required String commentId,
    required bool isLike,
  }) async {
    try {
      final userId = AuthService.currentUser.id;
      if (userId.isEmpty) {
        throw Exception('Usuário não autenticado');
      }

      final existing = await _supabase
          .from('product_comment_reactions')
          .select()
          .eq('comment_id', commentId)
          .eq('user_id', userId)
          .maybeSingle();

      final newType = isLike ? 'like' : 'dislike';

      if (existing == null) {
        // Criar nova reação
        await _supabase.from('product_comment_reactions').insert({
          'comment_id': commentId,
          'user_id': userId,
          'type': newType,
        });
      } else {
        final currentType = (existing['type'] ?? '') as String;
        if (currentType == newType) {
          // Já tem a mesma reação -> remove (toggle off)
          await _supabase
              .from('product_comment_reactions')
              .delete()
              .eq('id', existing['id']);
        } else {
          // Atualiza tipo de reação
          await _supabase
              .from('product_comment_reactions')
              .update({'type': newType})
              .eq('id', existing['id']);
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao alternar reação para comentário $commentId: $e');
      rethrow;
    }
  }
}
