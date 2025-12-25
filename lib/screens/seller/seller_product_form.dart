import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../services/seller_product_service.dart';
import '../../services/image_upload_service.dart';
import '../../models/seller_product_model.dart';
import '../../data/product_options.dart';
import '../../widgets/image_picker_widget.dart';

class SellerProductForm extends StatefulWidget {
  final SellerProductModel? product;
  const SellerProductForm({super.key, this.product});

  @override
  State<SellerProductForm> createState() => _SellerProductFormState();
}

class _SellerProductFormState extends State<SellerProductForm> {
  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final oldPriceCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final stockCtrl = TextEditingController();
  final transportCtrl = TextEditingController();
  
  String _selectedCategory = 'Eletrónicos';
  String img = 'assets/images/product_placeholder.png';
  List<String> _productImages = [];
  bool _isActive = true;
  bool _isLoading = false;
  bool _hasOldPrice = false; // Se tem preço antigo
  
  // Opções do produto
  bool _hasSizeOption = false;
  bool _hasColorOption = false;
  bool _hasAgeOption = false;
  bool _hasStorageOption = false;
  bool _hasPantSizeOption = false;
  bool _hasShoeSizeOption = false;
  bool _hasLocationEnabled = false;
  
  List<String> _sizes = [];
  List<String> _colors = [];
  List<String> _ageGroups = [];
  List<String> _storageOptions = [];
  List<String> _pantSizes = [];
  List<String> _shoeSizes = [];
  
  String _storeAddress = '';
  double? _storeLatitude;
  double? _storeLongitude;
  
  // Opções disponíveis (substituídas pelas do ProductOptions)
  final List<String> _availableSizes = ProductOptions.clothingSizes;
  final List<String> _availableColors = ProductOptions.colors;
  final List<String> _availableAgeGroups = ProductOptions.ageGroups;
  final List<String> _availableStorage = ProductOptions.storageOptions;
  final List<String> _availablePantSizes = ProductOptions.pantSizes;
  final List<String> _availableShoeSizes = ProductOptions.shoeSizes;

  final List<String> _categories = [
    'Eletrónicos',
    'Família',
    'Alimentos',
    'Beleza',
    'Vestuário',
    'Casa e Jardim',
    'Desporto',
    'Outros',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      nameCtrl.text = widget.product!.name;
      priceCtrl.text = widget.product!.price.toString();
      if (widget.product!.oldPrice != null) {
        oldPriceCtrl.text = widget.product!.oldPrice!.toString();
        _hasOldPrice = true;
      }
      descCtrl.text = widget.product!.description;
      stockCtrl.text = widget.product!.stock.toString();
      transportCtrl.text = widget.product!.transportPrice.toString();
      _selectedCategory = widget.product!.category;
      _productImages = List<String>.from(widget.product!.images);
      _isActive = widget.product!.active;
      _hasSizeOption = widget.product!.hasSizeOption;
      _hasColorOption = widget.product!.hasColorOption;
      _hasAgeOption = widget.product!.hasAgeOption;
      _hasStorageOption = widget.product!.hasStorageOption;
      _hasPantSizeOption = widget.product!.hasPantSizeOption;
      _hasShoeSizeOption = widget.product!.hasShoeSizeOption;
      _hasLocationEnabled = widget.product!.hasLocationEnabled;
      _sizes = widget.product!.sizes ?? [];
      _colors = widget.product!.colors ?? [];
      _ageGroups = widget.product!.ageGroups ?? [];
      _storageOptions = widget.product!.storageOptions ?? [];
      _pantSizes = widget.product!.pantSizes ?? [];
      _shoeSizes = widget.product!.shoeSizes ?? [];
      _storeAddress = widget.product!.storeAddress ?? '';
      _storeLatitude = widget.product!.storeLatitude;
      _storeLongitude = widget.product!.storeLongitude;
    } else {
      stockCtrl.text = '0';
      transportCtrl.text = '50';
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    descCtrl.dispose();
    stockCtrl.dispose();
    transportCtrl.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final name = nameCtrl.text.trim();
    final price = double.parse(priceCtrl.text);    final oldPrice = _hasOldPrice && oldPriceCtrl.text.isNotEmpty 
        ? double.parse(oldPriceCtrl.text) 
        : null;    final desc = descCtrl.text.trim();
    final stock = int.parse(stockCtrl.text);
    final transport = double.parse(transportCtrl.text);

    try {
      // Upload das imagens do produto para o Supabase Storage
      List<String> uploadedImageUrls = [];
      for (String imagePath in _productImages) {
        // Limitar a 5 imagens
        if (uploadedImageUrls.length >= 5) break;
        
        if (imagePath.isNotEmpty) {
          if (imagePath.startsWith('http')) {
            // Já é uma URL do Supabase, manter
            uploadedImageUrls.add(imagePath);
          } else if (!imagePath.startsWith('assets/')) {
            // É um caminho local, fazer upload
            String uploadedUrl = await ImageUploadService.uploadProductImage(imagePath);
            uploadedImageUrls.add(uploadedUrl);
          } else {
            // É um asset local
            uploadedImageUrls.add(imagePath);
          }
        }
      }
      
      // Se não houver imagens, adicionar uma padrão
      if (uploadedImageUrls.isEmpty) {
        uploadedImageUrls.add('assets/images/default.png');
      }
      
      print('📸 Total de imagens preparadas para salvar: ${uploadedImageUrls.length}');
      print('🖼️ URLs das imagens: $uploadedImageUrls');

      if (widget.product == null) {
        // Criar novo produto
        await SellerProductService.add(
          SellerProductModel(
            id: AuthService.generateUuid(), // UUID válido
            sellerId: AuthService.currentUser.id,
            sellerStoreName: AuthService.currentUser.storeName,
            name: name,
            price: price,
            oldPrice: oldPrice,
            images: uploadedImageUrls, // Usar URLs do Supabase (até 5 imagens)
            description: desc,
            category: _selectedCategory,
            stock: stock,
            active: _isActive,
            soldCount: 0,
            popularity: 50.0,
            sizes: _hasSizeOption && _sizes.isNotEmpty ? _sizes : null,
            colors: _hasColorOption && _colors.isNotEmpty ? _colors : null,
            ageGroups: _hasAgeOption && _ageGroups.isNotEmpty ? _ageGroups : null,
            storageOptions: _hasStorageOption && _storageOptions.isNotEmpty ? _storageOptions : null,
            pantSizes: _hasPantSizeOption && _pantSizes.isNotEmpty ? _pantSizes : null,
            shoeSizes: _hasShoeSizeOption && _shoeSizes.isNotEmpty ? _shoeSizes : null,
            transportPrice: transport,
            hasSizeOption: _hasSizeOption,
            hasColorOption: _hasColorOption,
            hasAgeOption: _hasAgeOption,
            hasStorageOption: _hasStorageOption,
            hasPantSizeOption: _hasPantSizeOption,
            hasShoeSizeOption: _hasShoeSizeOption,
            hasLocationEnabled: _hasLocationEnabled,
            storeLatitude: _storeLatitude,
            storeLongitude: _storeLongitude,
            storeAddress: _storeAddress.isNotEmpty ? _storeAddress : null,
          ),
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produto cadastrado com sucesso!')),
          );
        }
      } else {
        // Atualizar produto existente
        final updated = widget.product!.copyWith(
          name: name,
          price: price,
          oldPrice: oldPrice,
          description: desc,
          category: _selectedCategory,
          images: uploadedImageUrls, // Usar URLs do Supabase
          stock: stock,
          active: _isActive,
          sizes: _hasSizeOption && _sizes.isNotEmpty ? _sizes : null,
          colors: _hasColorOption && _colors.isNotEmpty ? _colors : null,
          ageGroups: _hasAgeOption && _ageGroups.isNotEmpty ? _ageGroups : null,
          storageOptions: _hasStorageOption && _storageOptions.isNotEmpty ? _storageOptions : null,
          pantSizes: _hasPantSizeOption && _pantSizes.isNotEmpty ? _pantSizes : null,
          shoeSizes: _hasShoeSizeOption && _shoeSizes.isNotEmpty ? _shoeSizes : null,
          transportPrice: transport,
          hasSizeOption: _hasSizeOption,
          hasColorOption: _hasColorOption,
          hasAgeOption: _hasAgeOption,
          hasStorageOption: _hasStorageOption,
          hasPantSizeOption: _hasPantSizeOption,
          hasShoeSizeOption: _hasShoeSizeOption,
          hasLocationEnabled: _hasLocationEnabled,
          storeLatitude: _storeLatitude,
          storeLongitude: _storeLongitude,
          storeAddress: _storeAddress.isNotEmpty ? _storeAddress : null,
        );
        
        await SellerProductService.update(updated);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produto atualizado com sucesso!')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar produto: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final edit = widget.product != null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          edit ? 'Editar Produto' : 'Adicionar Produto',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Imagens do produto (até 5)
            Card(
              elevation: 2,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ImagePickerWidget(
                  selectedImages: _productImages,
                  maxImages: 5,
                  isCircular: false,
                  onImagesChanged: (images) {
                    setState(() {
                      _productImages = images;
                      if (images.isNotEmpty) {
                        img = images.first; // Primeira imagem como principal
                      }
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Nome do produto
            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome do Produto *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.shopping_bag),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe o nome do produto';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Categoria
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Categoria *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: _categories.map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedCategory = value!);
              },
            ),

            const SizedBox(height: 16),

            // Preço
            TextFormField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Preço (MT) *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                suffixText: 'MT',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe o preço';
                }
                final price = double.tryParse(value);
                if (price == null || price <= 0) {
                  return 'Preço inválido';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Opção de Preço Antigo (Promoção)
            SwitchListTile(
              title: const Text('Produto em promoção'),
              subtitle: const Text('Mostrar preço antigo riscado'),
              value: _hasOldPrice,
              onChanged: (value) {
                setState(() {
                  _hasOldPrice = value;
                  if (!value) {
                    oldPriceCtrl.clear();
                  }
                });
              },
              contentPadding: EdgeInsets.zero,
            ),

            if (_hasOldPrice) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: oldPriceCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Preço Antigo (MT)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.money_off),
                  suffixText: 'MT',
                  helperText: 'Preço antes da promoção',
                ),
                validator: (value) {
                  if (_hasOldPrice && (value == null || value.trim().isEmpty)) {
                    return 'Informe o preço antigo';
                  }
                  if (value != null && value.isNotEmpty) {
                    final oldPrice = double.tryParse(value);
                    final currentPrice = double.tryParse(priceCtrl.text);
                    if (oldPrice == null || oldPrice <= 0) {
                      return 'Preço inválido';
                    }
                    if (currentPrice != null && oldPrice <= currentPrice) {
                      return 'Preço antigo deve ser maior que o atual';
                    }
                  }
                  return null;
                },
              ),
            ],

            const SizedBox(height: 16),

            // Estoque
            TextFormField(
              controller: stockCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Quantidade em Estoque *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2),
                helperText: 'Quantidade disponível para venda',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe a quantidade';
                }
                final stock = int.tryParse(value);
                if (stock == null || stock < 0) {
                  return 'Quantidade inválida';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Descrição
            TextFormField(
              controller: descCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                helperText: 'Descreva as características do produto',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe a descrição do produto';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Preço de Transporte
            TextFormField(
              controller: transportCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Preço do Transporte (MT) *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_shipping),
                suffixText: 'MT',
                helperText: 'Valor que será cobrado pelo frete',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe o preço do transporte';
                }
                final transport = double.tryParse(value);
                if (transport == null || transport < 0) {
                  return 'Preço inválido';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),
            const Divider(),
            const Text(
              'Opções do Produto',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure as opções que os clientes poderão escolher',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),

            // Opção de Tamanho
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Possui Tamanhos'),
                    subtitle: const Text('Ex: PP, P, M, G, GG'),
                    value: _hasSizeOption,
                    onChanged: (value) {
                      setState(() => _hasSizeOption = value);
                    },
                  ),
                  if (_hasSizeOption) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selecione os tamanhos disponíveis:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableSizes.map((size) {
                              final isSelected = _sizes.contains(size);
                              return FilterChip(
                                label: Text(size),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _sizes.add(size);
                                    } else {
                                      _sizes.remove(size);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Opção de Cor
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Possui Cores'),
                    subtitle: const Text('Ex: Preto, Branco, Vermelho'),
                    value: _hasColorOption,
                    onChanged: (value) {
                      setState(() => _hasColorOption = value);
                    },
                  ),
                  if (_hasColorOption) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selecione as cores disponíveis:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableColors.map((color) {
                              final isSelected = _colors.contains(color);
                              return FilterChip(
                                label: Text(color),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _colors.add(color);
                                    } else {
                                      _colors.remove(color);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Opção de Idade
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Possui Faixas Etárias'),
                    subtitle: const Text('Ex: Infantil, Adulto, Idoso'),
                    value: _hasAgeOption,
                    onChanged: (value) {
                      setState(() => _hasAgeOption = value);
                    },
                  ),
                  if (_hasAgeOption) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selecione as faixas etárias disponíveis:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableAgeGroups.map((age) {
                              final isSelected = _ageGroups.contains(age);
                              return FilterChip(
                                label: Text(age),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _ageGroups.add(age);
                                    } else {
                                      _ageGroups.remove(age);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Opção de Armazenamento (Eletrônicos)
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Possui Armazenamento'),
                    subtitle: const Text('Ex: 64GB, 128GB, 256GB'),
                    value: _hasStorageOption,
                    onChanged: (value) {
                      setState(() => _hasStorageOption = value);
                    },
                  ),
                  if (_hasStorageOption) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selecione as opções de armazenamento:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableStorage.map((storage) {
                              final isSelected = _storageOptions.contains(storage);
                              return FilterChip(
                                label: Text(storage),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _storageOptions.add(storage);
                                    } else {
                                      _storageOptions.remove(storage);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Opção de Tamanho de Calça
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Possui Tamanhos de Calça'),
                    subtitle: const Text('Ex: 28, 30, 32, 34'),
                    value: _hasPantSizeOption,
                    onChanged: (value) {
                      setState(() => _hasPantSizeOption = value);
                    },
                  ),
                  if (_hasPantSizeOption) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selecione os tamanhos de calça:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availablePantSizes.map((size) {
                              final isSelected = _pantSizes.contains(size);
                              return FilterChip(
                                label: Text(size),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _pantSizes.add(size);
                                    } else {
                                      _pantSizes.remove(size);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Opção de Tamanho de Calçado
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Possui Tamanhos de Calçado'),
                    subtitle: const Text('Ex: 36, 37, 38, 39'),
                    value: _hasShoeSizeOption,
                    onChanged: (value) {
                      setState(() => _hasShoeSizeOption = value);
                    },
                  ),
                  if (_hasShoeSizeOption) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selecione os tamanhos de calçado:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableShoeSizes.map((size) {
                              final isSelected = _shoeSizes.contains(size);
                              return FilterChip(
                                label: Text(size),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _shoeSizes.add(size);
                                    } else {
                                      _shoeSizes.remove(size);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Opção de Localização
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Habilitar Localização'),
                    subtitle: const Text('Mostrar localização da loja aos clientes'),
                    value: _hasLocationEnabled,
                    onChanged: (value) {
                      setState(() => _hasLocationEnabled = value);
                    },
                  ),
                  if (_hasLocationEnabled) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Configuração de Localização:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Endereço da Loja',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.location_on),
                            ),
                            maxLines: 2,
                            onChanged: (value) {
                              _storeAddress = value;
                            },
                            controller: TextEditingController(text: _storeAddress),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Obter localização atual
                              setState(() {
                                _storeLatitude = -25.969248; // Maputo exemplo
                                _storeLongitude = 32.573292;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Localização obtida com sucesso!'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.my_location),
                            label: const Text('Obter Localização Atual'),
                          ),
                          if (_storeLatitude != null && _storeLongitude != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Lat: ${_storeLatitude!.toStringAsFixed(6)}, Lng: ${_storeLongitude!.toStringAsFixed(6)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Switch de ativo/inativo
            Card(
              child: SwitchListTile(
                title: const Text('Produto Ativo'),
                subtitle: Text(
                  _isActive
                      ? 'Produto visível para clientes'
                      : 'Produto oculto dos clientes',
                ),
                value: _isActive,
                activeColor: Colors.green,
                onChanged: (value) {
                  setState(() => _isActive = value);
                },
              ),
            ),

            const SizedBox(height: 24),

            // Botão de salvar
            ElevatedButton(
              onPressed: _isLoading ? null : save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      edit ? 'Salvar Alterações' : 'Cadastrar Produto',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),

            if (edit) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Cancelar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
