import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import '../../services/auth_service.dart';
import '../../services/seller_product_service.dart';
import '../../services/image_upload_service.dart';
import '../../services/category_service.dart';
import '../../services/seller_product_service.dart';
import '../../services/location_service.dart';
import '../../models/seller_product_model.dart';
import '../../data/product_options.dart';
import '../../widgets/image_picker_widget.dart';
import '../../widgets/location_autocomplete_field.dart';
import '../../utils/currency_utils.dart';

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

  String _selectedCategory = ''; // Será definido após carregar categorias
  String?
  _selectedCategorySubcategoryId; // Subcategoria específica da categoria
  List<Map<String, dynamic>> _categorySubcategories = [];
  String img = 'assets/images/product_placeholder.png';
  List<String> _productImages = [];
  String? _bannerImage;
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
  bool _showBannerSection = false;

  // Formatação da descrição
  String _descriptionAlignment =
      'left'; // left, center, right (aplicado por parágrafo)
  bool _descriptionBold = false; // estilo padrão caso não use seleção
  bool _descriptionItalic = false; // estilo padrão caso não use seleção

  List<String> _sizes = [];
  List<String> _colors = [];
  List<String> _ageGroups = [];
  List<String> _storageOptions = [];
  List<String> _pantSizes = [];
  List<String> _shoeSizes = [];

  // Opções personalizadas digitadas pelo vendedor
  List<String> _customSizes = [];
  List<String> _customColors = [];
  List<String> _customAgeGroups = [];
  List<String> _customStorageOptions = [];
  List<String> _customPantSizes = [];
  List<String> _customShoeSizes = [];

  // Inputs para opções personalizadas
  final TextEditingController _customSizeController = TextEditingController();
  final TextEditingController _customColorController = TextEditingController();
  final TextEditingController _customAgeController = TextEditingController();
  final TextEditingController _customStorageGbController =
      TextEditingController();
  final TextEditingController _customStorageTbController =
      TextEditingController();
  final TextEditingController _customPantSizeController =
      TextEditingController();
  final TextEditingController _customShoeSizeController =
      TextEditingController();

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

  @override
  void initState() {
    super.initState();
    _loadCategories();

    if (widget.product != null) {
      nameCtrl.text = widget.product!.name;
      priceCtrl.text =
          CurrencyUtils.formatMtPlain(widget.product!.price);
      if (widget.product!.oldPrice != null) {
        oldPriceCtrl.text =
            CurrencyUtils.formatMtPlain(widget.product!.oldPrice!);
        _hasOldPrice = true;
      }
      descCtrl.text = widget.product!.description;
      stockCtrl.text = widget.product!.stock.toString();
      transportCtrl.text = widget.product!.transportPrice.toString();
      _selectedCategory = widget.product!.category;
      _selectedCategorySubcategoryId = widget.product!.categorySubcategoryId;
      _productImages = List<String>.from(widget.product!.images);
      _bannerImage = widget.product!.bannerImage;
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
      _descriptionAlignment = widget.product!.descriptionAlignment;
      _descriptionBold = widget.product!.descriptionBold;
      _descriptionItalic = widget.product!.descriptionItalic;
      _showBannerSection = _bannerImage != null && _bannerImage!.isNotEmpty;

      // Recuperar opções personalizadas que não fazem parte das listas padrão
      _customSizes = _sizes
          .where((s) => !_availableSizes.contains(s))
          .toSet()
          .toList();
      _customColors = _colors
          .where((c) => !_availableColors.contains(c))
          .toSet()
          .toList();
      _customAgeGroups = _ageGroups
          .where((a) => !_availableAgeGroups.contains(a))
          .toSet()
          .toList();
      _customStorageOptions = _storageOptions
          .where((s) => !_availableStorage.contains(s))
          .toSet()
          .toList();
      _customPantSizes = _pantSizes
          .where((p) => !_availablePantSizes.contains(p))
          .toSet()
          .toList();
      _customShoeSizes = _shoeSizes
          .where((s) => !_availableShoeSizes.contains(s))
          .toSet()
          .toList();
    } else {
      stockCtrl.text = '0';
      transportCtrl.text = '50';
    }
  }

  void _resetOptionsForCategory() {
    _hasSizeOption = false;
    _hasColorOption = false;
    _hasAgeOption = false;
    _hasStorageOption = false;
    _hasPantSizeOption = false;
    _hasShoeSizeOption = false;

    _sizes = [];
    _colors = [];
    _ageGroups = [];
    _storageOptions = [];
    _pantSizes = [];
    _shoeSizes = [];

    _customSizes = [];
    _customColors = [];
    _customAgeGroups = [];
    _customStorageOptions = [];
    _customPantSizes = [];
    _customShoeSizes = [];

    _customSizeController.clear();
    _customColorController.clear();
    _customAgeController.clear();
    _customStorageGbController.clear();
    _customStorageTbController.clear();
    _customPantSizeController.clear();
    _customShoeSizeController.clear();
  }

  String get _categoryKey {
    final c = _selectedCategory.toLowerCase().trim();
    if (c.contains('vestu')) return 'vestuario';
    if (c.contains('eletr')) return 'eletronicos';
    if (c.contains('beleza')) return 'beleza';
    if (c.contains('alimento')) return 'alimentos';
    if (c.contains('casa') && c.contains('jardim')) return 'casaejardim';
    return 'outros';
  }

  bool get _allowSizeOption {
    switch (_categoryKey) {
      case 'vestuario':
        return true; // Roupas em geral
      case 'eletronicos':
      case 'beleza':
      case 'alimentos':
      case 'casaejardim':
        return false;
      default:
        return true;
    }
  }

  bool get _allowPantSizeOption {
    return _categoryKey == 'vestuario';
  }

  bool get _allowShoeSizeOption {
    return _categoryKey == 'vestuario';
  }

  bool get _allowStorageOption {
    return _categoryKey == 'eletronicos';
  }

  bool get _allowAgeOption {
    // Por padrão, não usamos idade para esses domínios
    return false;
  }

  bool get _allowColorOption {
    switch (_categoryKey) {
      case 'vestuario':
      case 'eletronicos':
      case 'beleza':
      case 'casaejardim':
        return true;
      case 'alimentos':
        return false;
      default:
        return true;
    }
  }

  Future<void> _loadCategories() async {
    await CategoryService.loadCategories();
    if (mounted && CategoryService.categories.isNotEmpty) {
      setState(() {
        // Se for novo produto, definir primeira categoria válida (excluindo "Início")
        if (widget.product == null) {
          final validCategories = CategoryService.categories
              .where((cat) => cat.active && cat.name != 'Início')
              .toList();
          if (validCategories.isNotEmpty) {
            _selectedCategory = validCategories.first.name;
          }
        }
      });

      // Após definir categoria inicial, carregar subcategorias da categoria
      if (_selectedCategory.isNotEmpty) {
        await _loadCategorySubcategories(_selectedCategory);
      }
    }
  }

  Future<void> _loadCategorySubcategories(String categoryName) async {
    try {
      final items = await SellerProductService.getCategorySubcategories(
        categoryName,
      );

      if (!mounted) return;

      setState(() {
        _categorySubcategories = items;

        // Se a subcategoria selecionada atual não pertence mais à categoria, limpar
        if (_selectedCategorySubcategoryId != null &&
            !_categorySubcategories.any(
              (s) => s['id'] == _selectedCategorySubcategoryId,
            )) {
          _selectedCategorySubcategoryId = null;
        }
      });
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao carregar subcategorias da categoria "$categoryName": $e');
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    descCtrl.dispose();
    stockCtrl.dispose();
    transportCtrl.dispose();
    _customSizeController.dispose();
    _customColorController.dispose();
    _customAgeController.dispose();
    _customStorageGbController.dispose();
    _customStorageTbController.dispose();
    _customPantSizeController.dispose();
    _customShoeSizeController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final name = nameCtrl.text.trim();
    final price = double.parse(
      priceCtrl.text.replaceAll(' ', '').replaceAll(',', '.'),
    );

    // Se o toggle de promoção estiver DESATIVADO, forçar oldPrice como null
    final oldPrice = !_hasOldPrice
        ? null
        : (oldPriceCtrl.text.isNotEmpty
          ? double.parse(
            oldPriceCtrl.text
              .replaceAll(' ', '')
              .replaceAll(',', '.'),
          )
              : null);

    final desc = descCtrl.text.trim();
    final stock = int.parse(stockCtrl.text);
    final transport = double.parse(
      transportCtrl.text.replaceAll(' ', '').replaceAll(',', '.'),
    );

    try {
      // Upload da imagem de banner (opcional, única)
      String? bannerImageUrl;
      if (_bannerImage != null && _bannerImage!.isNotEmpty) {
        final path = _bannerImage!;
        if (path.startsWith('http') || path.startsWith('assets/')) {
          bannerImageUrl = path;
        } else {
          bannerImageUrl = await ImageUploadService.uploadProductBannerImage(
            path,
          );
        }
      }

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
            String uploadedUrl = await ImageUploadService.uploadProductImage(
              imagePath,
            );
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

      print(
        '📸 Total de imagens preparadas para salvar: ${uploadedImageUrls.length}',
      );
      print('🖼️ URLs das imagens: $uploadedImageUrls');
      print('💰 Promoção ativa (_hasOldPrice): $_hasOldPrice');
      print('💵 Preço antigo (oldPrice): $oldPrice');
      print('💲 Preço atual (price): $price');

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
            bannerImage: bannerImageUrl,
            description: desc,
            category: _selectedCategory,
            categorySubcategoryId: _selectedCategorySubcategoryId,
            stock: stock,
            active: _isActive,
            soldCount: 0,
            popularity: 50.0,
            sizes: _hasSizeOption && _sizes.isNotEmpty ? _sizes : null,
            colors: _hasColorOption && _colors.isNotEmpty ? _colors : null,
            ageGroups: _hasAgeOption && _ageGroups.isNotEmpty
                ? _ageGroups
                : null,
            storageOptions: _hasStorageOption && _storageOptions.isNotEmpty
                ? _storageOptions
                : null,
            pantSizes: _hasPantSizeOption && _pantSizes.isNotEmpty
                ? _pantSizes
                : null,
            shoeSizes: _hasShoeSizeOption && _shoeSizes.isNotEmpty
                ? _shoeSizes
                : null,
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
            descriptionAlignment: _descriptionAlignment,
            descriptionBold: _descriptionBold,
            descriptionItalic: _descriptionItalic,
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
          categorySubcategoryId: _selectedCategorySubcategoryId,
          images: uploadedImageUrls, // Usar URLs do Supabase
          bannerImage: bannerImageUrl,
          stock: stock,
          active: _isActive,
          sizes: _hasSizeOption && _sizes.isNotEmpty ? _sizes : null,
          colors: _hasColorOption && _colors.isNotEmpty ? _colors : null,
          ageGroups: _hasAgeOption && _ageGroups.isNotEmpty ? _ageGroups : null,
          storageOptions: _hasStorageOption && _storageOptions.isNotEmpty
              ? _storageOptions
              : null,
          pantSizes: _hasPantSizeOption && _pantSizes.isNotEmpty
              ? _pantSizes
              : null,
          shoeSizes: _hasShoeSizeOption && _shoeSizes.isNotEmpty
              ? _shoeSizes
              : null,
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
          descriptionAlignment: _descriptionAlignment,
          descriptionBold: _descriptionBold,
          descriptionItalic: _descriptionItalic,
        );

        print('📝 Após copyWith - oldPrice no updated: ${updated.oldPrice}');

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar produto: $e')));
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
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ImagePickerWidget(
                      selectedImages: _productImages,
                      maxImages: 5,
                      isCircular: false,
                      onImagesChanged: (images) {
                        setState(() {
                          _productImages = images;
                          if (images.isNotEmpty) {
                            img =
                                images.first; // Primeira imagem como principal
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A imagem será ajustada para o formato quadrado (1:1) automaticamente.\n'
                      'Resolução recomendada: 1024×1024 px ou superior.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Imagem de banner horizontal (opcional)
            Card(
              elevation: 2,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('Imagem de Banner (opcional)'),
                    subtitle: const Text(
                      'Mostrar este produto no banner "Em destaque" da Home',
                    ),
                    value: _showBannerSection,
                    onChanged: (value) {
                      setState(() {
                        _showBannerSection = value;
                        if (!value) {
                          _bannerImage = null;
                        }
                      });
                    },
                  ),
                  if (_showBannerSection) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ImagePickerWidget(
                            title: 'Imagem de Banner (1 horizontal)',
                            selectedImages:
                                _bannerImage != null && _bannerImage!.isNotEmpty
                                ? [_bannerImage!]
                                : const [],
                            maxImages: 1,
                            isCircular: false,
                            onImagesChanged: (images) {
                              setState(() {
                                _bannerImage = images.isNotEmpty
                                    ? images.first
                                    : null;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Esta imagem será usada somente no banner "Em destaque" da Home.\n'
                            'Ela é processada para formato horizontal 16:9 (ex: 1280×720 px).',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
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

            // Categoria (dinâmica do Supabase)
            CategoryService.categories.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : DropdownButtonFormField<String>(
                    value:
                        CategoryService.categories
                            .where((cat) => cat.active && cat.name != 'Início')
                            .any((cat) => cat.name == _selectedCategory)
                        ? _selectedCategory
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Categoria *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                      helperText: 'Categoria do produto',
                    ),
                    items: CategoryService.categories
                        .where((cat) => cat.active && cat.name != 'Início')
                        .map((cat) {
                          return DropdownMenuItem(
                            value: cat.name,
                            child: Text(cat.name),
                          );
                        })
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCategory = value;
                          _selectedCategorySubcategoryId = null;
                          _resetOptionsForCategory();
                        });
                        _loadCategorySubcategories(value);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Selecione uma categoria';
                      }
                      return null;
                    },
                  ),

            const SizedBox(height: 16),

            // Subcategoria específica da categoria (quando existir)
            if (_categorySubcategories.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedCategorySubcategoryId,
                decoration: const InputDecoration(
                  labelText: 'Subcategoria (opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                  helperText:
                      'Subcategoria específica dentro da categoria selecionada',
                ),
                items: _categorySubcategories.map((sub) {
                  return DropdownMenuItem<String>(
                    value: sub['id'] as String,
                    child: Text(sub['name'] as String),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategorySubcategoryId = value;
                    _resetOptionsForCategory();
                  });
                },
              ),

            const SizedBox(height: 16),

            // Preço
            TextFormField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[0-9., ]'),
                ),
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
                final price = double.tryParse(
                  value.replaceAll(' ', '').replaceAll(',', '.'),
                );
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
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9., ]'),
                  ),
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
                    final oldPrice = double.tryParse(
                      value.replaceAll(' ', '').replaceAll(',', '.'),
                    );
                    final currentPrice = double.tryParse(
                      priceCtrl.text
                          .replaceAll(' ', '')
                          .replaceAll(',', '.'),
                    );
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
              textAlign: _descriptionAlignment == 'center'
                  ? TextAlign.center
                  : _descriptionAlignment == 'right'
                  ? TextAlign.right
                  : TextAlign.left,
              style: TextStyle(
                fontWeight: _descriptionBold
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontStyle: _descriptionItalic
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
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

            const SizedBox(height: 6),

            // Controles de formatação da descrição
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(
                    Icons.format_align_left,
                    color: _descriptionAlignment == 'left'
                        ? Colors.deepPurple
                        : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _descriptionAlignment = 'left';
                    });
                  },
                ),
                IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(
                    Icons.format_align_center,
                    color: _descriptionAlignment == 'center'
                        ? Colors.deepPurple
                        : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _descriptionAlignment = 'center';
                    });
                  },
                ),
                IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(
                    Icons.format_align_right,
                    color: _descriptionAlignment == 'right'
                        ? Colors.deepPurple
                        : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _descriptionAlignment = 'right';
                    });
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(
                    Icons.format_bold,
                    color: _descriptionBold ? Colors.deepPurple : Colors.grey,
                  ),
                  onPressed: () {
                    final text = descCtrl.text;
                    final selection = descCtrl.selection;
                    if (!selection.isValid || selection.isCollapsed) {
                      // Sem seleção: alterna estilo padrão
                      setState(() {
                        _descriptionBold = !_descriptionBold;
                      });
                      return;
                    }

                    final start = selection.start;
                    final end = selection.end;
                    final selected = text.substring(start, end);
                    final before = text.substring(0, start);
                    final after = text.substring(end);

                    // Aplica marcação simples **texto** para negrito
                    final newText = '$before**$selected**$after';
                    descCtrl.value = descCtrl.value.copyWith(
                      text: newText,
                      selection: TextSelection.collapsed(
                        offset: (before + '**$selected**').length,
                      ),
                    );
                  },
                ),
                IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(
                    Icons.format_italic,
                    color: _descriptionItalic ? Colors.deepPurple : Colors.grey,
                  ),
                  onPressed: () {
                    final text = descCtrl.text;
                    final selection = descCtrl.selection;
                    if (!selection.isValid || selection.isCollapsed) {
                      // Sem seleção: alterna estilo padrão
                      setState(() {
                        _descriptionItalic = !_descriptionItalic;
                      });
                      return;
                    }

                    final start = selection.start;
                    final end = selection.end;
                    final selected = text.substring(start, end);
                    final before = text.substring(0, start);
                    final after = text.substring(end);

                    // Aplica marcação simples _texto_ para itálico
                    final newText = '${before}_${selected}_$after';
                    descCtrl.value = descCtrl.value.copyWith(
                      text: newText,
                      selection: TextSelection.collapsed(
                        offset: (before + '_${selected}_').length,
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Preço de Transporte
            TextFormField(
              controller: transportCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[0-9., ]'),
                ),
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
                final transport = double.tryParse(
                  value.replaceAll(' ', '').replaceAll(',', '.'),
                );
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure as opções que os clientes poderão escolher',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),

            // Opção de Tamanho
            if (_allowSizeOption)
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
                              children:
                                  [
                                    ..._availableSizes,
                                    ..._customSizes.where(
                                      (s) => !_availableSizes.contains(s),
                                    ),
                                  ].map((size) {
                                    final isSelected = _sizes.contains(size);
                                    return FilterChip(
                                      label: Text(size),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            if (!_sizes.contains(size)) {
                                              _sizes.add(size);
                                            }
                                          } else {
                                            _sizes.remove(size);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Adicionar tamanho personalizado:',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _customSizeController,
                              decoration: InputDecoration(
                                hintText: 'Ex: 26, 3XL',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.add_circle),
                                  color: Colors.deepPurple,
                                  onPressed: () {
                                    final raw = _customSizeController.text
                                        .trim();
                                    if (raw.isEmpty) return;
                                    final size = raw;
                                    setState(() {
                                      if (!_availableSizes.contains(size) &&
                                          !_customSizes.contains(size)) {
                                        _customSizes.add(size);
                                      }
                                      if (!_sizes.contains(size)) {
                                        _sizes.add(size);
                                      }
                                      _customSizeController.clear();
                                    });
                                  },
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

            const SizedBox(height: 12),

            // Opção de Cor
            if (_allowColorOption)
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
                              children:
                                  [
                                    ..._availableColors,
                                    ..._customColors.where(
                                      (c) => !_availableColors.contains(c),
                                    ),
                                  ].map((color) {
                                    final isSelected = _colors.contains(color);
                                    return FilterChip(
                                      label: Text(color),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            if (!_colors.contains(color)) {
                                              _colors.add(color);
                                            }
                                          } else {
                                            _colors.remove(color);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Adicionar cor personalizada:',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _customColorController,
                              decoration: InputDecoration(
                                hintText: 'Ex: Turquesa, Bordô',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.add_circle),
                                  color: Colors.deepPurple,
                                  onPressed: () {
                                    final raw = _customColorController.text
                                        .trim();
                                    if (raw.isEmpty) return;
                                    final color = raw;
                                    setState(() {
                                      if (!_availableColors.contains(color) &&
                                          !_customColors.contains(color)) {
                                        _customColors.add(color);
                                      }
                                      if (!_colors.contains(color)) {
                                        _colors.add(color);
                                      }
                                      _customColorController.clear();
                                    });
                                  },
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

            const SizedBox(height: 12),

            // Opção de Idade
            if (_allowAgeOption)
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
                              children:
                                  [
                                    ..._availableAgeGroups,
                                    ..._customAgeGroups.where(
                                      (a) => !_availableAgeGroups.contains(a),
                                    ),
                                  ].map((age) {
                                    final isSelected = _ageGroups.contains(age);
                                    return FilterChip(
                                      label: Text(age),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            if (!_ageGroups.contains(age)) {
                                              _ageGroups.add(age);
                                            }
                                          } else {
                                            _ageGroups.remove(age);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Adicionar faixa etária personalizada:',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _customAgeController,
                              decoration: InputDecoration(
                                hintText: 'Ex: 2-3A, 16-18A',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.add_circle),
                                  color: Colors.deepPurple,
                                  onPressed: () {
                                    final raw = _customAgeController.text
                                        .trim();
                                    if (raw.isEmpty) return;
                                    final age = raw;
                                    setState(() {
                                      if (!_availableAgeGroups.contains(age) &&
                                          !_customAgeGroups.contains(age)) {
                                        _customAgeGroups.add(age);
                                      }
                                      if (!_ageGroups.contains(age)) {
                                        _ageGroups.add(age);
                                      }
                                      _customAgeController.clear();
                                    });
                                  },
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

            const SizedBox(height: 12),

            // Opção de Armazenamento (Eletrônicos)
            if (_allowStorageOption)
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
                              children:
                                  [
                                    ..._availableStorage,
                                    ..._customStorageOptions.where(
                                      (s) => !_availableStorage.contains(s),
                                    ),
                                  ].map((storage) {
                                    final isSelected = _storageOptions.contains(
                                      storage,
                                    );
                                    return FilterChip(
                                      label: Text(storage),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            if (!_storageOptions.contains(
                                              storage,
                                            )) {
                                              _storageOptions.add(storage);
                                            }
                                          } else {
                                            _storageOptions.remove(storage);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Adicionar armazenamento personalizado:',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Column(
                              children: [
                                TextField(
                                  controller: _customStorageGbController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Ex: 200',
                                    labelText: 'Valor em GB',
                                    suffixText: 'GB',
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.add_circle),
                                      color: Colors.deepPurple,
                                      onPressed: () {
                                        final raw = _customStorageGbController
                                            .text
                                            .trim();
                                        if (raw.isEmpty) return;
                                        final digits = raw.replaceAll(
                                          RegExp(r'[^0-9]'),
                                          '',
                                        );
                                        if (digits.isEmpty) return;
                                        final option = '${digits}GB';
                                        setState(() {
                                          if (!_availableStorage.contains(
                                                option,
                                              ) &&
                                              !_customStorageOptions.contains(
                                                option,
                                              )) {
                                            _customStorageOptions.add(option);
                                          }
                                          if (!_storageOptions.contains(
                                            option,
                                          )) {
                                            _storageOptions.add(option);
                                          }
                                          _customStorageGbController.clear();
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _customStorageTbController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Ex: 2',
                                    labelText: 'Valor em TB',
                                    suffixText: 'TB',
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.add_circle),
                                      color: Colors.deepPurple,
                                      onPressed: () {
                                        final raw = _customStorageTbController
                                            .text
                                            .trim();
                                        if (raw.isEmpty) return;
                                        final digits = raw.replaceAll(
                                          RegExp(r'[^0-9]'),
                                          '',
                                        );
                                        if (digits.isEmpty) return;
                                        final option = '${digits}TB';
                                        setState(() {
                                          if (!_availableStorage.contains(
                                                option,
                                              ) &&
                                              !_customStorageOptions.contains(
                                                option,
                                              )) {
                                            _customStorageOptions.add(option);
                                          }
                                          if (!_storageOptions.contains(
                                            option,
                                          )) {
                                            _storageOptions.add(option);
                                          }
                                          _customStorageTbController.clear();
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
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
            if (_allowPantSizeOption)
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
                              children:
                                  [
                                    ..._availablePantSizes,
                                    ..._customPantSizes.where(
                                      (s) => !_availablePantSizes.contains(s),
                                    ),
                                  ].map((size) {
                                    final isSelected = _pantSizes.contains(
                                      size,
                                    );
                                    return FilterChip(
                                      label: Text(size),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            if (!_pantSizes.contains(size)) {
                                              _pantSizes.add(size);
                                            }
                                          } else {
                                            _pantSizes.remove(size);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Adicionar tamanho de calça personalizado:',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _customPantSizeController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Ex: 26, 52',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.add_circle),
                                  color: Colors.deepPurple,
                                  onPressed: () {
                                    final raw = _customPantSizeController.text
                                        .trim();
                                    if (raw.isEmpty) return;
                                    final size = raw;
                                    setState(() {
                                      if (!_availablePantSizes.contains(size) &&
                                          !_customPantSizes.contains(size)) {
                                        _customPantSizes.add(size);
                                      }
                                      if (!_pantSizes.contains(size)) {
                                        _pantSizes.add(size);
                                      }
                                      _customPantSizeController.clear();
                                    });
                                  },
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

            const SizedBox(height: 12),

            // Opção de Tamanho de Calçado
            if (_allowShoeSizeOption)
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
                              children:
                                  [
                                    ..._availableShoeSizes,
                                    ..._customShoeSizes.where(
                                      (s) => !_availableShoeSizes.contains(s),
                                    ),
                                  ].map((size) {
                                    final isSelected = _shoeSizes.contains(
                                      size,
                                    );
                                    return FilterChip(
                                      label: Text(size),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            if (!_shoeSizes.contains(size)) {
                                              _shoeSizes.add(size);
                                            }
                                          } else {
                                            _shoeSizes.remove(size);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Adicionar tamanho de calçado personalizado:',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _customShoeSizeController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Ex: 47, 48',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.add_circle),
                                  color: Colors.deepPurple,
                                  onPressed: () {
                                    final raw = _customShoeSizeController.text
                                        .trim();
                                    if (raw.isEmpty) return;
                                    final size = raw;
                                    setState(() {
                                      if (!_availableShoeSizes.contains(size) &&
                                          !_customShoeSizes.contains(size)) {
                                        _customShoeSizes.add(size);
                                      }
                                      if (!_shoeSizes.contains(size)) {
                                        _shoeSizes.add(size);
                                      }
                                      _customShoeSizeController.clear();
                                    });
                                  },
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

            const SizedBox(height: 12),

            // Opção de Localização
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Habilitar Localização'),
                    subtitle: const Text(
                      'Mostrar localização da loja aos clientes',
                    ),
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
                          LocationAutocompleteField(
                            controller: TextEditingController(
                              text: _storeAddress,
                            ),
                            label: 'Endereço da Loja',
                            hint: 'Ex: Nampula, Bairro X, perto do mercado Y',
                            onPlaceSelected: (details) {
                              setState(() {
                                _storeAddress = details.formattedAddress;
                                _storeLatitude = details.lat;
                                _storeLongitude = details.lng;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final position =
                                  await LocationService.getCurrentPosition();
                              if (position == null) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Não foi possível obter a localização. Verifique o GPS e as permissões.',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                              // Tentar obter endereço legível (cidade/bairro, ex: Nampula)
                              final address =
                                  await LocationService.getAddressFromCoordinates(
                                    position.latitude,
                                    position.longitude,
                                  );

                              setState(() {
                                _storeLatitude = position.latitude;
                                _storeLongitude = position.longitude;
                                // Só atualiza o texto se veio um endereço real
                                if (address != null && address.isNotEmpty) {
                                  _storeAddress = address;
                                }
                              });

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Localização obtida com sucesso!',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.my_location),
                            label: const Text('Obter Localização Atual'),
                          ),
                          if (_storeLatitude != null &&
                              _storeLongitude != null) ...[
                            const SizedBox(height: 8),
                            // Mapa real (OpenStreetMap) com marcador, clicável para abrir Google Maps
                            SizedBox(
                              height: 200,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  children: [
                                    FlutterMap(
                                      options: MapOptions(
                                        initialCenter: latlng.LatLng(
                                          _storeLatitude!,
                                          _storeLongitude!,
                                        ),
                                        initialZoom: 16,
                                        interactionOptions:
                                            const InteractionOptions(
                                              flags:
                                                  InteractiveFlag.pinchZoom |
                                                  InteractiveFlag.drag,
                                            ),
                                      ),
                                      children: [
                                        // Mapa claro padrão OpenStreetMap, fácil de reconhecer
                                        TileLayer(
                                          urlTemplate:
                                              'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                          subdomains: const ['a', 'b', 'c'],
                                          userAgentPackageName:
                                              'com.example.wampulavendas',
                                        ),
                                        MarkerLayer(
                                          markers: [
                                            Marker(
                                              point: latlng.LatLng(
                                                _storeLatitude!,
                                                _storeLongitude!,
                                              ),
                                              width: 40,
                                              height: 40,
                                              alignment: Alignment.bottomCenter,
                                              child: const Icon(
                                                Icons.location_on,
                                                size: 40,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Positioned.fill(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () async {
                                            final uri = Uri.parse(
                                              'https://www.google.com/maps/search/?api=1&query=${_storeLatitude!.toStringAsFixed(6)},${_storeLongitude!.toStringAsFixed(6)}',
                                            );
                                            if (await canLaunchUrl(uri)) {
                                              await launchUrl(
                                                uri,
                                                mode: LaunchMode
                                                    .externalApplication,
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
                onPressed: _isLoading ? null : () => Navigator.pop(context),
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
