import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;

import '../../services/client_publicacao_service.dart';
import '../../models/client_publicacao_model.dart';
import '../../widgets/image_picker_widget.dart';
import '../../services/location_service.dart';
import '../../services/seller_product_service.dart';
import '../../widgets/location_autocomplete_field.dart';
import '../../utils/currency_utils.dart';
import '../../widgets/wv_primary_button.dart';
import '../product/product_detail_screen.dart';

class NovaPublicacaoScreen extends StatefulWidget {
  final ClientPublicacaoModel? publicacao;

  const NovaPublicacaoScreen({super.key, this.publicacao});

  @override
  State<NovaPublicacaoScreen> createState() => _NovaPublicacaoScreenState();
}

class _NovaPublicacaoScreenState extends State<NovaPublicacaoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _promoPriceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationAddressCtrl = TextEditingController();

  List<String> _images = [];
  String? _bannerImage;
  bool _showBannerSection = false;
  bool _hasPromotion = false;
  bool _hasLocationEnabled = false;
  bool _isActive = true;
  bool _isSaving = false;
  String _locationAddress = '';
  double? _locationLatitude;
  double? _locationLongitude;
  String? _selectedCategorySubcategoryId;
  List<Map<String, dynamic>> _categorySubcategories = [];

  // Formatação da descrição (copiado do formulário do vendedor)
  String _descriptionAlignment = 'left'; // left, center, right
  bool _descriptionBold = false;
  bool _descriptionItalic = false;

  // Verifica se a publicação está expirada
  bool get _isExpired {
    if (widget.publicacao == null) return false;
    return widget.publicacao!.effectiveExpiresAt.isBefore(DateTime.now());
  }

  Future<void> _openPublicationDetail() async {
    final existing = widget.publicacao;
    if (existing == null) return;

    try {
      final sellerProduct = await SellerProductService.getById(existing.id);
      if (!mounted) return;

      if (sellerProduct == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir a publicação.'),
          ),
        );
        return;
      }

      final product = sellerProduct.toProductModel();

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: product),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao abrir publicação: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.publicacao;
    if (existing != null) {
      _nameCtrl.text = existing.name;
      _priceCtrl.text = CurrencyUtils.formatMtPlain(existing.price);
      if (existing.promoPrice != null) {
        _hasPromotion = true;
        _promoPriceCtrl.text =
            CurrencyUtils.formatMtPlain(existing.promoPrice!);
      }
      _descCtrl.text = existing.description ?? '';
      _images = List<String>.from(existing.images);
      _hasLocationEnabled = existing.hasLocationEnabled;
      _isActive = existing.active;
      // A localização real (endereço + lat/lng) é carregada do produto espelho
      // após o init, em _loadExistingLocationFromProduct.
    }

    if (existing != null) {
      _loadExistingLocationFromProduct(existing.id);
    }

    // Carregar subcategorias específicas da categoria "Temporarios"
    _loadTemporariosSubcategories();
  }

  Future<void> _loadExistingLocationFromProduct(String publicationId) async {
    try {
      final product = await SellerProductService.getById(publicationId);
      if (!mounted || product == null) return;
      setState(() {
        // Localização herdada do produto espelho
        if (product.hasLocationEnabled &&
            product.storeLatitude != null &&
            product.storeLongitude != null) {
          _hasLocationEnabled = true;
          _locationLatitude = product.storeLatitude;
          _locationLongitude = product.storeLongitude;
          _locationAddress = product.storeAddress ?? '';
          _locationAddressCtrl.text = _locationAddress;
        }

        // Banner herdado (se existir)
        if (product.bannerImage != null && product.bannerImage!.isNotEmpty) {
          _bannerImage = product.bannerImage;
          _showBannerSection = true;
        }

        // Formatação da descrição herdada
        _descriptionAlignment = product.descriptionAlignment;
        _descriptionBold = product.descriptionBold;
        _descriptionItalic = product.descriptionItalic;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao carregar localização da publicação: $e');
    }
  }

  Future<void> _loadTemporariosSubcategories() async {
    try {
      final subs = await SellerProductService.getCategorySubcategories(
        'Temporarios',
      );

      String? selectedId;
      // Se estiver editando, tentar recuperar subcategoria do produto ligado
      if (widget.publicacao != null) {
        final product = await SellerProductService.getById(
          widget.publicacao!.id,
        );
        selectedId = product?.categorySubcategoryId;
      }

      if (!mounted) return;

      setState(() {
        _categorySubcategories = subs;
        if (selectedId != null && subs.any((s) => s['id'] == selectedId)) {
          _selectedCategorySubcategoryId = selectedId;
        }
      });
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao carregar subcategorias de Temporarios: $e');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _promoPriceCtrl.dispose();
    _descCtrl.dispose();
    _locationAddressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameCtrl.text.trim();
      final price = double.parse(
        _priceCtrl.text.replaceAll(' ', '').replaceAll(',', '.'),
      );
      final promoPrice = _hasPromotion && _promoPriceCtrl.text.isNotEmpty
          ? double.parse(
              _promoPriceCtrl.text
                  .replaceAll(' ', '')
                  .replaceAll(',', '.'),
            )
          : null;
      final desc = _descCtrl.text.trim().isEmpty
          ? 'Publicação de cliente'
          : _descCtrl.text.trim();

      if (widget.publicacao == null) {
        await ClientPublicacaoService.createPublication(
          name: name,
          price: price,
          promoPrice: promoPrice,
          description: desc,
          localImagePaths: _images,
          hasLocationEnabled: _hasLocationEnabled,
          locationAddress: _hasLocationEnabled ? _locationAddress : null,
          latitude: _hasLocationEnabled ? _locationLatitude : null,
          longitude: _hasLocationEnabled ? _locationLongitude : null,
          categorySubcategoryId: _selectedCategorySubcategoryId,
          bannerImagePath: _showBannerSection && _bannerImage != null
              ? _bannerImage
              : null,
          descriptionAlignment: _descriptionAlignment,
          descriptionBold: _descriptionBold,
          descriptionItalic: _descriptionItalic,
        );
      } else {
        final updatedModel = widget.publicacao!.copyWith(
          name: name,
          price: price,
          promoPrice: promoPrice,
          hasLocationEnabled: _hasLocationEnabled,
          active: _isExpired ? true : _isActive, // Reativar se expirada
          images: _images,
          category: 'Temporarios',
          description: desc,
        );

        await ClientPublicacaoService.updatePublication(
          updatedModel,
          updatedImagePaths: _images,
          locationAddress: _hasLocationEnabled ? _locationAddress : null,
          latitude: _hasLocationEnabled ? _locationLatitude : null,
          longitude: _hasLocationEnabled ? _locationLongitude : null,
          categorySubcategoryId: _selectedCategorySubcategoryId,
          bannerImagePath: _showBannerSection && _bannerImage != null
              ? _bannerImage
              : null,
          descriptionAlignment: _descriptionAlignment,
          descriptionBold: _descriptionBold,
          descriptionItalic: _descriptionItalic,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.publicacao == null
                ? 'Publicação criada com sucesso!'
                : (_isExpired
                    ? 'Publicação republicada com sucesso! (+24h)'
                    : 'Publicação atualizada com sucesso!'),
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar publicação: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.publicacao != null;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isEditing ? 'Editar Publicação' : 'Nova Publicação',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (isEditing)
            TextButton(
              onPressed: _isExpired ? null : _openPublicationDetail,
              child: Text(
                'Ver',
                style: TextStyle(
                  color: _isExpired
                      ? Colors.grey.shade400
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagens (opcionais, até 5)
                Card(
                  elevation: 2,
                  shadowColor: Colors.black.withOpacity(0.06),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.photo_library_outlined,
                                size: 20, color: Colors.deepPurple),
                            const SizedBox(width: 6),
                            Text(
                              'Fotos da publicação',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ImagePickerWidget(
                          selectedImages: _images,
                          maxImages: 5,
                          onImagesChanged: (imgs) {
                            setState(() => _images = imgs);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A imagem será ajustada para o formato quadrado (1:1) automaticamente. '
                  'Resolução recomendada: 1024×1024 px ou superior.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
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
                          'Destaque esta publicação em banners especiais da Home.',
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
                                    _bannerImage != null &&
                                        _bannerImage!.isNotEmpty
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
                                'Use uma imagem horizontal (16:9), por exemplo 1280×720 px.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Nome da Publicação
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome da Publicação',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o nome da publicação';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Categoria fixa: Temporarios (somente exibição)
                TextFormField(
                  enabled: false,
                  initialValue: 'Temporarios',
                  decoration: const InputDecoration(
                    labelText: 'Categoria fixa *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                    helperText:
                        'A categoria da publicação será sempre Temporarios',
                  ),
                ),
                const SizedBox(height: 16),

                // Subcategoria específica da categoria Temporarios
                if (_categorySubcategories.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _selectedCategorySubcategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Subcategoria (opcional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.label_outline),
                      helperText:
                          'Subcategoria específica dentro da categoria Temporarios',
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
                      });
                    },
                  ),
                if (_categorySubcategories.isNotEmpty)
                  const SizedBox(height: 16),

                // Preço
                TextFormField(
                  controller: _priceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Preço',
                    suffixText: 'MT',
                    helperText:
                        'Digite apenas números (use vírgula ou ponto para decimais).',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9., ]'),
                    ),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o preço';
                    }
                    final v = double.tryParse(
                      value.replaceAll(' ', '').replaceAll(',', '.'),
                    );
                    if (v == null || v <= 0) {
                      return 'Informe um valor válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Habilitar Localização'),
                        subtitle: const Text(
                          'Mostrar a localização real onde o produto está',
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
                                'Endereço / Referência:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              LocationAutocompleteField(
                                controller: _locationAddressCtrl,
                                label: 'Endereço da localização',
                                hint: 'Ex: Bairro X, rua Y, perto do mercado Z',
                                onPlaceSelected: (details) {
                                  setState(() {
                                    _locationAddress = details.formattedAddress;
                                    _locationLatitude = details.lat;
                                    _locationLongitude = details.lng;
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Não foi possível obter a localização. Verifique o GPS e as permissões.',
                                          ),
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  final address =
                                      await LocationService.getAddressFromCoordinates(
                                        position.latitude,
                                        position.longitude,
                                      );

                                  setState(() {
                                    _locationLatitude = position.latitude;
                                    _locationLongitude = position.longitude;
                                    // Só escreve no campo se veio endereço real
                                    if (address != null && address.isNotEmpty) {
                                      _locationAddress = address;
                                      _locationAddressCtrl.text = address;
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
                                label: const Text('Obter localização atual'),
                              ),
                              if (_locationLatitude != null &&
                                  _locationLongitude != null) ...[
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
                                              _locationLatitude!,
                                              _locationLongitude!,
                                            ),
                                            initialZoom: 16,
                                            interactionOptions:
                                                const InteractionOptions(
                                                  flags:
                                                      InteractiveFlag
                                                          .pinchZoom |
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
                                                    _locationLatitude!,
                                                    _locationLongitude!,
                                                  ),
                                                  width: 40,
                                                  height: 40,
                                                  alignment:
                                                      Alignment.bottomCenter,
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
                                                  'https://www.google.com/maps/search/?api=1&query=${_locationLatitude!.toStringAsFixed(6)},${_locationLongitude!.toStringAsFixed(6)}',
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

                // Promoção
                Row(
                  children: [
                    Switch.adaptive(
                      value: _hasPromotion,
                      activeColor: Colors.deepPurple,
                      onChanged: (value) {
                        setState(() => _hasPromotion = value);
                        if (!value) {
                          _promoPriceCtrl.clear();
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text('Ativar promoção'),
                  ],
                ),
                const SizedBox(height: 8),
                if (_hasPromotion)
                  TextFormField(
                    controller: _promoPriceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Preço promocional',
                      suffixText: 'MT',
                      helperText:
                          'Somente números; use vírgula ou ponto para decimais.',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9., ]'),
                      ),
                    ],
                    validator: (value) {
                      if (!_hasPromotion) return null;
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe o preço promocional';
                      }
                      final v = double.tryParse(
                        value.replaceAll(' ', '').replaceAll(',', '.'),
                      );
                      if (v == null || v <= 0) {
                        return 'Informe um valor válido';
                      }
                      return null;
                    },
                  ),

                const SizedBox(height: 16),

                // Descrição com formatação simples (estilo vendedor)
                TextFormField(
                  controller: _descCtrl,
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
                    labelText: 'Descrição da publicação',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                    helperText: 'Conte rapidamente o que você está oferecendo',
                  ),
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
                        color: _descriptionBold
                            ? Colors.deepPurple
                            : Colors.grey,
                      ),
                      onPressed: () {
                        final text = _descCtrl.text;
                        final selection = _descCtrl.selection;
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

                        final newText = '$before**$selected**$after';
                        _descCtrl.value = _descCtrl.value.copyWith(
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
                        color: _descriptionItalic
                            ? Colors.deepPurple
                            : Colors.grey,
                      ),
                      onPressed: () {
                        final text = _descCtrl.text;
                        final selection = _descCtrl.selection;
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

                        final newText = '${before}_${selected}_$after';
                        _descCtrl.value = _descCtrl.value.copyWith(
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

                // Publicação ativa (sempre true por padrão)
                Row(
                  children: [
                    Switch.adaptive(
                      value: _isActive,
                      activeColor: Colors.deepPurple,
                      onChanged: (value) {
                        setState(() => _isActive = value);
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text('Publicação ativa'),
                  ],
                ),

                const SizedBox(height: 24),

                WVPrimaryButton(
                  label: _isExpired
                      ? 'Republicar'
                      : (widget.publicacao != null ? 'Atualizar' : 'Publicar'),
                  onPressed: _isSaving ? null : _save,
                  isLoading: _isSaving,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
