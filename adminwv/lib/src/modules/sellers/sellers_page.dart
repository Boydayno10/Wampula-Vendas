import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellersPage extends StatefulWidget {
  const SellersPage({super.key});

  @override
  State<SellersPage> createState() => _SellersPageState();
}

enum _SellerAction {
  edit,
  remove,
  removeStore,
}

class _SellersPageState extends State<SellersPage> {
  bool _loading = true;
  String? _error;
  List<_SellerProfile> _sellers = const [];
  String _search = '';

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
      final data = await supabase
          .from('profiles')
          .select()
          .eq('is_seller', true);

      final sellers = (data as List)
          .map((e) => _SellerProfile.fromMap(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _sellers = sellers;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar vendedores: $e';
        _loading = false;
      });
    }
  }

  Future<void> _editSeller(_SellerProfile seller) async {
    final storeNameController =
        TextEditingController(text: seller.storeName ?? '');
    final storeDescController =
        TextEditingController(text: seller.storeDescription ?? '');
    final bairroController = TextEditingController(text: seller.bairro ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar loja/vendedor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: storeNameController,
                decoration: const InputDecoration(labelText: 'Nome da loja'),
              ),
              TextField(
                controller: storeDescController,
                decoration:
                    const InputDecoration(labelText: 'Descrição da loja'),
              ),
              TextField(
                controller: bairroController,
                decoration: const InputDecoration(labelText: 'Bairro'),
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

    if (confirmed != true) return;

    final supabase = Supabase.instance.client;

    try {
      await supabase.from('profiles').update({
        'store_name': storeNameController.text.trim(),
        'store_description': storeDescController.text.trim(),
        'bairro': bairroController.text.trim(),
      }).eq('id', seller.id);

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar vendedor: $e')),
      );
    }
  }

  Future<void> _removeSeller(_SellerProfile seller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover vendedor'),
        content: Text(
          'Tem certeza que deseja remover ${seller.name} como vendedor? Ele continuará como usuário comum.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final supabase = Supabase.instance.client;
    try {
      await supabase
          .from('profiles')
          .update({'is_seller': false}).eq('id', seller.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao remover vendedor: $e')),
      );
    }
  }

  Future<void> _removeStore(_SellerProfile seller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover loja'),
        content: Text(
          'Tem certeza que deseja remover a loja "${seller.storeName ?? '-'}" deste vendedor? O campo de nome da loja ficará vazio (NULL).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover loja'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final supabase = Supabase.instance.client;
    try {
      await supabase
          .from('profiles')
          .update({'store_name': null}).eq('id', seller.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao remover loja: $e')),
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

    if (_sellers.isEmpty) {
      return const Center(child: Text('Nenhuma loja/vendedor encontrado.'));
    }

    final totalSellers = _sellers.length;
    final query = _search.toLowerCase();
    final filtered = _sellers.where((s) {
      final text = '${s.name ?? ''} ${s.email ?? ''} ${s.storeName ?? ''}';
      return query.isEmpty || text.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Chip(label: Text('Vendedores: $totalSellers')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar por nome, email ou loja',
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
            IconButton(
              tooltip: 'Recarregar',
              icon: const Icon(Icons.refresh),
              onPressed: _load,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: filtered.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 80),
                      Center(
                        child: Text(
                          'Nenhuma loja/vendedor encontrado com esse filtro.',
                        ),
                      ),
                    ],
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;

                      if (maxWidth > 900) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            DataTable(
                              columnSpacing: 16,
                              columns: const [
                                DataColumn(label: Text('ID')),
                                DataColumn(label: Text('Nome')),
                                DataColumn(label: Text('Email')),
                                DataColumn(label: Text('Loja')),
                                DataColumn(label: Text('Bairro')),
                                DataColumn(label: Text('Ações')),
                              ],
                              rows: filtered
                                  .map(
                                    (s) => DataRow(
                                      cells: [
                                        DataCell(
                                            Text(s.id.substring(0, 8))),
                                        DataCell(
                                          SizedBox(
                                            width: 140,
                                            child: Text(
                                              s.name ?? '-',
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 180,
                                            child: Text(
                                              s.email ?? '-',
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 160,
                                            child: Text(
                                              s.storeName ?? '-',
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(s.bairro ?? '-')),
                                        DataCell(
                                          Align(
                                            alignment:
                                                Alignment.centerRight,
                                            child:
                                                PopupMenuButton<_SellerAction>(
                                              tooltip: 'Mais ações',
                                              icon: const Icon(
                                                Icons.more_vert,
                                              ),
                                              onSelected: (action) {
                                                switch (action) {
                                                  case _SellerAction.edit:
                                                    _editSeller(s);
                                                    break;
                                                  case _SellerAction.remove:
                                                    _removeSeller(s);
                                                    break;
                                                  case _SellerAction.removeStore:
                                                    _removeStore(s);
                                                    break;
                                                }
                                              },
                                              itemBuilder: (context) => const [
                                                PopupMenuItem(
                                                  value: _SellerAction.edit,
                                                  child: Text('Editar loja'),
                                                ),
                                                PopupMenuItem(
                                                  value:
                                                      _SellerAction.removeStore,
                                                  child: Text('Remover loja'),
                                                ),
                                                PopupMenuItem(
                                                  value:
                                                      _SellerAction.remove,
                                                  child:
                                                      Text('Remover vendedor'),
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

                      return ListView.builder(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final s = filtered[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 0),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.storeName ?? s.name ?? 'Sem nome',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text('ID: ${s.id.substring(0, 8)}'),
                                  Text('Nome: ${s.name ?? '-'}'),
                                  Text('Email: ${s.email ?? '-'}'),
                                  Text('Bairro: ${s.bairro ?? '-'}'),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: PopupMenuButton<_SellerAction>(
                                      tooltip: 'Mais ações',
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (action) {
                                        switch (action) {
                                          case _SellerAction.edit:
                                            _editSeller(s);
                                            break;
                                          case _SellerAction.removeStore:
                                            _removeStore(s);
                                            break;
                                          case _SellerAction.remove:
                                            _removeSeller(s);
                                            break;
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: _SellerAction.edit,
                                          child: Text('Editar loja'),
                                        ),
                                        PopupMenuItem(
                                          value: _SellerAction.removeStore,
                                          child: Text('Remover loja'),
                                        ),
                                        PopupMenuItem(
                                          value: _SellerAction.remove,
                                          child: Text('Remover vendedor'),
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
          ),
        ),
      ],
    );
  }
}

class _SellerProfile {
  final String id;
  final String? name;
  final String? email;
  final String? bairro;
  final String? storeName;
  final String? storeDescription;

  _SellerProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.bairro,
    required this.storeName,
    required this.storeDescription,
  });

  factory _SellerProfile.fromMap(Map<String, dynamic> map) {
    return _SellerProfile(
      id: map['id'] as String,
      name: map['name'] as String?,
      email: map['email'] as String?,
      bairro: map['bairro'] as String?,
      storeName: map['store_name'] as String?,
      storeDescription: map['store_description'] as String?,
    );
  }
}

