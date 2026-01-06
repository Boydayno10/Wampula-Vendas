import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loadingBalances = true;
  bool _loadingTransactions = true;
  String? _error;
  List<Map<String, dynamic>> _balances = const [];
  List<Map<String, dynamic>> _transactions = const [];
  String _searchSeller = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBalances();
    _loadTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBalances() async {
    setState(() {
      _loadingBalances = true;
      _error = null;
    });

    final supabase = Supabase.instance.client;

    try {
      final data = await supabase.from('seller_balances').select();
      setState(() {
        _balances = (data as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _loadingBalances = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar saldos: $e';
        _loadingBalances = false;
      });
    }
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _loadingTransactions = true;
    });

    final supabase = Supabase.instance.client;

    try {
      final data = await supabase
          .from('seller_transactions')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _transactions = (data as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _loadingTransactions = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar transações: $e';
        _loadingTransactions = false;
      });
    }
  }

  Future<void> _resetFinances() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resetar finanças'),
        content: const Text(
          'Tem certeza que deseja resetar todas as finanças?\n\n'
          'Esta ação irá apagar TODOS os saldos e histórico de transações '
          'de todos os vendedores e não poderá ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Resetar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _loadingBalances = true;
      _loadingTransactions = true;
      _error = null;
    });

    final supabase = Supabase.instance.client;

    try {
      // Supabase exige cláusula WHERE para DELETE.
      // Usamos filtros de data que atingem todas as linhas existentes.

      // Apagar histórico de transações primeiro
      await supabase
        .from('seller_transactions')
        .delete()
        .gt('created_at', '1970-01-01');

      // Depois apagar saldos
      await supabase
        .from('seller_balances')
        .delete()
        .gt('updated_at', '1970-01-01');

      setState(() {
        _balances = const [];
        _transactions = const [];
        _loadingBalances = false;
        _loadingTransactions = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Finanças resetadas com sucesso.'),
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Erro ao resetar finanças: $e';
        _loadingBalances = false;
        _loadingTransactions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalAvailable = _balances
        .map((b) => (b['available_balance'] as num?)?.toDouble() ?? 0)
        .fold<double>(0, (a, b) => a + b);
    final totalPending = _balances
        .map((b) => (b['pending_balance'] as num?)?.toDouble() ?? 0)
        .fold<double>(0, (a, b) => a + b);
    final totalEarnings = _balances
        .map((b) => (b['total_earnings'] as num?)?.toDouble() ?? 0)
        .fold<double>(0, (a, b) => a + b);
    final totalWithdrawn = _balances
        .map((b) => (b['total_withdrawn'] as num?)?.toDouble() ?? 0)
        .fold<double>(0, (a, b) => a + b);

    final query = _searchSeller.toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Chip(label: Text('Disponível: ${totalAvailable.toStringAsFixed(2)}')),
            Chip(label: Text('Pendente: ${totalPending.toStringAsFixed(2)}')),
            Chip(label: Text('Total ganhos: ${totalEarnings.toStringAsFixed(2)}')),
            Chip(label: Text('Total sacado: ${totalWithdrawn.toStringAsFixed(2)}')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Filtrar por ID de vendedor (prefixo)',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchSeller = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Recarregar',
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _loadBalances();
                _loadTransactions();
              },
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _resetFinances,
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Resetar finanças'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Saldos'),
            Tab(text: 'Transações'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildBalancesTable(query),
              _buildTransactionsTable(query),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBalancesTable(String sellerFilter) {
    if (_loadingBalances) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_balances.isEmpty) {
      return const Center(child: Text('Nenhum saldo encontrado.'));
    }

    final filtered = sellerFilter.isEmpty
        ? _balances
        : _balances
            .where((b) => (b['seller_id'] as String)
                .toLowerCase()
                .startsWith(sellerFilter.toLowerCase()))
            .toList();

    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadBalances,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            Center(child: Text('Nenhum saldo encontrado com o filtro.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBalances,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          DataTable(
            columnSpacing: 16,
            columns: const [
              DataColumn(label: Text('Vendedor')),
              DataColumn(label: Text('Disponível')),
              DataColumn(label: Text('Pendente')),
              DataColumn(label: Text('Ganhos')),
              DataColumn(label: Text('Sacado')),
            ],
            rows: filtered
                .map(
                  (b) => DataRow(
                    cells: [
                      DataCell(Text(
                          (b['seller_id'] as String).substring(0, 8))),
                      DataCell(Text(
                          ((b['available_balance'] as num?) ?? 0)
                              .toStringAsFixed(2))),
                      DataCell(Text(
                          ((b['pending_balance'] as num?) ?? 0)
                              .toStringAsFixed(2))),
                      DataCell(Text(
                          ((b['total_earnings'] as num?) ?? 0)
                              .toStringAsFixed(2))),
                      DataCell(Text(
                          ((b['total_withdrawn'] as num?) ?? 0)
                              .toStringAsFixed(2))),
                    ],
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTable(String sellerFilter) {
    if (_loadingTransactions) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_transactions.isEmpty) {
      return const Center(child: Text('Nenhuma transação encontrada.'));
    }

    final filtered = sellerFilter.isEmpty
        ? _transactions
        : _transactions
            .where((t) => (t['seller_id'] as String)
                .toLowerCase()
                .startsWith(sellerFilter.toLowerCase()))
            .toList();

    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadTransactions,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            Center(child: Text('Nenhuma transação encontrada com o filtro.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;

          if (maxWidth > 900) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                DataTable(
                  columnSpacing: 16,
                  columns: const [
                    DataColumn(label: Text('Vendedor')),
                    DataColumn(label: Text('Tipo')),
                    DataColumn(label: Text('Valor')),
                    DataColumn(label: Text('Descrição')),
                    DataColumn(label: Text('Pedido')),
                    DataColumn(label: Text('Data')),
                  ],
                  rows: filtered
                      .map(
                        (t) => DataRow(
                          cells: [
                            DataCell(Text(
                                (t['seller_id'] as String).substring(0, 8))),
                            DataCell(Text(t['type'].toString())),
                            DataCell(Text(
                                ((t['amount'] as num?) ?? 0)
                                    .toStringAsFixed(2))),
                            DataCell(
                              SizedBox(
                                width: 220,
                                child: Text(
                                  t['description'] as String,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(
                                (t['order_id'] as String?) ?? '-')),
                            DataCell(Text(
                                (t['created_at'] as String?) ?? '-')),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final t = filtered[index];
              return Card(
                margin:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vendedor: ${(t['seller_id'] as String).substring(0, 8)}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text('Tipo: ${t['type']}'),
                      Text(
                          'Valor: ${((t['amount'] as num?) ?? 0).toStringAsFixed(2)}'),
                      Text('Pedido: ${t['order_id'] ?? '-'}'),
                      const SizedBox(height: 4),
                      Text(t['description'] as String),
                      const SizedBox(height: 4),
                      Text(
                        (t['created_at'] as String?) ?? '-',
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

