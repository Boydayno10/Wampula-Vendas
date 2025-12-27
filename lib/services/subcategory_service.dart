import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subcategory_model.dart';

/// Serviço para gerenciar subcategorias do sistema
/// Subcategorias são gerenciadas apenas por administradores no Supabase
/// Vendedores e clientes apenas visualizam
class SubcategoryService {
  static final _supabase = Supabase.instance.client;
  static final List<SubcategoryModel> _subcategories = [];
  static bool _isLoaded = false;

  /// Retorna todas as subcategorias ativas ordenadas por display_order
  static List<SubcategoryModel> get subcategories => _subcategories;
  
  /// Verifica se as subcategorias já foram carregadas
  static bool get isLoaded => _isLoaded;

  /// Carrega subcategorias do Supabase
  static Future<List<SubcategoryModel>> loadSubcategories() async {
    try {
      print('🔄 Carregando subcategorias do Supabase...');
      
      final response = await _supabase
          .from('subcategories')
          .select()
          .eq('active', true)
          .order('display_order', ascending: true);

      _subcategories.clear();
      
      if (response != null) {
        for (var item in response) {
          try {
            final subcategory = SubcategoryModel.fromJson(item);
            _subcategories.add(subcategory);
          } catch (e) {
            print('❌ Erro ao parsear subcategoria: $e');
          }
        }
      }

      _isLoaded = true;
      print('✅ ${_subcategories.length} subcategorias carregadas com sucesso!');
      
      return _subcategories;
    } catch (e) {
      print('❌ Erro ao carregar subcategorias: $e');
      _isLoaded = true; // Marca como carregado mesmo com erro
      return _subcategories;
    }
  }

  /// Força recarregamento das subcategorias
  static Future<List<SubcategoryModel>> reloadSubcategories() async {
    _isLoaded = false;
    return await loadSubcategories();
  }

  /// Obtém subcategoria por ID
  static SubcategoryModel? getById(String id) {
    try {
      return _subcategories.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Obtém subcategoria por nome
  static SubcategoryModel? getByName(String name) {
    try {
      return _subcategories.firstWhere(
        (s) => s.name.toLowerCase() == name.toLowerCase()
      );
    } catch (e) {
      return null;
    }
  }

  /// Verifica se uma subcategoria existe
  static bool exists(String name) {
    return _subcategories.any(
      (s) => s.name.toLowerCase() == name.toLowerCase()
    );
  }

  /// Limpa o cache de subcategorias
  static void clearCache() {
    _subcategories.clear();
    _isLoaded = false;
  }

  /// Obtém informações de debug
  static Map<String, dynamic> getDebugInfo() {
    return {
      'total_subcategories': _subcategories.length,
      'is_loaded': _isLoaded,
      'subcategories': _subcategories.map((s) => {
        'id': s.id,
        'name': s.name,
        'filter_type': s.filterType.toString(),
        'active': s.active,
        'display_order': s.displayOrder,
      }).toList(),
    };
  }
}
