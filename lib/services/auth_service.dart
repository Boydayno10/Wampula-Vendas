import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'package:uuid/uuid.dart';

class AuthService {
  static final _supabase = Supabase.instance.client;
  static bool _sessionChecked = false;
  
  static UserModel currentUser = UserModel(
    id: 'user001',
    name: 'Usuário Wampula',
    email: 'usuario@wampula.com',
    phone: '+25884xxxxxxx',
    bairro: 'Piloto',
    isSeller: true,
    verified: true,
  );
  
  static bool isLoggedIn = false;
  
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
        // Buscar dados do perfil do usuário
        await _loadUserProfile(response.user!.id);
        isLoggedIn = true;
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
        'is_seller': true,
        'verified': true,
      });
      
      // 3. Atualizar currentUser local
      currentUser = UserModel(
        id: response.user!.id,
        name: name,
        email: email,
        phone: phone,
        bairro: bairro,
        isSeller: true,
        verified: true,
      );
      
      isLoggedIn = true;
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
              'is_seller': true,
              'verified': true,
            });
            
            currentUser = UserModel(
              id: loginResponse.user!.id,
              name: name,
              email: email,
              phone: phone,
              bairro: bairro,
              isSeller: true,
              verified: true,
            );
            
            isLoggedIn = true;
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
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      if (data != null) {
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
      } else {
        // Perfil não encontrado, criar um básico
        currentUser = UserModel(
          id: userId,
          name: 'Usuário',
          email: _supabase.auth.currentUser?.email ?? '',
          phone: '+258',
          bairro: 'Piloto',
          isSeller: true,
          verified: true,
        );
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
        isSeller: true,
        verified: true,
      );
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
        print('Erro: Usuário não autenticado');
        return false;
      }

      final updateData = {
        'name': name,
        'phone': phone,
        'bairro': bairro,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        updateData['profile_image_url'] = profileImageUrl;
      }

      await _supabase.from('profiles').update(updateData).eq('id', userId);

      // Recarregar perfil completo do banco
      await _loadUserProfile(userId);
      
      print('✅ Perfil atualizado com sucesso');

      return true;
    } catch (e) {
      print('Erro ao atualizar perfil: $e');
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
  }
  
  /// Login (método legado para compatibilidade)
  static void login() {
    isLoggedIn = true;
  }
  
  /// Logout do Supabase
  static Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
      isLoggedIn = false;
    } catch (e) {
      print('Erro ao fazer logout: $e');
    }
  }
}
