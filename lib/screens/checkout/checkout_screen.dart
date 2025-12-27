import 'package:flutter/material.dart';
import '../../services/cart_service.dart';
import '../../services/order_service.dart';
import '../../services/payment_service.dart';
import '../order/order_success_screen.dart';
import '../../models/product_model.dart';
import '../payments/payments_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final ProductModel? product;
  final int? quantity;
  final String? size;
  final String? color;
  final String? age;
  final String? storage;
  final String? pantSize;
  final String? shoeSize;

  const CheckoutScreen({
    super.key,
    this.product,
    this.quantity,
    this.size,
    this.color,
    this.age,
    this.storage,
    this.pantSize,
    this.shoeSize,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  Future<void> _refreshCheckout() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDirect = widget.product != null;

    final items = isDirect
        ? <dynamic>[]
        : CartService.items.where((i) => i.selected).toList();

    final total = isDirect
        ? (widget.product!.price * (widget.quantity ?? 1))
        : CartService.total;

    final mpesa = PaymentService.primary;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Finalizar Compra',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.payment, color: Colors.deepPurple),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaymentsScreen()),
              );
            },
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _refreshCheckout,
        child: Column(
          children: [
            Expanded(
              child: isDirect
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          elevation: 2,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // CORRIGIDO: Suporta URLs HTTP e assets locais
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: widget.product!.image.startsWith('http')
                                    ? Image.network(
                                        widget.product!.image,
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
                                        widget.product!.image,
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
                                        widget.product!.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Qtd: ${widget.quantity ?? 1}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (widget.size != null && widget.size!.isNotEmpty)
                                        Text(
                                          'Tam.: ${widget.size}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      if (widget.color != null && widget.color!.isNotEmpty)
                                        Text(
                                          'Cor: ${widget.color}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      if (widget.age != null && widget.age!.isNotEmpty)
                                        Text(
                                          'Idade: ${widget.age}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      if (widget.storage != null && widget.storage!.isNotEmpty)
                                        Text(
                                          'Armaz.: ${widget.storage}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      if (widget.pantSize != null && widget.pantSize!.isNotEmpty)
                                        Text(
                                          'Calça: ${widget.pantSize}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      if (widget.shoeSize != null && widget.shoeSize!.isNotEmpty)
                                        Text(
                                          'Calçado: ${widget.shoeSize}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${(widget.product!.price * (widget.quantity ?? 1)).toStringAsFixed(0)} MT',
                                  style: const TextStyle(
                                    color: Colors.deepPurple,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : (items.isEmpty
                        ? const Center(
                            child: Text(
                              'Nenhum item selecionado',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: items.length,
                            itemBuilder: (_, index) {
                              final item = items[index];
                              return Card(
                                elevation: 2,
                                shadowColor: Colors.black12,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
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
                                          children: [
                                            Text(
                                              item.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Qtd: ${item.quantity}',
                                              style: const TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            if (item.size.isNotEmpty)
                                              Text(
                                                'Tam.: ${item.size}',
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            if (item.color.isNotEmpty)
                                              Text(
                                                'Cor: ${item.color}',
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            if (item.age.isNotEmpty)
                                              Text(
                                                'Idade: ${item.age}',
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${(item.price * item.quantity).toStringAsFixed(0)} MT',
                                        style: const TextStyle(
                                          color: Colors.deepPurple,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )),
            ),

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Forma de pagamento',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.phone_android, color: Colors.green.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            mpesa != null
                                ? 'M-Pesa (${mpesa.number})'
                                : 'Nenhum número M-Pesa',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '${total.toStringAsFixed(0)} MT',
                        style: const TextStyle(
                          fontSize: 22,
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
                      onPressed:
                          (total == 0 ||
                              mpesa == null ||
                              (!isDirect && items.isEmpty))
                          ? null
                          : () async {
                              if (isDirect) {
                                final order = await OrderService()
                                    .createOrderFromDirectPurchase(
                                      product: widget.product!,
                                      quantity: widget.quantity ?? 1,
                                      size: widget.size,
                                      color: widget.color,
                                      age: widget.age,
                                      storage: widget.storage,
                                      pantSize: widget.pantSize,
                                      shoeSize: widget.shoeSize,
                                    );
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        OrderSuccessScreen(order: order),
                                  ),
                                );
                              } else {
                                final order = await OrderService().createOrder();
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        OrderSuccessScreen(order: order),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Pagar agora',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
