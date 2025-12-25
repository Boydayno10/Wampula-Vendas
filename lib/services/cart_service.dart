import '../models/product_model.dart';
import '../models/cart_item.dart';

class CartService {
  static final List<CartItem> _items = [];

  static List<CartItem> get items => _items;

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
    // 🆕 Sempre cria um novo item, mesmo que seja o mesmo produto/opções
    _items.add(
      CartItem(
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
      ),
    );
  }

  /// ➕ Aumentar quantidade
  static void increase(CartItem item) {
    item.quantity++;
  }

  /// ➖ Diminuir quantidade
  static void decrease(CartItem item) {
    if (item.quantity > 1) {
      item.quantity--;
    }
  }

  /// ☑️ Selecionar / desmarcar
  static void toggleSelection(CartItem item) {
    item.selected = !item.selected;
  }

  /// 🗑️ Remover itens selecionados
  static void removeSelected() {
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
}
