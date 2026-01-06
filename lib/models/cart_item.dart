class CartItem {
  // ID do produto (product_id no Supabase)
  final String id;
  final String name;
  final double price;
  final String image;

  // ID da linha no banco (tabela cart_items)
  final String? cartItemId;

  int quantity;
  bool selected;

  // Opções do produto
  final String? size;
  final String? color;
  final String? age;
  final String? storage;
  final String? pantSize;
  final String? shoeSize;

  CartItem({
    this.cartItemId,
    required this.id,
    required this.name,
    required this.price,
    required this.image,
    this.quantity = 1,
    this.selected = true,
    this.size,
    this.color,
    this.age,
    this.storage,
    this.pantSize,
    this.shoeSize,
  });
}
