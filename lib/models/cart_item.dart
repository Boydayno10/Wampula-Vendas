class CartItem {
  final String id;
  final String name;
  final double price;
  final String image;

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
