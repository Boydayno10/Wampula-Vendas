import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/seller_product_service.dart';
import '../../models/seller_product_model.dart';
import 'seller_product_form.dart';

class SellerProductsScreen extends StatefulWidget {
  const SellerProductsScreen({super.key});

  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen> {
  String _filterStatus = 'Todos'; // Todos, Ativos, Inativos
  String _searchQuery = '';

  Future<void> _refreshProducts() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {});
  }

  Future<List<SellerProductModel>> _getFilteredProducts() async {
    final sellerId = AuthService.currentUser.id;
    var products = await SellerProductService.bySeller(sellerId);

    // Filtrar por status
    if (_filterStatus == 'Ativos') {
      products = products.where((p) => p.active).toList();
    } else if (_filterStatus == 'Inativos') {
      products = products.where((p) => !p.active).toList();
    }

    // Filtrar por busca
    if (_searchQuery.isNotEmpty) {
      products = products
          .where((p) =>
              p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              p.category.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    return products;
  }

  Future<void> _deleteProduct(SellerProductModel product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja realmente excluir "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SellerProductService.remove(product.id);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produto excluído com sucesso')),
        );
      }
    }
  }

  Future<void> _toggleActive(SellerProductModel product) async {
    final updated = product.copyWith(active: !product.active);
    await SellerProductService.update(updated);
    setState(() {});
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.active ? 'Produto ativado' : 'Produto desativado',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Produtos'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _filterStatus,
            onSelected: (value) {
              setState(() => _filterStatus = value);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'Todos', child: Text('Todos')),
              const PopupMenuItem(value: 'Ativos', child: Text('Ativos')),
              const PopupMenuItem(value: 'Inativos', child: Text('Inativos')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SellerProductForm()),
          );
          setState(() {});
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo Produto'),
      ),
      body: FutureBuilder<List<SellerProductModel>>(
        future: _getFilteredProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Erro: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Tentar Novamente'),
                  ),
                ],
              ),
            );
          }

          final products = snapshot.data ?? [];

          return Column(
            children: [
              // Barra de busca
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar produtos...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),

              // Lista de produtos
              Expanded(
            child: products.isEmpty
                ? RefreshIndicator(
                    onRefresh: _refreshProducts,
                    child: ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Nenhum produto encontrado',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refreshProducts,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: products.length,
                      itemBuilder: (_, i) {
                        final p = products[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SellerProductForm(product: p),
                                ),
                              );
                              setState(() {});
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Imagem do produto
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                  child: p.images.isNotEmpty && p.images.first.startsWith('http')
                                    ? Image.network(
                                        p.images.first,
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 70,
                                            height: 70,
                                            color: Colors.grey[300],
                                            child: Icon(Icons.image_not_supported),
                                          );
                                        },
                                      )
                                    : Image.asset(
                                        p.images.isNotEmpty ? p.images.first : 'assets/images/default.png',
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 70,
                                            height: 70,
                                            color: Colors.grey[300],
                                            child: Icon(Icons.image_not_supported),
                                          );
                                        },
                                      ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Informações do produto
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          p.category,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Text(
                                              '${p.price.toStringAsFixed(2)} MT',
                                              style: const TextStyle(
                                                color: Colors.deepPurple,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const Spacer(),
                                            Icon(
                                              Icons.inventory_2,
                                              size: 14,
                                              color: p.stock > 0 ? Colors.green : Colors.red,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${p.stock}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: p.stock > 0 ? Colors.green : Colors.red,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: p.active
                                                    ? Colors.green.shade100
                                                    : Colors.grey.shade300,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                p.active ? 'Ativo' : 'Inativo',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: p.active
                                                      ? Colors.green.shade700
                                                      : Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Menu de ações
                                  PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SellerProductForm(product: p),
                                          ),
                                        );
                                        setState(() {});
                                      } else if (value == 'toggle') {
                                        await _toggleActive(p);
                                      } else if (value == 'delete') {
                                        await _deleteProduct(p);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 20),
                                            SizedBox(width: 8),
                                            Text('Editar'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'toggle',
                                        child: Row(
                                          children: [
                                            Icon(
                                              p.active ? Icons.visibility_off : Icons.visibility,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(p.active ? 'Desativar' : 'Ativar'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, size: 20, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Remover', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ),
            ],
          );
        },
      ),
    );
  }
}
