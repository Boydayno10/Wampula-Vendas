import 'package:flutter/material.dart';

class TransportSheet extends StatelessWidget {
  final double transportPrice;

  const TransportSheet({super.key, this.transportPrice = 50.0});

  Widget _title(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      );

  Widget _value(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      );

  Widget _description(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black87,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title("Frete:"),
            const SizedBox(height: 4),
            _value("${transportPrice.toStringAsFixed(2)} MT"),
            const SizedBox(height: 16),

            _title("Local de entrega:"),
            const SizedBox(height: 4),
            _description("Mercado do bairro"),
            const SizedBox(height: 16),

            _title("Atenção:"),
            const SizedBox(height: 8),
            _description(
              "O entregador só tem no máximo 10 minutos de espera pelo cliente.\n"
              "Se o entregador for até o local, o posicionamento exato ficará a critério dele.\n"
              "Chegue antes do entregador acompanhando o status do pedido.",
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
