import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category_model.dart';

/// Serviço para gerenciar categorias do sistema
/// Carrega categorias do Supabase dinamicamente
class CategoryService {
  static final _supabase = Supabase.instance.client;
  static final List<CategoryModel> _categories = [];
  static bool _isLoaded = false;

  /// Retorna todas as categorias ativas ordenadas por display_order
  static List<CategoryModel> get categories => _categories;
  
  /// Verifica se as categorias já foram carregadas
  static bool get isLoaded => _isLoaded;

  /// Carrega categorias do Supabase
  static Future<List<CategoryModel>> loadCategories() async {
    try {
      print('📂 Carregando categorias do Supabase...');
      
      final response = await _supabase
          .from('categories')
          .select()
          .eq('active', true)
          .order('display_order', ascending: true)
          .order('name', ascending: true);

      _categories.clear();
      
      if (response != null) {
        for (var item in response) {
          _categories.add(CategoryModel.fromJson(item));
        }
        _isLoaded = true;
        print('✅ ${_categories.length} categorias carregadas');
      }

      return _categories;
    } catch (e) {
      print('❌ Erro ao carregar categorias: $e');
      
      // Fallback para categorias padrão se houver erro
      if (_categories.isEmpty) {
        _addDefaultCategories();
      }
      
      return _categories;
    }
  }

  /// Adiciona categorias padrão como fallback
  static void _addDefaultCategories() {
    print('⚠️ Usando categorias padrão (fallback)');
    _categories.addAll([
      CategoryModel(
        id: 'default-1',
        name: 'Início',
        displayOrder: 0,
        active: true,
        createdAt: DateTime.now(),
      ),
      CategoryModel(
        id: 'default-2',
        name: 'Eletrónicos',
        displayOrder: 1,
        active: true,
        createdAt: DateTime.now(),
      ),
      CategoryModel(
        id: 'default-3',
        name: 'Família',
        displayOrder: 2,
        active: true,
        createdAt: DateTime.now(),
      ),
      CategoryModel(
        id: 'default-4',
        name: 'Alimentos',
        displayOrder: 3,
        active: true,
        createdAt: DateTime.now(),
      ),
      CategoryModel(
        id: 'default-5',
        name: 'Beleza',
        displayOrder: 4,
        active: true,
        createdAt: DateTime.now(),
      ),
    ]);
  }

  /// Retorna uma categoria por nome
  static CategoryModel? getCategoryByName(String name) {
    try {
      return _categories.firstWhere((cat) => cat.name.toLowerCase() == name.toLowerCase());
    } catch (e) {
      return null;
    }
  }

  /// Retorna uma categoria por ID
  static CategoryModel? getCategoryById(String id) {
    try {
      return _categories.firstWhere((cat) => cat.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Força o recarregamento das categorias
  static Future<void> reload() async {
    _isLoaded = false;
    await loadCategories();
  }

  /// Retorna lista de nomes de categorias (para dropdowns)
  static List<String> getCategoryNames() {
    return _categories.map((cat) => cat.name).toList();
  }
}
