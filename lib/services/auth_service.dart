import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'package:uuid/uuid.dart';
import 'payment_service.dart';
import 'notification_service.dart';
import 'order_service.dart';
import 'product_analytics_service.dart';
import 'cart_service.dart';

class AuthService {
  static final _supabase = Supabase.instance.client;
  static bool _sessionChecked = false;

  static UserModel currentUser = UserModel(
    id: 'user001',
    name: 'Usuário Wampula',
    email: 'usuario@wampula.com',
    phone: '+25884xxxxxxx',
    bairro: 'Piloto',
    isSeller: false,
    verified: false,
  );

  static final ValueNotifier<UserModel> currentUserNotifier =
      ValueNotifier<UserModel>(currentUser);

  static bool isLoggedIn = false;

  static void _notifyCurrentUserChanged() {
    currentUserNotifier.value = currentUser;
  }

  /// Verifica se há uma sessão ativa ao iniciar o app (login persistente)
  static Future<void> checkSession() async {
    if (_sessionChecked) return;
    _sessionChecked = true;

    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        print('✅ Sessão ativa encontrada para: ${session.user.email}');
        await _loadUserProfile(session.user.id);
        isLoggedIn = true;

        // Carregar dados do usuário
        await _loadUserData();
      } else {
        print('ℹ️ Nenhuma sessão ativa encontrada');
      }
    } catch (e) {
      print('❌ Erro ao verificar sessão: $e');
    }
  }

  /// Verifica se o email já existe no Supabase
  static Future<bool> emailExists(String email) async {
    try {
      // Verifica se existe um perfil com esse email
      final response = await _supabase
          .from('profiles')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      // Se retornou algum dado, o email existe
      return response != null;
    } catch (e) {
      print('Erro ao verificar email: $e');
      // Em caso de erro, assume que não existe para permitir cadastro
      return false;
    }
  }

  /// Login com email e senha usando Supabase Auth
  static Future<bool> loginWithEmail(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Carregar dados do usuário
        await _loadUserData();

        // Buscar dados do perfil do usuário
        await _loadUserProfile(response.user!.id);
        isLoggedIn = true;
        _notifyCurrentUserChanged();
        return true;
      }

      return false;
    } catch (e) {
      print('Erro no login: $e');
      return false;
    }
  }

  /// Cria novo usuário com email e senha no Supabase Auth
  static Future<bool> createUserWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String bairro,
  }) async {
    try {
      // 1. Criar usuário no Supabase Auth (sem confirmação de email)
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: null, // Sem redirecionamento
      );

      if (response.user == null) {
        print('Erro: Usuário não foi criado');
        return false;
      }

      // 2. Salvar dados do perfil na tabela profiles
      await _supabase.from('profiles').insert({
        'id': response.user!.id,
        'name': name,
        'email': email,
        'phone': phone,
        'bairro': bairro,
        // Novo usuário entra sempre como cliente (não vendedor)
        'is_seller': false,
        'verified': false,
      });

      // 3. Atualizar currentUser local
      currentUser = UserModel(
        id: response.user!.id,
        name: name,
        email: email,
        phone: phone,
        bairro: bairro,
        isSeller: false,
        verified: false,
      );

      isLoggedIn = true;
      _notifyCurrentUserChanged();
      return true;
    } on AuthException catch (e) {
      print('Erro Auth ao criar usuário: ${e.message}');

      // Se o erro for de confirmação de email, ainda consideramos sucesso
      // pois o usuário foi criado, apenas precisa confirmar email
      if (e.message.contains('confirmation') ||
          e.message.contains('email') ||
          e.statusCode == '500') {
        print('Usuário criado mas com problema no email de confirmação');
        // Tentar buscar o usuário recém criado
        try {
          final loginResponse = await _supabase.auth.signInWithPassword(
            email: email,
            password: password,
          );

          if (loginResponse.user != null) {
            // Salvar perfil
            await _supabase.from('profiles').upsert({
              'id': loginResponse.user!.id,
              'name': name,
              'email': email,
              'phone': phone,
              'bairro': bairro,
              'is_seller': false,
              'verified': false,
            });

            currentUser = UserModel(
              id: loginResponse.user!.id,
              name: name,
              email: email,
              phone: phone,
              bairro: bairro,
              isSeller: false,
              verified: false,
            );

            isLoggedIn = true;
            _notifyCurrentUserChanged();
            return true;
          }
        } catch (e) {
          print('Erro ao fazer login após criar usuário: $e');
        }
      }

      return false;
    } catch (e) {
      print('Erro ao criar usuário: $e');
      return false;
    }
  }

  /// Carrega o perfil do usuário do banco de dados
  static Future<void> _loadUserProfile(String userId) async {
    try {
      print('🔄 Carregando perfil do usuário $userId...');
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data != null) {
        print(
          '📥 Perfil carregado do banco: ${data['name']}, Bairro: ${data['bairro']}',
        );
        currentUser = UserModel(
          id: data['id'],
          name: data['name'] ?? '',
          email: data['email'] ?? '',
          phone: data['phone'] ?? '',
          bairro: data['bairro'] ?? 'Piloto',
          isSeller: data['is_seller'] ?? false,
          verified: data['verified'] ?? false,
          profileImageUrl: data['profile_image_url'],
          storeName: data['store_name'],
          storeDescription: data['store_description'],
          storeBanner: data['store_banner'],
        );
        _notifyCurrentUserChanged();
        print('✅ currentUser atualizado - Bairro: ${currentUser.bairro}');
      } else {
        // Perfil não encontrado, criar um básico
        currentUser = UserModel(
          id: userId,
          name: 'Usuário',
          email: _supabase.auth.currentUser?.email ?? '',
          phone: '+258',
          bairro: 'Piloto',
          isSeller: false,
          verified: false,
        );
        _notifyCurrentUserChanged();
      }
    } catch (e) {
      print('Erro ao carregar perfil: $e');
      // Em caso de erro, criar usuário básico
      currentUser = UserModel(
        id: userId,
        name: 'Usuário',
        email: _supabase.auth.currentUser?.email ?? '',
        phone: '+258',
        bairro: 'Piloto',
        isSeller: false,
        verified: false,
      );
      _notifyCurrentUserChanged();
    }
  }

  /// Recarrega o perfil do usuário atual do Supabase (método público)
  static Future<void> reloadCurrentUserProfile() async {
    if (_supabase.auth.currentUser != null) {
      await _loadUserProfile(_supabase.auth.currentUser!.id);
    }
  }

  /// Atualiza o perfil do usuário no Supabase
  static Future<bool> updateProfile({
    required String name,
    required String phone,
    required String bairro,
    String? profileImageUrl,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('❌ Erro: Usuário não autenticado');
        return false;
      }

      print('🔑 User ID autenticado: $userId');
      print('📧 Email do usuário: ${_supabase.auth.currentUser?.email}');

      final updateData = {
        'name': name,
        'phone': phone,
        'bairro': bairro,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        updateData['profile_image_url'] = profileImageUrl;
      }

      print('📤 Tentando atualizar perfil...');
      print('   ID: $userId');
      print('   Dados: $updateData');

      // Primeiro, verificar se o registro existe
      final checkExists = await _supabase
          .from('profiles')
          .select('id, name, bairro')
          .eq('id', userId)
          .maybeSingle();

      if (checkExists == null) {
        print('❌ ERRO: Perfil não encontrado no banco para o usuário $userId');
        return false;
      }

      print(
        '✅ Perfil encontrado: ${checkExists['name']} - Bairro atual: ${checkExists['bairro']}',
      );

      // Executar update e verificar resultado
      final response = await _supabase
          .from('profiles')
          .update(updateData)
          .eq('id', userId)
          .select();

      print('📦 Resposta do Supabase: $response');

      if (response.isEmpty) {
        print('⚠️ AVISO: Nenhuma linha foi atualizada!');
        print('   Isso pode ser um problema de política RLS.');
        print('   Execute o script fix_profiles_update_policy.sql no Supabase');
        return false;
      }

      print(
        '✅ Update bem-sucedido! Novo bairro no banco: ${response[0]['bairro']}',
      );

      // Atualizar localmente antes de recarregar
      currentUser.name = name;
      currentUser.phone = phone;
      currentUser.bairro = bairro;
      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        currentUser.profileImageUrl = profileImageUrl;
      }

      print('💾 Dados locais atualizados - Bairro: ${currentUser.bairro}');

      // Recarregar perfil completo do banco para confirmar
      await _loadUserProfile(userId);

      print(
        '🎉 Perfil atualizado com sucesso - Bairro final: ${currentUser.bairro}',
      );

      return true;
    } catch (e, stackTrace) {
      print('❌ Erro ao atualizar perfil: $e');
      print('📍 Stack trace: $stackTrace');
      return false;
    }
  }

  /// Atualiza informações da loja no Supabase
  static Future<bool> updateStoreInfo({
    required String storeName,
    required String storeDescription,
    String? storeBanner,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('Erro: Usuário não autenticado');
        return false;
      }

      final updateData = {
        'store_name': storeName,
        'store_description': storeDescription,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (storeBanner != null && storeBanner.isNotEmpty) {
        updateData['store_banner'] = storeBanner;
      }

      await _supabase.from('profiles').update(updateData).eq('id', userId);

      // Recarregar perfil completo do banco
      await _loadUserProfile(userId);

      print('✅ Informações da loja atualizadas com sucesso');

      return true;
    } catch (e) {
      print('Erro ao atualizar loja: $e');
      return false;
    }
  }

  /// Gera um UUID válido para novos registros
  static String generateUuid() {
    return const Uuid().v4();
  }

  /// Cria novo usuário (método legado para compatibilidade)
  static void createUser(UserModel user) {
    currentUser = user;
    isLoggedIn = true;
    _notifyCurrentUserChanged();
  }

  /// Login (método legado para compatibilidade)
  static void login() {
    isLoggedIn = true;
  }

  /// Logout do Supabase
  static Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
      // Limpa dados de interação e recomendações em memória
      ProductAnalyticsService.clearUserInteractions();
      CartService.clear();
      isLoggedIn = false;
    } catch (e) {
      print('Erro ao fazer logout: $e');
    }
  }

  /// Carrega os dados do usuário (números de pagamento, notificações, pedidos)
  static Future<void> _loadUserData() async {
    try {
      // Carregar em paralelo para melhor performance
      await Future.wait([
        PaymentService.loadPaymentNumbers(),
        NotificationService.loadNotifications(),
        OrderService().loadOrders(),
        CartService.loadFromSupabase(),
      ]);
      print('✅ Dados do usuário carregados com sucesso');
    } catch (e) {
      print('❌ Erro ao carregar dados do usuário: $e');
    }
  }

  /// Busca o perfil de qualquer usuário por ID, sem alterar o currentUser.
  static Future<UserModel?> fetchUserProfileById(String userId) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;

      return UserModel(
        id: data['id'] as String,
        name: (data['name'] ?? '') as String,
        email: (data['email'] ?? '') as String,
        phone: (data['phone'] ?? '') as String,
        bairro: (data['bairro'] ?? 'Piloto') as String,
        isSeller: (data['is_seller'] ?? false) as bool,
        verified: (data['verified'] ?? false) as bool,
        profileImageUrl: data['profile_image_url'] as String?,
        storeName: data['store_name'] as String?,
        storeDescription:
            (data['store_description'] as String?) ?? 'Bem-vindo à nossa loja!',
        storeBanner: data['store_banner'] as String?,
      );
    } catch (e) {
      print('Erro ao buscar perfil por ID ($userId): $e');
      return null;
    }
  }
}
