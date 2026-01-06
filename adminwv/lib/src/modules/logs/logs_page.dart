import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loadingSearch = true;
  bool _loadingTouches = true;
  String? _error;
  List<Map<String, dynamic>> _searchLogs = const [];
  List<Map<String, dynamic>> _touches = const [];
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSearchLogs();
    _loadTouches();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _deleteSearchLog(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar busca'),
        content: const Text(
          'Tem certeza que deseja apagar este registro de busca?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final supabase = Supabase.instance.client;

    try {
      await supabase.from('search_logs').delete().eq('id', id);
      setState(() {
        _searchLogs = _searchLogs.where((l) => l['id'] != id).toList();
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao apagar search_log: $e';
      });
    }
  }

  Future<void> _deleteTouch(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar toque em publicação'),
        content: const Text(
          'Tem certeza que deseja apagar este registro de toque em publicação?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final supabase = Supabase.instance.client;

    try {
      await supabase.from('publication_touches').delete().eq('id', id);
      setState(() {
        _touches = _touches.where((t) => t['id'] != id).toList();
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao apagar publication_touch: $e';
      });
    }
  }

  Future<void> _loadSearchLogs() async {
    setState(() {
      _loadingSearch = true;
      _error = null;
    });

    final supabase = Supabase.instance.client;
    try {
      final data = await supabase
          .from('search_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(200);
      setState(() {
        _searchLogs = (data as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _loadingSearch = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar search_logs: $e';
        _loadingSearch = false;
      });
    }
  }

  Future<void> _loadTouches() async {
    setState(() {
      _loadingTouches = true;
    });

    final supabase = Supabase.instance.client;
    try {
      final data = await supabase
          .from('publication_touches')
          .select()
          .order('created_at', ascending: false)
          .limit(200);
      setState(() {
        _touches = (data as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _loadingTouches = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar publication_touches: $e';
        _loadingTouches = false;
      });
    }
  }

  Future<void> _resetAllLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar logs'),
        content: const Text(
          'Tem certeza que deseja apagar todos os registros de buscas e toques em publicações? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar tudo'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final supabase = Supabase.instance.client;

    setState(() {
      _loadingSearch = true;
      _loadingTouches = true;
      _error = null;
    });

    try {
      // Apaga todos usando filtros por ID (respeita as mesmas policies
      // que já permitem apagar um por um)
      final searchIds = _searchLogs
          .map((e) => e['id'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      if (searchIds.isNotEmpty) {
        await supabase
            .from('search_logs')
            .delete()
            .inFilter('id', searchIds);
      }

      final touchIds = _touches
          .map((e) => e['id'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      if (touchIds.isNotEmpty) {
        await supabase
            .from('publication_touches')
            .delete()
            .inFilter('id', touchIds);
      }

      await _loadSearchLogs();
      await _loadTouches();
    } catch (e) {
      setState(() {
        _error = 'Erro ao limpar logs: $e';
        _loadingSearch = false;
        _loadingTouches = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchesCount = _searchLogs.length;
    final touchesCount = _touches.length;
    final query = _searchText.toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Chip(label: Text('Buscas registradas: $searchesCount')),
            Chip(label: Text('Toques em publicações: $touchesCount')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Filtrar por termo, usuário ou publicação',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchText = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed:
                  (_loadingSearch || _loadingTouches) ? null : _resetAllLogs,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Resetar logs'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Search logs'),
            Tab(text: 'Publication touches'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSearchLogsTable(query),
              _buildTouchesTable(query),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchLogsTable(String query) {
    if (_loadingSearch) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    final filtered = query.isEmpty
        ? _searchLogs
        : _searchLogs.where((l) {
            final term = (l['search_term'] as String? ?? '').toLowerCase();
            final user = (l['user_id'] as String? ?? '').toLowerCase();
            return term.contains(query) || user.contains(query);
          }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('Nenhum search_log encontrado.'));
    }

    return RefreshIndicator(
      onRefresh: _loadSearchLogs,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          DataTable(
            columnSpacing: 16,
            columns: const [
              DataColumn(label: Text('Usuário')),
              DataColumn(label: Text('Termo')),
              DataColumn(label: Text('Resultados')),
              DataColumn(label: Text('Criado em')),
              DataColumn(label: Text('Ações')),
            ],
            rows: filtered
                .map(
                  (l) => DataRow(
                    cells: [
                      DataCell(Text(
                          (l['user_id'] as String?)?.substring(0, 8) ??
                              '-')),
                      DataCell(
                        SizedBox(
                          width: 200,
                          child: Text(
                            l['search_term'] as String,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(
                          (l['results_count'] as int?)?.toString() ?? '0')),
                      DataCell(Text((l['created_at'] as String?) ?? '-')),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Apagar registro',
                          onPressed: () {
                            final id = l['id'] as String?;
                            if (id != null) {
                              _deleteSearchLog(id);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTouchesTable(String query) {
    if (_loadingTouches) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    final filtered = query.isEmpty
        ? _touches
        : _touches.where((t) {
            final pub = (t['publication_id'] as String? ?? '').toLowerCase();
            final user = (t['user_id'] as String? ?? '').toLowerCase();
            final owner = (t['owner_id'] as String? ?? '').toLowerCase();
            return pub.contains(query) ||
                user.contains(query) ||
                owner.contains(query);
          }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('Nenhum registro de toque.'));
    }

    return RefreshIndicator(
      onRefresh: _loadTouches,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          DataTable(
            columnSpacing: 16,
            columns: const [
              DataColumn(label: Text('Publicação')),
              DataColumn(label: Text('Usuário')),
              DataColumn(label: Text('Dono')),
              DataColumn(label: Text('Criado em')),
              DataColumn(label: Text('Ações')),
            ],
            rows: filtered
                .map(
                  (t) => DataRow(
                    cells: [
                      DataCell(Text(
                          (t['publication_id'] as String).substring(0, 8))),
                      DataCell(Text(
                          (t['user_id'] as String).substring(0, 8))),
                      DataCell(Text(
                          (t['owner_id'] as String).substring(0, 8))),
                      DataCell(Text((t['created_at'] as String?) ?? '-')),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Apagar registro',
                          onPressed: () {
                            final id = t['id'] as String?;
                            if (id != null) {
                              _deleteTouch(id);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

