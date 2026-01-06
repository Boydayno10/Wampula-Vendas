import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

enum _ProductAction {
  edit,
  delete,
}

class _ProductsPageState extends State<ProductsPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  List<_Product> _products = const [];
  String _search = '';
  bool _onlyActive = false;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProducts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final supabase = Supabase.instance.client;

    try {
      final data = await supabase.from('products').select();
      final products = (data as List)
          .map((row) => _Product.fromMap(row as Map<String, dynamic>))
          .toList();

      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar produtos: $e';
        _loading = false;
      });
    }
  }

  Future<void> _editProduct(_Product product) async {
    final nameController = TextEditingController(text: product.name);
    final priceController =
        TextEditingController(text: product.price.toStringAsFixed(2));
    final stockController =
        TextEditingController(text: product.stock.toString());
    final descriptionController =
        TextEditingController(text: product.description ?? '');
    final imageController =
        TextEditingController(text: product.image ?? '');
    final categoryController =
        TextEditingController(text: product.category ?? '');
    final transportPriceController = TextEditingController(
      text: product.transportPrice?.toStringAsFixed(2) ?? '0.00',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Editar produto'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: 'Preço'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextField(
                    controller: stockController,
                    decoration: const InputDecoration(labelText: 'Stock'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: false),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    decoration:
                        const InputDecoration(labelText: 'Descrição'),
                    maxLines: 3,
                  ),
                  TextField(
                    controller: imageController,
                    decoration: const InputDecoration(
                        labelText: 'URL da imagem principal'),
                  ),
                  TextField(
                    controller: categoryController,
                    decoration:
                        const InputDecoration(labelText: 'Categoria'),
                  ),
                  TextField(
                    controller: transportPriceController,
                    decoration: const InputDecoration(
                        labelText: 'Preço de transporte'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
            ),
            actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    final supabase = Supabase.instance.client;

    try {
      final price = double.tryParse(priceController.text.replaceAll(',', '.'));
      final stock = int.tryParse(stockController.text);

      final transportPrice = double.tryParse(
        transportPriceController.text.replaceAll(',', '.'),
      );

      await supabase.from('products').update({
        'name': nameController.text.trim(),
        if (price != null) 'price': price,
        if (stock != null) 'stock': stock,
        'description': descriptionController.text.trim(),
        'image': imageController.text.trim().isEmpty
            ? product.image
            : imageController.text.trim(),
        'category': categoryController.text.trim().isEmpty
            ? product.category
            : categoryController.text.trim(),
        if (transportPrice != null) 'transport_price': transportPrice,
      }).eq('id', product.id);

      await _loadProducts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar produto: $e')),
      );
    }
  }

  Future<void> _toggleActive(_Product product) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase
          .from('products')
          .update({'active': !product.active}).eq('id', product.id);
      await _loadProducts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar ativo: $e')),
      );
    }
  }

  Future<void> _deleteProduct(_Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir produto'),
        content: Text(
          'Tem certeza que deseja excluir o produto "${product.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final supabase = Supabase.instance.client;
    try {
      await supabase.from('products').delete().eq('id', product.id);
      await _loadProducts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir produto: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!));
    }

    final totalProducts = _products.length;
    final activeProducts = _products.where((p) => p.active).length;

    final query = _search.toLowerCase();
    final filtered = _products.where((p) {
      final matchesQuery = query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.id.toLowerCase().contains(query);
      if (!matchesQuery) return false;
      if (_onlyActive && !p.active) return false;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Chip(label: Text('Total: $totalProducts')),
            Chip(label: Text('Ativos: $activeProducts')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar por nome ou ID',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {
                    _search = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            FilterChip(
              label: const Text('Somente ativos'),
              selected: _onlyActive,
              onSelected: (v) {
                setState(() => _onlyActive = v);
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Recarregar',
              icon: const Icon(Icons.refresh),
              onPressed: _loadProducts,
            ),
          ],
        ),
        const SizedBox(height: 16),
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Produtos'),
            Tab(text: 'Categorias'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildProductsTable(filtered),
              const _CategoriesTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductsTable(List<_Product> filtered) {
    if (filtered.isEmpty) {
      return const Center(child: Text('Nenhum produto cadastrado.'));
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;

          if (maxWidth > 900) {
            // Desktop: tabela ajustada para caber na largura, só scroll vertical
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                DataTable(
                  columnSpacing: 16,
                  columns: const [
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('Nome')),
                    DataColumn(label: Text('Preço')),
                    DataColumn(label: Text('Stock')),
                    DataColumn(label: Text('Ativo')),
                    DataColumn(label: Text('Pop')),
                    DataColumn(label: Text('Vendidos')),
                    DataColumn(label: Text('Views')),
                    DataColumn(label: Text('Score')),
                    DataColumn(label: Text('Ações')),
                  ],
                  rows: filtered
                      .map(
                        (p) => DataRow(
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  Text(p.id.substring(0, 8)),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    tooltip: 'Copiar ID completo',
                                    icon: const Icon(
                                      Icons.copy,
                                      size: 16,
                                    ),
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: p.id),
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content:
                                                Text('ID do produto copiado.'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 160,
                                child: Text(
                                  p.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(p.price.toStringAsFixed(2))),
                            DataCell(Text(p.stock.toString())),
                            DataCell(
                              Transform.scale(
                                scale: 0.7,
                                child: Switch(
                                  value: p.active,
                                  onChanged: (_) => _toggleActive(p),
                                ),
                              ),
                            ),
                            DataCell(Text(p.popularity.toStringAsFixed(1))),
                            DataCell(Text(p.soldCount.toString())),
                            DataCell(Text(p.viewsCount.toString())),
                            DataCell(
                              Text(
                                p.popularityScore.toStringAsFixed(1),
                              ),
                            ),
                            DataCell(
                              Align(
                                alignment: Alignment.centerRight,
                                child: PopupMenuButton<_ProductAction>(
                                  tooltip: 'Mais ações',
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (action) {
                                    switch (action) {
                                      case _ProductAction.edit:
                                        _editProduct(p);
                                        break;
                                      case _ProductAction.delete:
                                        _deleteProduct(p);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: _ProductAction.edit,
                                      child: Text('Editar'),
                                    ),
                                    PopupMenuItem(
                                      value: _ProductAction.delete,
                                      child: Text('Excluir'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ],
            );
          }

          // Mobile: cards verticais sem scroll horizontal
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final p = filtered[index];
              return Card(
                margin:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('ID: ${p.id.substring(0, 8)}'),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Copiar ID completo',
                            icon: const Icon(
                              Icons.copy,
                              size: 16,
                            ),
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: p.id),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('ID do produto copiado.'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      Text('Preço: ${p.price.toStringAsFixed(2)}'),
                      Text('Stock: ${p.stock}'),
                      Text('Vendidos: ${p.soldCount} · Views: ${p.viewsCount}'),
                      Text('Score: ${p.popularityScore.toStringAsFixed(1)}'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Ativo'),
                          Transform.scale(
                            scale: 0.9,
                            child: Switch(
                              value: p.active,
                              onChanged: (_) => _toggleActive(p),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: PopupMenuButton<_ProductAction>(
                          tooltip: 'Mais ações',
                          icon: const Icon(Icons.more_vert),
                          onSelected: (action) {
                            switch (action) {
                              case _ProductAction.edit:
                                _editProduct(p);
                                break;
                              case _ProductAction.delete:
                                _deleteProduct(p);
                                break;
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: _ProductAction.edit,
                              child: Text('Editar'),
                            ),
                            PopupMenuItem(
                              value: _ProductAction.delete,
                              child: Text('Excluir'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Product {
  final String id;
  final String name;
  final double price;
  final int stock;
  final bool active;
  final double popularity;
  final int soldCount;
  final int viewsCount;
  final double popularityScore;
  final String? description;
  final String? image;
  final String? category;
  final double? transportPrice;
  final bool hasSizeOption;
  final bool hasColorOption;
  final bool hasAgeOption;
  final bool hasStorageOption;
  final bool hasPantSizeOption;
  final bool hasShoeSizeOption;
  final bool hasLocationEnabled;
  final double? storeLatitude;
  final double? storeLongitude;
  final String? storeAddress;

  _Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.active,
    required this.popularity,
    required this.soldCount,
    required this.viewsCount,
    required this.popularityScore,
    this.description,
    this.image,
    this.category,
    this.transportPrice,
    this.hasSizeOption = false,
    this.hasColorOption = false,
    this.hasAgeOption = false,
    this.hasStorageOption = false,
    this.hasPantSizeOption = false,
    this.hasShoeSizeOption = false,
    this.hasLocationEnabled = false,
    this.storeLatitude,
    this.storeLongitude,
    this.storeAddress,
  });

  factory _Product.fromMap(Map<String, dynamic> map) {
    return _Product(
      id: map['id'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      stock: (map['stock'] as int?) ?? 0,
      active: (map['active'] as bool?) ?? true,
      popularity: (map['popularity'] as num?)?.toDouble() ?? 0,
      soldCount: (map['sold_count'] as int?) ?? 0,
      viewsCount: (map['views_count'] as int?) ?? 0,
      popularityScore: (map['popularity_score'] as num?)?.toDouble() ?? 0,
      description: map['description'] as String?,
      image: map['image'] as String?,
      category: map['category'] as String?,
      transportPrice: (map['transport_price'] as num?)?.toDouble(),
      hasSizeOption: (map['has_size_option'] as bool?) ?? false,
      hasColorOption: (map['has_color_option'] as bool?) ?? false,
      hasAgeOption: (map['has_age_option'] as bool?) ?? false,
      hasStorageOption: (map['has_storage_option'] as bool?) ?? false,
      hasPantSizeOption: (map['has_pant_size_option'] as bool?) ?? false,
      hasShoeSizeOption: (map['has_shoe_size_option'] as bool?) ?? false,
      hasLocationEnabled: (map['has_location_enabled'] as bool?) ?? false,
      storeLatitude: (map['store_latitude'] as num?)?.toDouble(),
      storeLongitude: (map['store_longitude'] as num?)?.toDouble(),
      storeAddress: map['store_address'] as String?,
    );
  }
}

class _CategoriesTab extends StatefulWidget {
  const _CategoriesTab();

  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _categories = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final supabase = Supabase.instance.client;

    try {
      final cats = await supabase.from('categories').select();
      setState(() {
        _categories = (cats as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar categorias: $e';
        _loading = false;
      });
    }
  }

  Future<void> _editCategory(Map<String, dynamic> category) async {
    final nameController =
        TextEditingController(text: category['name'] as String);
    final descController = TextEditingController(
      text: (category['description'] as String?) ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar categoria'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Descrição'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final supabase = Supabase.instance.client;
    try {
      await supabase.from('categories').update({
        'name': nameController.text.trim(),
        'description': descController.text.trim(),
      }).eq('id', category['id']);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar categoria: $e')),
      );
    }
  }

  Future<void> _toggleCategoryActive(Map<String, dynamic> category) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase
          .from('categories')
          .update({'active': !(category['active'] as bool? ?? true)})
          .eq('id', category['id']);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar categoria: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!));
    }

    if (_categories.isEmpty) {
      return const Center(child: Text('Nenhuma categoria cadastrada.'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Nome')),
              DataColumn(label: Text('Descrição')),
              DataColumn(label: Text('Ativa')),
              DataColumn(label: Text('Ações')),
            ],
            rows: _categories
                .map(
                  (c) => DataRow(
                    cells: [
                      DataCell(Text(c['name'] as String)),
                      DataCell(Text((c['description'] as String?) ?? '-')),
                      DataCell(
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: (c['active'] as bool?) ?? true,
                            onChanged: (_) => _toggleCategoryActive(c),
                          ),
                        ),
                      ),
                      DataCell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: PopupMenuButton<int>(
                            tooltip: 'Mais ações',
                            icon: const Icon(Icons.more_vert),
                            onSelected: (action) {
                              if (action == 0) {
                                _editCategory(c);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 0,
                                child: Text('Editar'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

