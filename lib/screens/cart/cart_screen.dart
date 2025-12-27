import 'package:flutter/material.dart';
import '../../services/cart_service.dart';
import '../checkout/checkout_screen.dart';

class CartScreen extends StatefulWidget {
  final VoidCallback onBackToHome;

  const CartScreen({super.key, required this.onBackToHome});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Future<void> _refreshCart() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = CartService.items;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      // 🔝 TOP BAR
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Carrinho',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: widget.onBackToHome,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.deepPurple),
            onPressed: () {
              setState(() {
                CartService.removeSelected();
              });
            },
          ),
        ],
      ),

      body: items.isEmpty
          ? RefreshIndicator(
              onRefresh: _refreshCart,
              child: const Center(
                child: Text(
                  'Seu carrinho está vazio',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          : Column(
              children: [
                // 📦 LISTA
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshCart,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // ☑️ CHECKBOX MODERNO
                                Checkbox(
                                  value: item.selected,
                                  shape: const CircleBorder(),
                                  visualDensity: VisualDensity.compact,
                                  activeColor: Colors.deepPurple,
                                  checkColor: Colors.transparent,
                                  fillColor: WidgetStateProperty.resolveWith((
                                    states,
                                  ) {
                                    if (states.contains(WidgetState.selected)) {
                                      return Colors.deepPurple;
                                    }
                                    return Colors.transparent;
                                  }),
                                  side: const BorderSide(
                                    color: Colors.grey,
                                    width: 1.5,
                                  ),
                                  onChanged: (_) {
                                    setState(() {
                                      CartService.toggleSelection(item);
                                    });
                                  },
                                ),

                                // CORRIGIDO: Suporta URLs HTTP e assets locais
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: item.image.startsWith('http')
                                    ? Image.network(
                                        item.image,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey[200],
                                            child: const Center(
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.image, color: Colors.grey),
                                          );
                                        },
                                      )
                                    : Image.asset(
                                        item.image,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.image, color: Colors.grey),
                                          );
                                        },
                                      ),
                                ),
                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${item.price.toStringAsFixed(0)} MT',
                                        style: const TextStyle(
                                          color: Colors.deepPurple,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      if (item.size != null && item.size!.isNotEmpty)
                                        Text(
                                          'Tam.: ${item.size}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      if (item.color != null && item.color!.isNotEmpty)
                                        Text(
                                          'Cor: ${item.color}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      if (item.age != null && item.age!.isNotEmpty)
                                        Text(
                                          'Idade: ${item.age}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      if (item.storage != null && item.storage!.isNotEmpty)
                                        Text(
                                          'Armaz.: ${item.storage}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      if (item.pantSize != null && item.pantSize!.isNotEmpty)
                                        Text(
                                          'Calça: ${item.pantSize}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      if (item.shoeSize != null && item.shoeSize!.isNotEmpty)
                                        Text(
                                          'Calçado: ${item.shoeSize}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              CartService.decrease(item);
                                            });
                                          },
                                        ),
                                        Text('${item.quantity}'),
                                        IconButton(
                                          icon: const Icon(Icons.add),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              CartService.increase(item);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 💰 TOTAL
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total selecionado',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '${CartService.total.toStringAsFixed(0)} MT',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: CartService.total == 0
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const CheckoutScreen(),
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),

                          child: const Text('Finalizar compra'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
