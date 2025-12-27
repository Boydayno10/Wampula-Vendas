import 'package:flutter/material.dart';

class ProductOptionSheet extends StatefulWidget {
  final String title;
  final String image;
  final double price;

  final String? initialSize;
  final String? initialColor;
  final String? initialAge;
  final int? initialQuantity;
  
  // Opções configuradas pelo vendedor
  final List<String>? availableSizes;
  final List<String>? availableColors;
  final List<String>? availableAgeGroups;
  final List<String>? availableStorageOptions;
  final List<String>? availablePantSizes;
  final List<String>? availableShoeSizes;
  final bool hasSizeOption;
  final bool hasColorOption;
  final bool hasAgeOption;
  final bool hasStorageOption;
  final bool hasPantSizeOption;
  final bool hasShoeSizeOption;
  final int stock; // Estoque disponível

  const ProductOptionSheet({
    super.key,
    required this.title,
    required this.image,
    required this.price,
    this.initialSize,
    this.initialColor,
    this.initialAge,
    this.initialQuantity,
    this.availableSizes,
    this.availableColors,
    this.availableAgeGroups,
    this.availableStorageOptions,
    this.availablePantSizes,
    this.availableShoeSizes,
    this.hasSizeOption = false,
    this.hasColorOption = false,
    this.hasAgeOption = false,
    this.hasStorageOption = false,
    this.hasPantSizeOption = false,
    this.hasShoeSizeOption = false,
    this.stock = 999,
  });

  @override
  State<ProductOptionSheet> createState() => _ProductOptionSheetState();
}

class _ProductOptionSheetState extends State<ProductOptionSheet> {
  late int quantity;
  late String selectedSize;
  late String selectedColor;
  late String selectedAge;
  late String selectedStorage;
  late String selectedPantSize;
  late String selectedShoeSize;

  @override
  void initState() {
    super.initState();
    quantity = widget.initialQuantity ?? 1;
    
    // Não pré-selecionar nenhuma opção, deixar vazio para o usuário escolher
    selectedSize = widget.initialSize ?? "";
    selectedColor = widget.initialColor ?? "";
    selectedAge = widget.initialAge ?? "";
    selectedStorage = "";
    selectedPantSize = "";
    selectedShoeSize = "";
  }

  Widget _selectBox(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.deepPurple : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 12),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        t,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de arraste no topo (estilo iPhone)
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Título do produto
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 12),

          // Imagem e preço
          Row(
            children: [
              // CORRIGIDO: Suporta URLs HTTP e assets locais
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: widget.image.startsWith('http')
                  ? Image.network(
                      widget.image,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 70,
                          height: 70,
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 70,
                          height: 70,
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, color: Colors.grey, size: 30),
                        );
                      },
                    )
                  : Image.asset(
                      widget.image,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 70,
                          height: 70,
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, color: Colors.grey, size: 30),
                        );
                      },
                    ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${widget.price.toStringAsFixed(0)} MT",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: 16,
                          color: widget.stock > 0 ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.stock} em estoque',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.stock > 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Conteúdo rolável com as opções
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mostrar apenas opções configuradas pelo vendedor
                  if (widget.hasSizeOption && widget.availableSizes != null && widget.availableSizes!.isNotEmpty) ...[
                    _sectionTitle("Tamanho"),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.availableSizes!.map((size) {
                        return _selectBox(
                          size,
                          selectedSize == size,
                          () => setState(() => selectedSize = size),
                        );
                      }).toList(),
                    ),
                  ],

                  if (widget.hasColorOption && widget.availableColors != null && widget.availableColors!.isNotEmpty) ...[
                    _sectionTitle("Cor"),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.availableColors!.map((color) {
                        return _selectBox(
                          color,
                          selectedColor == color,
                          () => setState(() => selectedColor = color),
                        );
                      }).toList(),
                    ),
                  ],

                  if (widget.hasAgeOption && widget.availableAgeGroups != null && widget.availableAgeGroups!.isNotEmpty) ...[
                    _sectionTitle("Idade"),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.availableAgeGroups!.map((age) {
                        return _selectBox(
                          age,
                          selectedAge == age,
                          () => setState(() => selectedAge = age),
                        );
                      }).toList(),
                    ),
                  ],

                  if (widget.hasStorageOption && widget.availableStorageOptions != null && widget.availableStorageOptions!.isNotEmpty) ...[
                    _sectionTitle("Armazenamento"),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.availableStorageOptions!.map((storage) {
                        return _selectBox(
                          storage,
                          selectedStorage == storage,
                          () => setState(() => selectedStorage = storage),
                        );
                      }).toList(),
                    ),
                  ],

                  if (widget.hasPantSizeOption && widget.availablePantSizes != null && widget.availablePantSizes!.isNotEmpty) ...[
                    _sectionTitle("Tamanho de Calça"),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.availablePantSizes!.map((pantSize) {
                        return _selectBox(
                          pantSize,
                          selectedPantSize == pantSize,
                          () => setState(() => selectedPantSize = pantSize),
                        );
                      }).toList(),
                    ),
                  ],

                  if (widget.hasShoeSizeOption && widget.availableShoeSizes != null && widget.availableShoeSizes!.isNotEmpty) ...[
                    _sectionTitle("Tamanho de Calçado"),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.availableShoeSizes!.map((shoeSize) {
                        return _selectBox(
                          shoeSize,
                          selectedShoeSize == shoeSize,
                          () => setState(() => selectedShoeSize = shoeSize),
                        );
                      }).toList(),
                    ),
                  ],

                  _sectionTitle("Quantidade"),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.deepPurple),
                        onPressed: () =>
                            setState(() => quantity > 1 ? quantity-- : null),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.deepPurple),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "$quantity",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.deepPurple),
                        onPressed: quantity < widget.stock
                            ? () => setState(() => quantity++)
                            : null,
                      ),
                      const Spacer(),
                      Text(
                        'Máx: ${widget.stock}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Botão fixo na parte inferior
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  "size": selectedSize,
                  "color": selectedColor,
                  "age": selectedAge,
                  "storage": selectedStorage,
                  "pantSize": selectedPantSize,
                  "shoeSize": selectedShoeSize,
                  "quantity": quantity,
                });
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Confirmar'),
            ),
          ),
        ],
      ),
    );
  }
}
