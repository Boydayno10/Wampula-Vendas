import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

enum _UserAction {
  edit,
  delete,
  toggleBan,
}

class _UsersPageState extends State<UsersPage> {
  bool _loading = true;
  String? _error;
  List<_AdminUser> _users = const [];
  String _search = '';
  bool _onlySellers = false;
  bool _onlyVerified = false;
  bool _onlyAdmins = false;
  bool _onlyBanned = false;

  // Larguras ajustáveis das colunas (estilo explorador de ficheiros)
  double _idColumnWidth = 90;
  double _nameColumnWidth = 140;
  double _emailColumnWidth = 200;
  double _phoneColumnWidth = 120;
  double _bairroColumnWidth = 140;

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
      final profilesData = await supabase.from('profiles').select();
      final adminsData = await supabase.from('admin_users').select('user_id');

      final admins = <String>{};
      for (final row in adminsData as List) {
        final id = row['user_id'];
        if (id is String) admins.add(id);
      }

      final users = (profilesData as List)
          .map((row) => _AdminUser.fromMap(row as Map<String, dynamic>, admins))
          .toList();

      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar usuários: $e';
        _loading = false;
      });
    }
  }

  Future<void> _updateProfile(_AdminUser user) async {
    final nameController = TextEditingController(text: user.name ?? '');
    final emailController = TextEditingController(text: user.email ?? '');
    final phoneController = TextEditingController(text: user.phone ?? '');
    final bairroController = TextEditingController(text: user.bairro ?? '');
    final storeNameController =
      TextEditingController(text: user.storeName ?? '');
    final storeDescriptionController =
      TextEditingController(text: user.storeDescription ?? '');
    final profileImageUrlController =
      TextEditingController(text: user.profileImageUrl ?? '');
    final storeBannerController =
      TextEditingController(text: user.storeBanner ?? '');

    bool isSeller = user.isSeller;
    bool verified = user.verified;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar usuário'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bairroController,
                  decoration: const InputDecoration(labelText: 'Bairro'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('É vendedor (is_seller)'),
                  value: isSeller,
                  onChanged: (v) {
                    setState(() {
                      isSeller = v;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Perfil verificado'),
                  value: verified,
                  onChanged: (v) {
                    setState(() {
                      verified = v;
                    });
                  },
                ),
                const Divider(height: 24),
                TextField(
                  controller: storeNameController,
                  decoration:
                      const InputDecoration(labelText: 'Nome da loja (store_name)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: storeDescriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descrição da loja (store_description)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: profileImageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'URL da foto de perfil (profile_image_url)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: storeBannerController,
                  decoration: const InputDecoration(
                    labelText: 'URL do banner da loja (store_banner)',
                  ),
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
        );
      },
    );

    if (confirmed != true) return;

    final supabase = Supabase.instance.client;
    final bool wasSeller = user.isSeller;

    try {
      await supabase.from('profiles').update({
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'bairro': bairroController.text.trim(),
        'is_seller': isSeller,
        'verified': verified,
        'store_name': storeNameController.text.trim().isEmpty
            ? null
            : storeNameController.text.trim(),
        'store_description': storeDescriptionController.text.trim().isEmpty
            ? null
            : storeDescriptionController.text.trim(),
        'profile_image_url': profileImageUrlController.text.trim().isEmpty
            ? null
            : profileImageUrlController.text.trim(),
        'store_banner': storeBannerController.text.trim().isEmpty
            ? null
            : storeBannerController.text.trim(),
          }).eq('id', user.id);

          // Se o usuário era vendedor e deixou de ser, desativar apenas
          // os produtos de LOJA (mantém publicações de clientes, categoria "Temporarios")
          if (wasSeller && !isSeller) {
            await supabase
            .from('products')
            .update({'active': false})
            .eq('seller_id', user.id)
            .neq('category', 'Temporarios');
          }

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    }
  }

  Future<void> _toggleVerified(_AdminUser user) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase
          .from('profiles')
          .update({'verified': !user.verified}).eq('id', user.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar verificação: $e')),
      );
    }
  }

  Future<void> _toggleSeller(_AdminUser user) async {
    final supabase = Supabase.instance.client;
    try {
      final bool becomingSeller = !user.isSeller;

      await supabase
          .from('profiles')
          .update({'is_seller': becomingSeller}).eq('id', user.id);

      // Se está deixando de ser vendedor, desativar apenas produtos de LOJA
      // (categoria diferente de "Temporarios"), mantendo publicações de clientes.
      if (!becomingSeller) {
        await supabase
        .from('products')
        .update({'active': false})
        .eq('seller_id', user.id)
        .neq('category', 'Temporarios');
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar vendedor: $e')),
      );
    }
  }

  Future<void> _toggleAdmin(_AdminUser user) async {
    final supabase = Supabase.instance.client;

    try {
      if (user.isAdmin) {
        await supabase.from('admin_users').delete().eq('user_id', user.id);
      } else {
        await supabase.from('admin_users').insert({'user_id': user.id});
      }

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar admin: $e')),
      );
    }
  }

  Future<void> _toggleBanned(_AdminUser user) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase
          .from('profiles')
          .update({'banned': !user.banned}).eq('id', user.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar banimento: $e')),
      );
    }
  }

  Future<void> _deleteProfile(_AdminUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir usuário'),
        content: Text(
          'Tem certeza que deseja excluir o perfil de ${user.name ?? user.id}? Isso não remove o registro de auth.users.',
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
      await supabase.from('profiles').delete().eq('id', user.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir: $e')),
      );
    }
  }

  Future<void> _copyUserId(_AdminUser user) async {
    await Clipboard.setData(ClipboardData(text: user.id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ID do usuário copiado.')),
    );
  }

  Widget _buildResizableHeader(
    String title,
    double width,
    ValueChanged<double> onResize,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: (details) {
            final newWidth =
                (width + details.delta.dx).clamp(70.0, 400.0) as double;
            onResize(newWidth);
          },
          child: SizedBox(
            width: 10,
            child: Center(
              child: Container(
                width: 2,
                height: 18,
                color:
                    Theme.of(context).dividerColor.withOpacity(0.7),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStatusSwitch(
    BuildContext context,
    String label,
    bool value,
    VoidCallback onToggle,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            onChanged: (_) => onToggle(),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!));
    }
    final totalUsers = _users.length;
    final sellersCount = _users.where((u) => u.isSeller).length;
    final verifiedCount = _users.where((u) => u.verified).length;
    final adminsCount = _users.where((u) => u.isAdmin).length;
    final bannedCount = _users.where((u) => u.banned).length;

    final query = _search.toLowerCase();
    final filtered = _users.where((u) {
      final matchesQuery = query.isEmpty ||
          (u.name ?? '').toLowerCase().contains(query) ||
          u.id.toLowerCase().contains(query) ||
          (u.phone ?? '').toLowerCase().contains(query);
      if (!matchesQuery) return false;
      if (_onlySellers && !u.isSeller) return false;
      if (_onlyVerified && !u.verified) return false;
      if (_onlyAdmins && !u.isAdmin) return false;
        if (_onlyBanned && !u.banned) return false;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            Chip(label: Text('Total: $totalUsers')),
            Chip(label: Text('Vendedores: $sellersCount')),
            Chip(label: Text('Verificados: $verifiedCount')),
            Chip(label: Text('Admins: $adminsCount')),
            if (bannedCount > 0)
              Chip(
                label: Text('Banidos: $bannedCount'),
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .errorContainer
                    .withOpacity(0.2),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar por nome, telefone ou ID',
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
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            FilterChip(
              label: const Text('Somente vendedores'),
              selected: _onlySellers,
              onSelected: (v) {
                setState(() => _onlySellers = v);
              },
            ),
            FilterChip(
              label: const Text('Somente verificados'),
              selected: _onlyVerified,
              onSelected: (v) {
                setState(() => _onlyVerified = v);
              },
            ),
            FilterChip(
              label: const Text('Somente admins'),
              selected: _onlyAdmins,
              onSelected: (v) {
                setState(() => _onlyAdmins = v);
              },
            ),
            FilterChip(
              label: const Text('Somente banidos'),
              selected: _onlyBanned,
              onSelected: (v) {
                setState(() => _onlyBanned = v);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: filtered.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 80),
                      Center(
                        child: Text('Nenhum usuário encontrado com os filtros.'),
                      ),
                    ],
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 900;

                      if (isWide) {
                        return ListView(
                          physics:
                              const AlwaysScrollableScrollPhysics(),
                          children: [
                            DataTable(
                              columnSpacing: 16,
                              columns: [
                                DataColumn(
                                  label: _buildResizableHeader(
                                    'ID',
                                    _idColumnWidth,
                                    (v) => setState(
                                      () => _idColumnWidth = v,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: _buildResizableHeader(
                                    'Nome',
                                    _nameColumnWidth,
                                    (v) => setState(
                                      () => _nameColumnWidth = v,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: _buildResizableHeader(
                                    'Email',
                                    _emailColumnWidth,
                                    (v) => setState(
                                      () => _emailColumnWidth = v,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: _buildResizableHeader(
                                    'Telefone',
                                    _phoneColumnWidth,
                                    (v) => setState(
                                      () => _phoneColumnWidth = v,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: _buildResizableHeader(
                                    'Bairro',
                                    _bairroColumnWidth,
                                    (v) => setState(
                                      () => _bairroColumnWidth = v,
                                    ),
                                  ),
                                ),
                                const DataColumn(label: Text('Vendedor')),
                                const DataColumn(label: Text('Verificado')),
                                const DataColumn(label: Text('')),
                              ],
                              rows: filtered
                                  .map(
                                    (u) => DataRow(
                                      cells: [
                                        DataCell(
                                          SizedBox(
                                            width: _idColumnWidth,
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    u.id.length > 10
                                                        ? '${u.id.substring(0, 10)}…'
                                                        : u.id,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: 'Copiar ID',
                                                  icon: const Icon(
                                                    Icons.copy,
                                                    size: 16,
                                                  ),
                                                  onPressed: () =>
                                                      _copyUserId(u),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: _nameColumnWidth,
                                            child: Text(
                                              u.name ?? '-',
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: _emailColumnWidth,
                                            child: Text(
                                              u.email ?? '-',
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: _phoneColumnWidth,
                                            child: Text(
                                              u.phone ?? '-',
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: _bairroColumnWidth,
                                            child: Text(
                                              u.bairro ?? '-',
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Transform.scale(
                                            scale: 0.8,
                                            child: Switch(
                                              value: u.isSeller,
                                              onChanged: (_) =>
                                                  _toggleSeller(u),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Transform.scale(
                                            scale: 0.8,
                                            child: Switch(
                                              value: u.verified,
                                              onChanged: (_) =>
                                                  _toggleVerified(u),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Align(
                                            alignment:
                                                Alignment.centerRight,
                                            child: PopupMenuButton<_UserAction>(
                                              tooltip: 'Mais ações',
                                              icon: const Icon(Icons.more_vert),
                                              onSelected: (action) {
                                                switch (action) {
                                                  case _UserAction.edit:
                                                    _updateProfile(u);
                                                    break;
                                                  case _UserAction.delete:
                                                    _deleteProfile(u);
                                                    break;
                                                  case _UserAction.toggleBan:
                                                    _toggleBanned(u);
                                                    break;
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                  value: _UserAction.edit,
                                                  child: Text('Editar'),
                                                ),
                                                const PopupMenuItem(
                                                  value: _UserAction.delete,
                                                  child: Text('Eliminar'),
                                                ),
                                                PopupMenuItem(
                                                  value: _UserAction.toggleBan,
                                                  child: Text(
                                                    u.banned
                                                        ? 'Desbanir'
                                                        : 'Banir',
                                                  ),
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

                      // Mobile / narrow: lista de cartões, sem scroll horizontal
                      return ListView.builder(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final u = filtered[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 0,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    u.name ?? 'Sem nome',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ID: ${u.id}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color
                                              ?.withOpacity(0.7),
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(u.email ?? '-'),
                                  Text('Telefone: ${u.phone ?? '-'}'),
                                  Text('Bairro: ${u.bairro ?? '-'}'),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildCompactStatusSwitch(
                                        context,
                                        'Vend.',
                                        u.isSeller,
                                        () => _toggleSeller(u),
                                      ),
                                      _buildCompactStatusSwitch(
                                        context,
                                        'Verif.',
                                        u.verified,
                                        () => _toggleVerified(u),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        tooltip: 'Copiar ID',
                                        icon: const Icon(Icons.copy, size: 20),
                                        onPressed: () => _copyUserId(u),
                                      ),
                                      IconButton(
                                        tooltip: 'Editar',
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () => _updateProfile(u),
                                      ),
                                      IconButton(
                                        tooltip: 'Eliminar',
                                        icon: Icon(
                                          Icons.delete_outline,
                                          size: 20,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                        ),
                                        onPressed: () => _deleteProfile(u),
                                      ),
                                    ],
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

class _AdminUser {
  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final String? bairro;
  final bool verified;
  final bool isSeller;
  final bool isAdmin;
  final bool banned;
  final String? profileImageUrl;
  final String? storeName;
  final String? storeDescription;
  final String? storeBanner;

  _AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.bairro,
    required this.verified,
    required this.isSeller,
    required this.isAdmin,
    required this.banned,
    required this.profileImageUrl,
    required this.storeName,
    required this.storeDescription,
    required this.storeBanner,
  });

  factory _AdminUser.fromMap(
      Map<String, dynamic> map, Set<String> adminUserIds) {
    return _AdminUser(
      id: map['id'] as String,
      name: map['name'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      bairro: map['bairro'] as String?,
      verified: (map['verified'] as bool?) ?? false,
      isSeller: (map['is_seller'] as bool?) ?? false,
      isAdmin: adminUserIds.contains(map['id']),
      banned: (map['banned'] as bool?) ?? false,
      profileImageUrl: map['profile_image_url'] as String?,
      storeName: map['store_name'] as String?,
      storeDescription: map['store_description'] as String?,
      storeBanner: map['store_banner'] as String?,
    );
  }
}
