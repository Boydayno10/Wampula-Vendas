import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client_publicacao_model.dart';
import '../models/seller_product_model.dart';
import 'auth_service.dart';
import 'image_upload_service.dart';
import 'seller_product_service.dart';

class ClientPublicacaoService {
  static final _supabase = Supabase.instance.client;

  /// Busca publicações do cliente logado, limpando antes as expiradas.
  ///
  /// [nameQuery] - filtro por nome (busca parcial, case-insensitive).
  /// [statusFilter] - 'Ativas', 'Inativas' ou null para todos.
  static Future<List<ClientPublicacaoModel>> getMyPublications({
    String? nameQuery,
    String? statusFilter,
  }) async {
    final userId = AuthService.currentUser.id;
    if (userId.isEmpty) return [];

    // A limpeza de expiradas agora deve ser feita via função agendada
    // no Supabase. Removemos a chamada direta aqui para evitar qualquer
    // impacto inesperado em publicações recém-criadas.

    var query = _supabase
        .from('client_publications')
        .select()
        .eq('user_id', userId);

    if (statusFilter == 'Ativas') {
      query = query.eq('active', true);
    } else if (statusFilter == 'Inativas') {
      query = query.eq('active', false);
    }

    final trimmed = nameQuery?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      query = query.ilike('name', '%$trimmed%');
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List)
        .map((json) => ClientPublicacaoModel.fromJson(json))
        .toList();
  }

  /// Busca uma publicação de cliente por ID (independente de quem seja o dono).
  static Future<ClientPublicacaoModel?> getById(String id) async {
    final response = await _supabase
        .from('client_publications')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return ClientPublicacaoModel.fromJson(response as Map<String, dynamic>);
  }

  /// Busca publicações públicas (ativas e não expiradas) de um usuário específico.
  static Future<List<ClientPublicacaoModel>> getPublicationsForUser(
    String userId,
  ) async {
    if (userId.isEmpty) return [];

    final nowIso = DateTime.now().toIso8601String();

    final response = await _supabase
        .from('client_publications')
        .select()
        .eq('user_id', userId)
        .eq('active', true)
        .gte('expires_at', nowIso)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => ClientPublicacaoModel.fromJson(json))
        .toList();
  }

  /// Cria nova publicação para o cliente logado.
  static Future<void> createPublication({
    required String name,
    required double price,
    double? promoPrice,
    required String description,
    required List<String> localImagePaths,
    required bool hasLocationEnabled,
    String? locationAddress,
    double? latitude,
    double? longitude,
    String? categorySubcategoryId,
    String? bannerImagePath,
    String descriptionAlignment = 'left',
    bool descriptionBold = false,
    bool descriptionItalic = false,
  }) async {
    final userId = AuthService.currentUser.id;
    if (userId.isEmpty) {
      throw Exception('Usuário não autenticado');
    }

    // Upload das imagens principais (até 5)
    final uploadedUrls = <String>[];
    for (final path in localImagePaths) {
      if (uploadedUrls.length >= 5) break;

      if (path.startsWith('http') || path.startsWith('assets/')) {
        uploadedUrls.add(path);
      } else {
        final url = await ImageUploadService.uploadProductImage(path);
        uploadedUrls.add(url);
      }
    }

    if (uploadedUrls.isEmpty) {
      uploadedUrls.add('assets/images/default.png');
    }

    // Upload da imagem de banner (opcional)
    String? bannerImageUrl;
    if (bannerImagePath != null && bannerImagePath.isNotEmpty) {
      if (bannerImagePath.startsWith('http') ||
          bannerImagePath.startsWith('assets/')) {
        bannerImageUrl = bannerImagePath;
      } else {
        bannerImageUrl = await ImageUploadService.uploadProductBannerImage(
          bannerImagePath,
        );
      }
    }

    final now = DateTime.now();
    final publicationId = AuthService.generateUuid();

    final publication = ClientPublicacaoModel(
      id: publicationId,
      userId: userId,
      name: name,
      price: price,
      promoPrice: promoPrice,
      images: uploadedUrls,
      active: true,
      hasLocationEnabled: hasLocationEnabled,
      category: 'Temporarios',
      description: description,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
    );

    // 1) Salvar na tabela de publicações do cliente (controle de 24h)
    await _supabase.from('client_publications').insert(publication.toJson());

    // 2) Criar também um produto "normal" na tabela products,
    // usando o mesmo ID, para aparecer na Home e nas buscas

    // Mapeamento de preço/promoção para o modelo de produto:
    // - Se houver promoPrice: price = promoPrice, oldPrice = price original
    // - Caso contrário: price = price original, oldPrice = null
    final double productPrice;
    final double? oldPrice;
    if (promoPrice != null) {
      productPrice = promoPrice;
      oldPrice = price;
    } else {
      productPrice = price;
      oldPrice = null;
    }

    final storeName =
      // Apenas vendedores têm loja; clientes publicam sem loja associada
      (AuthService.currentUser.isSeller
        ? AuthService.currentUser.storeName
        : null) ??
      AuthService.currentUser.name ??
      'Cliente Wampula';

    final sellerProduct = SellerProductModel(
      id: publicationId,
      sellerId: userId,
      sellerStoreName: storeName,
      name: name,
      price: productPrice,
      oldPrice: oldPrice,
      images: uploadedUrls,
      bannerImage: bannerImageUrl,
      description: description,
      category: 'Temporarios',
      categorySubcategoryId: categorySubcategoryId,
      stock: 1,
      active: true,
      soldCount: 0,
      popularity: 50.0,
      transportPrice: 0,
      hasSizeOption: false,
      hasColorOption: false,
      hasAgeOption: false,
      hasStorageOption: false,
      hasPantSizeOption: false,
      hasShoeSizeOption: false,
      hasLocationEnabled: hasLocationEnabled,
      storeLatitude: hasLocationEnabled ? latitude : null,
      storeLongitude: hasLocationEnabled ? longitude : null,
      storeAddress: hasLocationEnabled
          ? (locationAddress?.isNotEmpty == true
                ? locationAddress
                : AuthService.currentUser.bairro)
          : null,
      descriptionAlignment: descriptionAlignment,
      descriptionBold: descriptionBold,
      descriptionItalic: descriptionItalic,
    );

    await SellerProductService.add(sellerProduct);
  }

  /// Atualiza uma publicação existente.
  /// Se a publicação estiver expirada, renova automaticamente com +24 horas.
  static Future<void> updatePublication(
    ClientPublicacaoModel publication, {
    List<String>? updatedImagePaths,
    String? locationAddress,
    double? latitude,
    double? longitude,
    String? categorySubcategoryId,
    String? bannerImagePath,
    String descriptionAlignment = 'left',
    bool descriptionBold = false,
    bool descriptionItalic = false,
  }) async {
    final userId = AuthService.currentUser.id;
    if (userId.isEmpty) {
      throw Exception('Usuário não autenticado');
    }

    var images = publication.images;
    if (updatedImagePaths != null) {
      final uploadedUrls = <String>[];
      for (final path in updatedImagePaths) {
        // Limitar a no máximo 5 imagens
        if (uploadedUrls.length >= 5) break;

        if (path.startsWith('http') || path.startsWith('assets/')) {
          uploadedUrls.add(path);
        } else {
          final url = await ImageUploadService.uploadProductImage(path);
          uploadedUrls.add(url);
        }
      }
      // Se ainda não houver imagens (cliente removeu todas), usar padrão
      images = uploadedUrls.isEmpty
          ? ['assets/images/default.png']
          : uploadedUrls;
    }

    // Sempre usa o valor atual do banco para decidir se está expirada,
    // garantindo que múltiplas edições não fiquem renovando o prazo.
    final existing = await getById(publication.id);
    final baseExpiresAt = existing?.effectiveExpiresAt ??
        publication.effectiveExpiresAt;
    final isExpired = DateTime.now().isAfter(baseExpiresAt);

    final updated = isExpired
        // Republicar: adicionar 24 horas a partir de agora
        ? publication.copyWith(
            images: images,
            expiresAt: DateTime.now().add(const Duration(hours: 24)),
          )
        : publication.copyWith(
            images: images,
          );

    // 1) Atualizar registro da publicação do cliente
    await _supabase
        .from('client_publications')
        .update(updated.toJson())
        .eq('id', updated.id)
        .eq('user_id', userId);

    // 2) Atualizar também o produto na tabela products

    // Mesma regra de preço/promocional usada na criação
    final double productPrice;
    final double? oldPrice;
    if (updated.promoPrice != null) {
      productPrice = updated.promoPrice!;
      oldPrice = updated.price;
    } else {
      productPrice = updated.price;
      oldPrice = null;
    }

    // Upload/definição da imagem de banner (opcional)
    String? bannerImageUrl;
    if (bannerImagePath != null) {
      if (bannerImagePath.isEmpty) {
        bannerImageUrl = null;
      } else if (bannerImagePath.startsWith('http') ||
          bannerImagePath.startsWith('assets/')) {
        bannerImageUrl = bannerImagePath;
      } else {
        bannerImageUrl = await ImageUploadService.uploadProductBannerImage(
          bannerImagePath,
        );
      }
    }

    final existingProduct = await SellerProductService.getById(updated.id);

    if (existingProduct != null) {
      final updatedProduct = existingProduct.copyWith(
        name: updated.name,
        price: productPrice,
        oldPrice: oldPrice,
        description: updated.description ?? existingProduct.description,
        category: 'Temporarios',
        categorySubcategoryId: categorySubcategoryId,
        images: images,
        stock: 1,
        active: updated.active,
        transportPrice: 0,
        hasSizeOption: false,
        hasColorOption: false,
        hasAgeOption: false,
        hasStorageOption: false,
        hasPantSizeOption: false,
        hasShoeSizeOption: false,
        hasLocationEnabled: updated.hasLocationEnabled,
        storeLatitude: updated.hasLocationEnabled
            ? latitude ?? existingProduct.storeLatitude
            : null,
        storeLongitude: updated.hasLocationEnabled
            ? longitude ?? existingProduct.storeLongitude
            : null,
        storeAddress: updated.hasLocationEnabled
            ? ((locationAddress?.isNotEmpty == true)
                  ? locationAddress
                  : (existingProduct.storeAddress ??
                        AuthService.currentUser.bairro))
            : null,
        bannerImage: bannerImageUrl ?? existingProduct.bannerImage,
        descriptionAlignment: descriptionAlignment,
        descriptionBold: descriptionBold,
        descriptionItalic: descriptionItalic,
      );

      await SellerProductService.update(updatedProduct);
    } else {
        final storeName =
          (AuthService.currentUser.isSeller
              ? AuthService.currentUser.storeName
              : null) ??
          AuthService.currentUser.name ??
          'Cliente Wampula';

      final newProduct = SellerProductModel(
        id: updated.id,
        sellerId: userId,
        sellerStoreName: storeName,
        name: updated.name,
        price: productPrice,
        oldPrice: oldPrice,
        images: images,
        bannerImage: bannerImageUrl,
        description: updated.description ?? 'Publicação de cliente',
        category: 'Temporarios',
        categorySubcategoryId: categorySubcategoryId,
        stock: 1,
        active: updated.active,
        soldCount: 0,
        popularity: 50.0,
        transportPrice: 0,
        hasSizeOption: false,
        hasColorOption: false,
        hasAgeOption: false,
        hasStorageOption: false,
        hasPantSizeOption: false,
        hasShoeSizeOption: false,
        hasLocationEnabled: updated.hasLocationEnabled,
        storeLatitude: updated.hasLocationEnabled ? latitude : null,
        storeLongitude: updated.hasLocationEnabled ? longitude : null,
        storeAddress: updated.hasLocationEnabled
            ? ((locationAddress?.isNotEmpty == true)
                  ? locationAddress
                  : AuthService.currentUser.bairro)
            : null,
        descriptionAlignment: descriptionAlignment,
        descriptionBold: descriptionBold,
        descriptionItalic: descriptionItalic,
      );

      await SellerProductService.add(newProduct);
    }
  }

  static Future<void> setActive(
    ClientPublicacaoModel publication,
    bool active,
  ) async {
    final userId = AuthService.currentUser.id;
    if (userId.isEmpty) return;

    final updated = publication.copyWith(active: active);

    // Atualiza flag na tabela de publicações
    await _supabase
        .from('client_publications')
        .update({'active': active})
        .eq('id', updated.id)
        .eq('user_id', userId);

    // Atualiza também o produto correspondente
    try {
      await _supabase
          .from('products')
          .update({'active': active})
          .eq('id', updated.id)
          .eq('seller_id', userId);
    } catch (_) {
      // Não quebrar a UX caso falhe
    }
  }

  static Future<void> deletePublication(String id) async {
    final userId = AuthService.currentUser.id;
    if (userId.isEmpty) return;

    // Apagar publicação do cliente
    await _supabase
        .from('client_publications')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);

    // Apagar também o produto correspondente
    try {
      await _supabase
          .from('products')
          .delete()
          .eq('id', id)
          .eq('seller_id', userId);
    } catch (_) {
      // Silenciar erro para não afetar a UX
    }
  }

  /// Remove publicações expiradas (>= 24h) usando função RPC se existir,
  /// ou diretamente pela coluna expires_at.
  static Future<void> _cleanupExpired() async {
    try {
      final cutoff = DateTime.now().toUtc();

      // Buscar IDs expirados primeiro
      final expired = await _supabase
          .from('client_publications')
          .select('id')
          .lte('expires_at', cutoff.toIso8601String());

      if (expired is! List || expired.isEmpty) return;

      final ids = expired
          .map((e) => e['id'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      if (ids.isEmpty) return;

      // Apagar das duas tabelas: publicações e produtos
      await _supabase.from('client_publications').delete().inFilter('id', ids);

      await _supabase.from('products').delete().inFilter('id', ids);
    } catch (_) {
      // Silencia erros de limpeza para não quebrar a UX.
    }
  }
}
