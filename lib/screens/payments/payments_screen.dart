import 'package:flutter/material.dart';
import '../../services/payment_service.dart';
import '../../utils/responsive_helper.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final TextEditingController _controller = TextEditingController();

  Future<void> _refreshPayments() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final numbers = PaymentService.numbers;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: const BackButton(),
        title: Text(
          'Pagamentos',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 20),
          ),
        ),
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 8)),

          // ▌ Campo moderno para inserir número M-Pesa
          Padding(
            padding: ResponsiveHelper.getResponsivePadding(context),
            child: Container(
              padding: ResponsiveHelper.getResponsivePadding(context),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number, // só números!
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 15),
                    ),
                    decoration: InputDecoration(
                      labelText: "Número M-Pesa",
                      labelStyle: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: ResponsiveHelper.getResponsiveSpacing(context, 14),
                        horizontal: ResponsiveHelper.getResponsiveSpacing(context, 14),
                      ),

                      // prefixo +258 |
                      prefixIcon: SizedBox(
                        width: ResponsiveHelper.getResponsiveSpacing(context, 70),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "+258",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 15),
                              ),
                            ),
                            SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 6)),
                            Text(
                              "|",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // botão X
                      suffixIcon: _controller.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                setState(() {
                                  _controller.clear();
                                });
                              },
                              icon: Icon(
                                Icons.close,
                                color: Colors.grey,
                                size: ResponsiveHelper.getResponsiveIconSize(context, 20),
                              ),
                            )
                          : null,

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),

                    // apenas números permitidos
                    onChanged: (value) {
                      setState(() {
                        _controller.text = value.replaceAll(
                          RegExp(r'[^0-9]'),
                          "",
                        );
                        _controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: _controller.text.length),
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 10),

                  // Botão Adicionar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_controller.text.isEmpty) return;
                        setState(() {
                          PaymentService.addNumber(_controller.text);
                          _controller.clear();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("Adicionar"),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Divisor elegante
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: const [
                Expanded(child: Divider(color: Colors.grey, thickness: 0.5)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    "Seus números",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey, thickness: 0.5)),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // LISTA
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshPayments,
              child: numbers.isEmpty
                  ? const Center(
                      child: Text(
                        "Nenhum número M-Pesa adicionado",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: numbers.length,
                      itemBuilder: (context, index) {
                        final n = numbers[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.phone_iphone),
                            ),
                            title: Text(
                              n.number,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: n.isPrimary
                                ? const Text(
                                    "Principal",
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.star),
                                  color: n.isPrimary
                                      ? Colors.orange
                                      : Colors.grey,
                                  onPressed: () {
                                    setState(() {
                                      PaymentService.setPrimary(n.id);
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () {
                                    setState(() {
                                      PaymentService.remove(n.id);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
