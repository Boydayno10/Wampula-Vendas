import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/product_model.dart';
import '../models/cart_item.dart';

class CartService {
  static final _supabase = Supabase.instance.client;

  static final List<CartItem> _items = [];

  static List<CartItem> get items => _items;

  /// Carrega itens do carrinho do usuário logado a partir do Supabase
  static Future<void> loadFromSupabase() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await _supabase
          .from('cart_items')
          .select()
          .eq('user_id', userId)
          .order('created_at');

      _items
        ..clear()
        ..addAll(
          (response as List<dynamic>).map<CartItem>(
            (json) => CartItem(
              cartItemId: json['id'] as String?,
              id: (json['product_id'] ?? '') as String,
              name: (json['name'] ?? '') as String,
              image: (json['image'] ?? '') as String,
              price: (json['price'] ?? 0).toDouble(),
              quantity: (json['quantity'] ?? 1) as int,
              selected: (json['selected'] ?? true) as bool,
              size: json['size'] as String?,
              color: json['color'] as String?,
              age: json['age'] as String?,
              storage: json['storage'] as String?,
              pantSize: json['pant_size'] as String?,
              shoeSize: json['shoe_size'] as String?,
            ),
          ),
        );
    } catch (e) {
      print('Erro ao carregar carrinho do Supabase: $e');
    }
  }

  /// Limpa o carrinho em memória (usado no logout)
  static void clear() {
    _items.clear();
  }

  /// ➕ Adicionar produto com atributos completos
  static void addProduct({
    required ProductModel product,
    required int quantity,
    String? size,
    String? color,
    String? age,
    String? storage,
    String? pantSize,
    String? shoeSize,
  }) {
    final userId = _supabase.auth.currentUser?.id;
    final String? cartItemId = userId != null ? const Uuid().v4() : null;

    final newItem = CartItem(
      cartItemId: cartItemId,
      id: product.id,
      name: product.name,
      price: product.price,
      image: product.image,
      quantity: quantity,
      selected: true,
      size: size,
      color: color,
      age: age,
      storage: storage,
      pantSize: pantSize,
      shoeSize: shoeSize,
    );

    _items.add(newItem);

    if (userId != null && cartItemId != null) {
      _insertRemote(newItem, userId);
    }
  }

  /// ➕ Aumentar quantidade
  static void increase(CartItem item) {
    item.quantity++;
    _updateQuantityRemote(item);
  }

  /// ➖ Diminuir quantidade
  static void decrease(CartItem item) {
    if (item.quantity > 1) {
      item.quantity--;
      _updateQuantityRemote(item);
    }
  }

  /// ☑️ Selecionar / desmarcar
  static void toggleSelection(CartItem item) {
    item.selected = !item.selected;
    _updateSelectionRemote(item);
  }

  /// 🗑️ Remover itens selecionados
  static void removeSelected() {
    final selectedIds = _items
        .where((item) => item.selected && item.cartItemId != null)
        .map((item) => item.cartItemId!)
        .toList();

    if (selectedIds.isNotEmpty) {
      _deleteSelectedRemote(selectedIds);
    }

    _items.removeWhere((item) => item.selected);
  }

  /// 💰 Total dos selecionados
  static double get total {
    return _items
        .where((i) => i.selected)
        .fold(0.0, (sum, i) => sum + (i.price * i.quantity));
  }

  /// ❓ Há itens selecionados?
  static bool get hasSelected => _items.any((i) => i.selected);

  static Future<void> _insertRemote(CartItem item, String userId) async {
    if (item.cartItemId == null) return;

    try {
      await _supabase.from('cart_items').insert({
        'id': item.cartItemId,
        'user_id': userId,
        'product_id': item.id,
        'name': item.name,
        'image': item.image,
        'price': item.price,
        'quantity': item.quantity,
        'size': item.size,
        'color': item.color,
        'age': item.age,
        'storage': item.storage,
        'pant_size': item.pantSize,
        'shoe_size': item.shoeSize,
        'selected': item.selected,
      });
    } catch (e) {
      print('Erro ao inserir item no carrinho (Supabase): $e');
    }
  }

  static Future<void> _updateQuantityRemote(CartItem item) async {
    final userId = _supabase.auth.currentUser?.id;
    final cartItemId = item.cartItemId;
    if (userId == null || cartItemId == null) return;

    try {
      await _supabase
          .from('cart_items')
          .update({'quantity': item.quantity})
          .eq('id', cartItemId)
          .eq('user_id', userId);
    } catch (e) {
      print('Erro ao atualizar quantidade do carrinho (Supabase): $e');
    }
  }

  static Future<void> _updateSelectionRemote(CartItem item) async {
    final userId = _supabase.auth.currentUser?.id;
    final cartItemId = item.cartItemId;
    if (userId == null || cartItemId == null) return;

    try {
      await _supabase
          .from('cart_items')
          .update({'selected': item.selected})
          .eq('id', cartItemId)
          .eq('user_id', userId);
    } catch (e) {
      print('Erro ao atualizar seleção do carrinho (Supabase): $e');
    }
  }

  static Future<void> _deleteSelectedRemote(List<String> ids) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Deleta um por um para evitar dependência de in_(),
      // garantindo compatibilidade com versões antigas do postgrest.
      for (final id in ids) {
        await _supabase
            .from('cart_items')
            .delete()
            .eq('user_id', userId)
            .eq('id', id);
      }
    } catch (e) {
      print('Erro ao remover itens do carrinho (Supabase): $e');
    }
  }
}
