class OrderItem {
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final String image;
  
  // Opções selecionadas
  final String? size;
  final String? color;
  final String? age;
  final String? storage;
  final String? pantSize;
  final String? shoeSize;

  OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.image,
    this.size,
    this.color,
    this.age,
    this.storage,
    this.pantSize,
    this.shoeSize,
  });
}
