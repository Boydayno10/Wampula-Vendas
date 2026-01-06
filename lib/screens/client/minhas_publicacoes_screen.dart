import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/currency_utils.dart';

import '../../services/auth_service.dart';
import '../../services/client_publicacao_service.dart';
import '../../models/client_publicacao_model.dart';
import '../../services/seller_product_service.dart';
import 'nova_publicacao_screen.dart';
import '../product/product_detail_screen.dart';

class MinhasPublicacoesScreen extends StatefulWidget {
  const MinhasPublicacoesScreen({super.key});

  @override
  State<MinhasPublicacoesScreen> createState() =>
      _MinhasPublicacoesScreenState();
}

class _MinhasPublicacoesScreenState extends State<MinhasPublicacoesScreen> {
  String _filterStatus = 'Todos'; // Todos, Ativas, Inativas
  String _searchQuery = '';
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  final Map<String, int> _viewsByPublication = {};

  @override
  void initState() {
    super.initState();
    _listenRealtime();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {});
  }

  void _listenRealtime() {
    final userId = AuthService.currentUser.id;
    if (userId.isEmpty) return;

    final client = Supabase.instance.client;
    _subscription?.cancel();

    _subscription = client
        .from('client_publications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((_) {
          if (mounted) {
            setState(() {});
          }
        });
  }

  Future<List<ClientPublicacaoModel>> _loadPublicacoes() async {
    return ClientPublicacaoService.getMyPublications(
      nameQuery: _searchQuery.isEmpty ? null : _searchQuery,
      statusFilter: _filterStatus == 'Todos' ? null : _filterStatus,
    );
  }

  Future<List<ClientPublicacaoModel>> _getFilteredPublicacoes() async {
    // Toda filtragem (status + busca) já é feita no Supabase
    // em _loadPublicacoes para ter uma pesquisa real no backend.
    return _loadPublicacoes();
  }

  Future<void> _delete(ClientPublicacaoModel pub) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar publicação'),
        content: Text('Deseja realmente apagar "${pub.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ClientPublicacaoService.deletePublication(pub.id);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Publicação apagada com sucesso')),
        );
      }
    }
  }

  Future<void> _toggleActive(ClientPublicacaoModel pub) async {
    final newValue = !pub.active;
    await ClientPublicacaoService.setActive(pub, newValue);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newValue ? 'Publicação ativada' : 'Publicação desativada',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.currentUser;
    final bool isSellerWithStore = currentUser.isSeller;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Minhas Publicações'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            initialValue: _filterStatus,
            onSelected: (value) {
              setState(() => _filterStatus = value);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'Todos', child: Text('Todos')),
              PopupMenuItem(value: 'Ativas', child: Text('Ativas')),
              PopupMenuItem(value: 'Inativas', child: Text('Inativas')),
            ],
          ),
        ],
      ),
      floatingActionButton: isSellerWithStore
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NovaPublicacaoScreen(),
                  ),
                );
                if (created == true && mounted) {
                  setState(() {});
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Nova Publicação'),
            ),
      body: isSellerWithStore
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.store_mall_directory,
                      size: 64,
                      color: Colors.deepPurple,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Esta conta está verificada para fazer vendas de produtos diretamente pela sua loja.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Use o painel do vendedor para criar e gerir os seus produtos. Aqui não é possível criar publicações temporárias.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
          Expanded(
            child: FutureBuilder<List<ClientPublicacaoModel>>(
              future: _getFilteredPublicacoes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 12),
                        Text('Erro ao carregar publicações: ${snapshot.error}'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  );
                }

                final pubs = snapshot.data ?? [];

                return Column(
                  children: [
                    // Barra de busca (igual estilo do Meus Produtos)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Material(
                        elevation: 1.5,
                        shadowColor: Colors.black.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(24),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Buscar publicações...',
                            prefixIcon: Icon(Icons.search),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: pubs.isEmpty
                          ? RefreshIndicator(
                              onRefresh: _refresh,
                              child: ListView(
                                children: const [
                                  SizedBox(height: 100),
                                  Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.post_add_outlined,
                                          size: 64,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'Você ainda não tem publicações.',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _refresh,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                itemCount: pubs.length,
                                itemBuilder: (context, index) {
                                  final pub = pubs[index];
                                  return _buildItem(pub);
                                },
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(ClientPublicacaoModel pub) {
    final imageUrl = pub.images.isNotEmpty
        ? pub.images.first
        : 'assets/images/default.png';
    final isNetwork = imageUrl.startsWith('http');

    final expiresIn = pub.effectiveExpiresAt.difference(DateTime.now());
    final hoursLeft = expiresIn.inHours;

    // Carregar visualizações a partir do produto espelho (tabela products)
    final views = _viewsByPublication[pub.id] ?? 0;
    if (!_viewsByPublication.containsKey(pub.id)) {
      // Dispara carregamento assíncrono sem bloquear o build
      SellerProductService.getById(pub.id)
          .then((product) {
            if (!mounted || product == null) return;
            setState(() {
              _viewsByPublication[pub.id] = product.viewsCount ?? 0;
            });
          })
          .catchError((_) {});
    }

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.06),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final updated = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => NovaPublicacaoScreen(publicacao: pub),
            ),
          );
          if (updated == true && mounted) {
            setState(() {});
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Imagem (mesmo estilo do Meus Produtos)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    isNetwork
                        ? Image.network(
                            imageUrl,
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 70,
                                height: 70,
                                color: Colors.grey[300],
                                child: const Icon(Icons.image_not_supported),
                              );
                            },
                          )
                        : Image.asset(
                            imageUrl,
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 70,
                                height: 70,
                                color: Colors.grey[300],
                                child: const Icon(Icons.image_not_supported),
                              );
                            },
                          ),
                    // Badge de "EXPIRADA" no canto superior esquerdo
                    if (hoursLeft <= 0)
                      Positioned(
                        top: 4,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'EXPIRADA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Informações da publicação
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pub.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Temporarios',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          pub.promoPrice != null
                              ? CurrencyUtils.formatMt(pub.promoPrice!)
                              : CurrencyUtils.formatMt(pub.price),
                          style: const TextStyle(
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: pub.active
                                ? Colors.green.shade100
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            pub.active ? 'Ativa' : 'Inativa',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: pub.active
                                  ? Colors.green.shade700
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                hoursLeft <= 0
                                    ? Icons.schedule_outlined
                                    : Icons.access_time,
                                size: 12,
                                color: hoursLeft <= 0
                                    ? Colors.red
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                hoursLeft <= 0
                                    ? 'Expirada'
                                    : 'Expira em até $hoursLeft h',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: hoursLeft <= 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: hoursLeft <= 0
                                      ? Colors.red
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.visibility_outlined,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$views',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Menu de ações (igual padrão do vendedor)
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NovaPublicacaoScreen(publicacao: pub),
                      ),
                    );
                    if (updated == true && mounted) {
                      setState(() {});
                    }
                  } else if (value == 'view') {
                    if (pub.isExpired) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Esta publicação expirou. Republicar para voltar a visualizar.',
                          ),
                        ),
                      );
                      return;
                    }
                    try {
                      final sellerProduct =
                          await SellerProductService.getById(pub.id);
                      if (!mounted) return;

                      if (sellerProduct == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Não foi possível abrir a publicação.'),
                          ),
                        );
                        return;
                      }

                      final product = sellerProduct.toProductModel();

                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailScreen(
                            product: product,
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('Erro ao abrir publicação: $e'),
                        ),
                      );
                    }
                  } else if (value == 'toggle') {
                    await _toggleActive(pub);
                  } else if (value == 'delete') {
                    await _delete(pub);
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
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.remove_red_eye_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('Ver publicação'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          pub.active ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(pub.active ? 'Desativar' : 'Ativar'),
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
  }
}
