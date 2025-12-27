import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/subcategory_model.dart';
import '../screens/subcategory/subcategory_screen.dart';
import '../services/product_filter_service.dart';
import '../services/subcategory_service.dart';
import '../widgets/skeleton_loader.dart';

class SubCategorySelector extends StatefulWidget {
  final String category;
  final List<ProductModel> allProducts;

  const SubCategorySelector({
    super.key,
    required this.category,
    required this.allProducts,
  });

  @override
  State<SubCategorySelector> createState() => _SubCategorySelectorState();
}

class _SubCategorySelectorState extends State<SubCategorySelector> {
  bool _isLoading = true;
  List<SubcategoryModel> _subcategories = [];

  @override
  void initState() {
    super.initState();
    _loadSubcategories();
  }

  Future<void> _loadSubcategories() async {
    if (!SubcategoryService.isLoaded) {
      await SubcategoryService.loadSubcategories();
    }
    if (mounted) {
      setState(() {
        _subcategories = SubcategoryService.subcategories;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Skeleton horizontal combinando com o layout final de subcategorias
      return const SubcategoryRowSkeleton(itemCount: 3);
    }

    if (_subcategories.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Se não há produtos, não mostra as subcategorias
    if (widget.allProducts.isEmpty) {
      print('⚠️ Nenhum produto disponível');
      return const SizedBox.shrink();
    }

    print('\n========================================');
    print('📊 SUBCATEGORY SELECTOR - Categoria: "${widget.category}"');
    print('📦 Total de produtos recebidos: ${widget.allProducts.length}');
    print('🏷️ Subcategorias carregadas: ${_subcategories.length}');
    
    // 🎯 Filtrar produtos da categoria atual PRIMEIRO
    final categoryProducts = widget.category == 'Início' || widget.category.isEmpty
        ? widget.allProducts
        : widget.allProducts.where((p) {
            final matches = p.category.toLowerCase().trim() == widget.category.toLowerCase().trim();
            return matches;
          }).toList();

    print('✅ Produtos filtrados para "${widget.category}": ${categoryProducts.length}');

    // Se não há nenhum produto na categoria, não mostrar subcategorias
    if (categoryProducts.isEmpty) {
      print('⚠️ Nenhum produto na categoria "${widget.category}", ocultando subcategorias');
      print('========================================\n');
      return const SizedBox.shrink();
    }

    // 🎯 Processar subcategorias dinâmicas do Supabase
    // Primeiro, filtrar quais subcategorias têm produtos válidos
    final List<Map<String, dynamic>> validSubcategories = [];
    
    for (final subcategory in _subcategories) {
      final label = subcategory.name;
      final filterType = subcategory.filterType;
      
      // 📊 Aplicar filtro específico APENAS nos produtos já filtrados por categoria
      final filtered = ProductFilterService.filterProducts(
        allProducts: categoryProducts,
        categoryName: 'Início', // Usa 'Início' pois categoryProducts já está filtrado
        filterType: filterType,
      );

      // 🎯 FILTRO ESPECÍFICO: Cada subcategoria mostra APENAS produtos relevantes
      List<ProductModel> validFilteredProducts = [];
      
      // Aplicar filtro baseado no tipo (menos restritivo)
      switch (filterType) {
        case ProductFilterType.promocoes:
          // Aceita produtos com old_price ou mostra todos se não houver promoções
          validFilteredProducts = filtered.where((p) => 
            p.oldPrice != null && p.oldPrice! > 0
          ).toList();
          
          // Se não houver promoções, mostra os produtos com preço mais baixo
          if (validFilteredProducts.isEmpty) {
            validFilteredProducts = filtered.take(5).toList();
            print('⚠️ "$label": Sem promoções, mostrando produtos alternativos (${validFilteredProducts.length})');
          } else {
            print('✅ "$label" VÁLIDA: ${validFilteredProducts.length} produtos');
          }
          break;
          
        case ProductFilterType.novos:
          final now = DateTime.now();
          validFilteredProducts = filtered.where((p) {
            if (p.createdAt == null) return true; // Se não tem data, considera novo
            final daysSinceCreation = now.difference(p.createdAt!).inDays;
            return daysSinceCreation <= 90; // Aumentado de 30 para 90 dias
          }).toList();
          
          // Se não houver produtos novos, mostra os mais recentes
          if (validFilteredProducts.isEmpty) {
            validFilteredProducts = filtered.take(5).toList();
            print('⚠️ "$label": Mostrando produtos recentes (${validFilteredProducts.length})');
          } else {
            print('✅ "$label" VÁLIDA: ${validFilteredProducts.length} produtos');
          }
          break;
          
        case ProductFilterType.maisComprados:
          // Ordena por vendas, mas mostra todos (mesmo com 0 vendas)
          validFilteredProducts = filtered;
          if (validFilteredProducts.isEmpty) {
            print('⚠️ "$label": Sem produtos');
          } else {
            final comVendas = validFilteredProducts.where((p) => p.soldCount > 0).length;
            print('✅ "$label" VÁLIDA: ${validFilteredProducts.length} produtos ($comVendas com vendas)');
          }
          break;
          
        case ProductFilterType.maisPopulares:
          // Mostra todos os produtos, ordenados por popularidade
          validFilteredProducts = filtered;
          if (validFilteredProducts.isEmpty) {
            print('⚠️ "$label": Sem produtos');
          } else {
            final comCliques = validFilteredProducts.where((p) => (p.clicksCount ?? 0) > 0).length;
            print('✅ "$label" VÁLIDA: ${validFilteredProducts.length} produtos ($comCliques com cliques)');
          }
          break;
          
        case ProductFilterType.maisBaratos:
          validFilteredProducts = filtered;
          print('✅ "$label" VÁLIDA: ${validFilteredProducts.length} produtos');
          break;
          
        case ProductFilterType.recomendados:
          // Mostra todos os produtos (recomendação baseada em algoritmo)
          validFilteredProducts = filtered;
          if (validFilteredProducts.isEmpty) {
            print('⚠️ "$label": Sem produtos');
          } else {
            final comMetricas = validFilteredProducts.where((p) => 
              (p.clicksCount ?? 0) > 0 || (p.viewsCount ?? 0) > 0 || p.soldCount > 0
            ).length;
            print('✅ "$label" VÁLIDA: ${validFilteredProducts.length} produtos ($comMetricas com métricas)');
          }
          break;
      }
      
      // Adicionar à lista apenas se houver produtos válidos
      if (validFilteredProducts.isNotEmpty) {
        final topProduct = validFilteredProducts.first;
        final productImage = (topProduct.images != null && topProduct.images!.isNotEmpty)
            ? topProduct.images!.first
            : topProduct.image;
        
        validSubcategories.add({
          'subcategory': subcategory,
          'label': label,
          'filterType': filterType,
          'image': productImage,
          'productCount': validFilteredProducts.length,
        });
        print('✅ "$label" adicionada à lista de subcategorias válidas\n');
      } else {
        print('🚫 Subcategoria "$label" NÃO será exibida (sem produtos)\n');
      }
    }
    
    // Se não há subcategorias válidas, não mostrar nada
    if (validSubcategories.isEmpty) {
      print('⚠️ Nenhuma subcategoria válida para exibir');
      print('========================================\n');
      return const SizedBox.shrink();
    }
    
    print('📋 Total de subcategorias válidas: ${validSubcategories.length}');
    print('========================================\n');
    
    // Construir a lista de subcategorias válidas (SCROLL HORIZONTAL)
    return Container(
      height: 180,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: validSubcategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = validSubcategories[index];
          return _SubItem(
            label: item['label'] as String,
            image: item['image'] as String,
            productCount: item['productCount'] as int,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubCategoryScreen(
                    subCategory: item['label'] as String,
                    category: widget.category,
                    filterType: item['filterType'] as ProductFilterType,
                    allProducts: widget.allProducts,
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

class _SubItem extends StatelessWidget {
  final String label;
  final String image;
  final int productCount;
  final VoidCallback onTap;

  const _SubItem({
    super.key,
    required this.label,
    required this.image,
    required this.productCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: image.startsWith('http')
                ? Image.network(
                    image,
                    width: double.infinity,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 100,
                        color: Colors.grey[200],
                        child: Icon(Icons.image_not_supported, color: Colors.grey),
                      );
                    },
                  )
                : Image.asset(
                    image,
                    width: double.infinity,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 100,
                        color: Colors.grey[200],
                        child: Icon(Icons.image_not_supported, color: Colors.grey),
                      );
                    },
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '$productCount produtos',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
