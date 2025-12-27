import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// Serviço de upload de imagens para Supabase Storage
/// Gerencia uploads de imagens para buckets públicos
class ImageUploadService {
  static final _supabase = Supabase.instance.client;

  /// Faz upload de uma imagem para o Supabase Storage
  /// 
  /// [localPath] - Caminho do arquivo local
  /// [folder] - Nome do bucket ('product-images', 'profile-images', 'store-banners')
  /// 
  /// Retorna a URL pública da imagem
  static Future<String> uploadImage(String localPath, {required String folder}) async {
    try {
      // Se já for uma URL do Supabase ou asset, retorna direto
      if (localPath.startsWith('http') || localPath.startsWith('assets/')) {
        return localPath;
      }

      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception('Arquivo não encontrado: $localPath');
      }

      // Obter ID do usuário autenticado
      final userId = AuthService.currentUser.id;
      if (userId.isEmpty) {
        throw Exception('Usuário não autenticado');
      }

      // Criar nome único para o arquivo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = localPath.split('.').last;
      final fileName = '$userId/${timestamp}.$extension';

      // Fazer upload para o bucket correto
      await _supabase.storage
          .from(folder)
          .upload(fileName, file, fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
          ));

      // Obter URL pública
      final publicUrl = _supabase.storage
          .from(folder)
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      throw Exception('Erro ao fazer upload da imagem: $e');
    }
  }

  /// Faz upload de múltiplas imagens
  static Future<List<String>> uploadMultipleImages(
    List<String> localPaths, {
    required String folder,
  }) async {
    try {
      final uploadedUrls = <String>[];

      for (final path in localPaths) {
        final url = await uploadImage(path, folder: folder);
        uploadedUrls.add(url);
      }

      return uploadedUrls;
    } catch (e) {
      throw Exception('Erro ao fazer upload das imagens: $e');
    }
  }

  /// Deleta uma imagem do Supabase Storage
  static Future<void> deleteImage(String imageUrl) async {
    try {
      // Ignorar assets e URLs externas
      if (imageUrl.startsWith('assets/') || !imageUrl.contains('supabase')) {
        return;
      }

      // Extrair bucket e caminho do arquivo da URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      
      // URL format: .../storage/v1/object/public/{bucket}/{path}
      if (pathSegments.length >= 5 && pathSegments[2] == 'object' && pathSegments[3] == 'public') {
        final bucket = pathSegments[4];
        final filePath = pathSegments.sublist(5).join('/');
        
        await _supabase.storage
            .from(bucket)
            .remove([filePath]);
      }
    } catch (e) {
      // Ignora erros de deleção
      print('Erro ao deletar imagem: $e');
    }
  }

  /// Verifica se a imagem é um asset
  static bool isAssetImage(String imageUrl) {
    return imageUrl.startsWith('assets/');
  }

  /// Verifica se a imagem é uma URL remota
  static bool isRemoteImage(String imageUrl) {
    return imageUrl.startsWith('http');
  }

  /// Verifica se a imagem é um arquivo local
  static bool isLocalFile(String imageUrl) {
    return !isAssetImage(imageUrl) && 
           !isRemoteImage(imageUrl) && 
           File(imageUrl).existsSync();
  }

  /// Upload de imagem de produto
  static Future<String> uploadProductImage(String localPath) async {
    return uploadImage(localPath, folder: 'product-images');
  }

  /// Upload de imagem de perfil
  static Future<String> uploadProfileImage(String localPath) async {
    return uploadImage(localPath, folder: 'profile-images');
  }

  /// Upload de banner de loja
  static Future<String> uploadStoreBanner(String localPath) async {
    return uploadImage(localPath, folder: 'store-banners');
  }
}
