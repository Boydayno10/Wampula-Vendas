import '../models/mpesa_number_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class PaymentService {
  static final _supabase = Supabase.instance.client;
  static final List<MpesaNumber> _numbers = [];

  static List<MpesaNumber> get numbers => _numbers;

  /// Carregar números de pagamento do Supabase
  static Future<void> loadPaymentNumbers() async {
    try {
      if (!AuthService.isLoggedIn) return;

      final userId = AuthService.currentUser.id;
      final response = await _supabase
          .from('payment_numbers')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      _numbers.clear();
      for (var item in response) {
        _numbers.add(
          MpesaNumber(
            id: item['id'].toString(),
            number: item['number'],
            isPrimary: item['is_primary'] ?? false,
          ),
        );
      }
    } catch (e) {
      print('Erro ao carregar números de pagamento: $e');
    }
  }

  // ➕ Adicionar número e salvar no Supabase
  static Future<void> addNumber(String number) async {
    try {
      if (!AuthService.isLoggedIn) return;

      final userId = AuthService.currentUser.id;
      final isFirst = _numbers.isEmpty;

      // Salvar no Supabase
      final response = await _supabase
          .from('payment_numbers')
          .insert({
            'user_id': userId,
            'number': number,
            'is_primary': isFirst,
          })
          .select()
          .single();

      // Adicionar localmente
      _numbers.add(
        MpesaNumber(
          id: response['id'].toString(),
          number: number,
          isPrimary: isFirst,
        ),
      );
    } catch (e) {
      print('Erro ao adicionar número de pagamento: $e');
      rethrow;
    }
  }

  // ⭐ Definir principal e atualizar no Supabase
  static Future<void> setPrimary(String id) async {
    try {
      if (!AuthService.isLoggedIn) return;

      final userId = AuthService.currentUser.id;

      // Desmarcar todos como principal no Supabase
      await _supabase
          .from('payment_numbers')
          .update({'is_primary': false})
          .eq('user_id', userId);

      // Marcar o selecionado como principal
      await _supabase
          .from('payment_numbers')
          .update({'is_primary': true})
          .eq('id', int.parse(id));

      // Atualizar localmente
      for (var n in _numbers) {
        n.isPrimary = n.id == id;
      }
    } catch (e) {
      print('Erro ao definir número principal: $e');
    }
  }

  // 🗑️ Remover número do Supabase e localmente
  static Future<void> remove(String id) async {
    try {
      if (!AuthService.isLoggedIn) return;

      // Remover do Supabase
      await _supabase
          .from('payment_numbers')
          .delete()
          .eq('id', int.parse(id));

      // Remover localmente
      _numbers.removeWhere((n) => n.id == id);

      // garante que sempre exista um principal
      if (_numbers.isNotEmpty && !_numbers.any((n) => n.isPrimary)) {
        await setPrimary(_numbers.first.id);
      }
    } catch (e) {
      print('Erro ao remover número de pagamento: $e');
    }
  }

  // 🔑 Número principal (usado no checkout)
  static MpesaNumber? get primary {
    try {
      return _numbers.firstWhere((n) => n.isPrimary);
    } catch (_) {
      return null;
    }
  }
}
