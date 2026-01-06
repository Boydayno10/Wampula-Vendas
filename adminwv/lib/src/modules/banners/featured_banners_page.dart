import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FeaturedBannersPage extends StatefulWidget {
  const FeaturedBannersPage({super.key});

  @override
  State<FeaturedBannersPage> createState() => _FeaturedBannersPageState();
}

class _FeaturedBannersPageState extends State<FeaturedBannersPage> {
  bool _loading = true;
  String? _error;
  List<_BannerRow> _rows = const [];

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
        // Todos os produtos (independente de terem banner_image ou não).
        // Para admin, é permitido forçar qualquer produto no destaque;
        // se não houver banner_image, a Home usará a imagem normal.
        final productsData = await supabase
          .from('products')
          .select('id, name, banner_image');

      // Configurações de destaque (datas, posição, ativo)
      final bannersData = await supabase
          .from('featured_banners')
          .select()
          .order('position', ascending: true);

      final banners = (bannersData as List)
          .map((row) => _FeaturedBanner.fromMap(row as Map<String, dynamic>))
          .toList();

      final bannerByProductId = <String, _FeaturedBanner>{};
      for (final b in banners) {
        bannerByProductId[b.productId] = b;
      }

      final rows = (productsData as List)
          .map((row) {
            final id = (row['id'] ?? '').toString();
            return _BannerRow(
              productId: id,
              productName: (row['name'] ?? '').toString(),
              bannerImage: row['banner_image']?.toString(),
              config: bannerByProductId[id],
            );
          })
          .toList()
        ..sort((a, b) {
          final posA = a.config?.position ?? 999;
          final posB = b.config?.position ?? 999;
          return posA.compareTo(posB);
        });

      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar banners: $e';
        _loading = false;
      });
    }
  }

  Future<void> _editBanner(_BannerRow row) async {
    final existing = row.config;

    final productIdController = TextEditingController(text: row.productId);
    final positionController = TextEditingController(
      text: (existing?.position ?? 1).toString(),
    );

    final now = DateTime.now();
    DateTime? startAt = existing?.startAt ?? now;
    DateTime? endAt = existing?.endAt ?? now.add(const Duration(hours: 1));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            existing == null
                ? 'Configurar destaque'
                : 'Editar destaque',
          ),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (row.productName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          row.productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    TextField(
                      controller: productIdController,
                      decoration: const InputDecoration(
                        labelText: 'ID do produto (products.id)',
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: positionController,
                      decoration: const InputDecoration(
                        labelText: 'Posição (1 a 3)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Início da exibição'),
                      subtitle: Text(
                        startAt != null
                            ? startAt!.toLocal().toString()
                            : 'Selecione data e hora',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final now = DateTime.now();
                        final pickedDate = await showDatePicker(
                          context: context,
                          // Sempre usar a data atual como ponto de partida
                          // para facilitar reconfigurações de horário.
                          initialDate: now,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 5),
                        );
                        if (pickedDate == null) return;
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            now,
                          ),
                        );
                        if (pickedTime == null) return;
                        setStateDialog(() {
                          startAt = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Fim da exibição'),
                      subtitle: Text(
                        endAt != null
                            ? endAt!.toLocal().toString()
                            : 'Selecione data e hora',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        // Hora final sempre começa 1h após a hora atual
                        final now = DateTime.now();
                        final suggestedEnd = now.add(const Duration(hours: 1));
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: suggestedEnd,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 5),
                        );
                        if (pickedDate == null) return;
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            suggestedEnd,
                          ),
                        );
                        if (pickedTime == null) return;
                        setStateDialog(() {
                          endAt = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Zera as datas para deixar o banner "pendente" (sem horário definido)
                startAt = null;
                endAt = null;
                Navigator.pop(context, true);
              },
              child: const Text('Zerar datas'),
            ),
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

    final productId = productIdController.text.trim();
    final position = int.tryParse(positionController.text.trim());

    if (productId.isEmpty || position == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha ID do produto e posição.')),
      );
      return;
    }

    // Validação de datas:
    // - permitido: ambas nulas (banner pendente, não entra no carrossel);
    // - permitido: ambas preenchidas (banner agendado);
    // - inválido: apenas uma preenchida.
    final hasStart = startAt != null;
    final hasEnd = endAt != null;
    if (hasStart != hasEnd) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preencha tanto o início quanto o fim da exibição, ou deixe ambos vazios.',
          ),
        ),
      );
      return;
    }

    final supabase = Supabase.instance.client;

    try {
      if (existing == null) {
        await supabase.from('featured_banners').insert({
          'product_id': productId,
          'position': position,
          'start_at': startAt?.toUtc().toIso8601String(),
          'end_at': endAt?.toUtc().toIso8601String(),
          // Sempre cria/atualiza como ativo; a janela de tempo
          // controla se entra ou não no carrossel da Home.
          'active': true,
        });
      } else {
        await supabase
            .from('featured_banners')
            .update({
              'product_id': productId,
              'position': position,
              'start_at': startAt?.toUtc().toIso8601String(),
              'end_at': endAt?.toUtc().toIso8601String(),
              'active': true,
            })
            .eq('id', existing.id);
      }

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar banner: $e')),
      );
    }
  }

  /// Cria manualmente uma configuração de destaque informando o ID do produto.
  /// Só permite salvar se o produto existir e tiver banner_image configurado.
  Future<void> _createManualBanner() async {
    final productIdController = TextEditingController();
    final positionController = TextEditingController(text: '1');

    final now = DateTime.now();
    DateTime? startAt = now;
    DateTime? endAt = now.add(const Duration(hours: 1));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Adicionar produto ao destaque'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: productIdController,
                      decoration: const InputDecoration(
                        labelText: 'ID do produto (products.id)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: positionController,
                      decoration: const InputDecoration(
                        labelText: 'Posição (1 a 3)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Início da exibição'),
                      subtitle: Text(
                        startAt != null
                            ? startAt!.toLocal().toString()
                            : 'Selecione data e hora',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final now = DateTime.now();
                        final pickedDate = await showDatePicker(
                          context: context,
                          // Sempre começar pela data/hora atual
                          initialDate: now,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 5),
                        );
                        if (pickedDate == null) return;
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            now,
                          ),
                        );
                        if (pickedTime == null) return;
                        setStateDialog(() {
                          startAt = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Fim da exibição'),
                      subtitle: Text(
                        endAt != null
                            ? endAt!.toLocal().toString()
                            : 'Selecione data e hora',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        // Hora final sempre começa 1h após a hora atual
                        final now = DateTime.now();
                        final suggestedEnd = now.add(const Duration(hours: 1));
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: suggestedEnd,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 5),
                        );
                        if (pickedDate == null) return;
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            suggestedEnd,
                          ),
                        );
                        if (pickedTime == null) return;
                        setStateDialog(() {
                          endAt = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Deixa o banner pendente, sem janela de exibição definida
                startAt = null;
                endAt = null;
                Navigator.pop(context, true);
              },
              child: const Text('Zerar datas'),
            ),
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

    final productId = productIdController.text.trim();
    final position = int.tryParse(positionController.text.trim());

    if (productId.isEmpty || position == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha ID do produto e posição.')),
      );
      return;
    }

    // Regras de datas idênticas ao editor:
    // - permitido: ambas nulas (banner pendente);
    // - permitido: ambas preenchidas;
    // - inválido: apenas uma preenchida.
    final hasStart = startAt != null;
    final hasEnd = endAt != null;
    if (hasStart != hasEnd) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preencha tanto o início quanto o fim da exibição, ou deixe ambos vazios.',
          ),
        ),
      );
      return;
    }

    final supabase = Supabase.instance.client;

    try {
        // Verificar apenas se o produto existe; não exigimos banner_image
        // para o admin poder forçar o destaque.
        final product = await supabase
          .from('products')
          .select('id')
          .eq('id', productId)
          .maybeSingle();

      if (product == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produto não encontrado.')),
        );
        return;
      }

      await supabase.from('featured_banners').insert({
        'product_id': productId,
        'position': position,
        'start_at': startAt?.toUtc().toIso8601String(),
        'end_at': endAt?.toUtc().toIso8601String(),
        'active': true,
      });

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar banner: $e')),
      );
    }
  }

  Future<void> _deleteBanner(_FeaturedBanner banner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover banner'),
        content: Text(
          'Tem certeza que deseja remover o banner para o produto "${banner.productId}"?',
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
          .from('featured_banners')
          .delete()
          .eq('id', banner.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao remover banner: $e')),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Banners em destaque',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            FilledButton.icon(
              onPressed: _createManualBanner,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar banner'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Produto')),
                DataColumn(label: Text('Posição')),
                DataColumn(label: Text('Início')),
                DataColumn(label: Text('Fim')),
                DataColumn(label: Text('Ações')),
              ],
              rows: [
                for (final row in _rows)
                  DataRow(
                    cells: [
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              row.productName.isEmpty
                                  ? '(sem nome)'
                                  : row.productName,
                            ),
                            Builder(
                              builder: (context) => Text(
                                row.productId,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Text(row.config?.position.toString() ?? '-'),
                      ),
                      DataCell(
                        Text(
                          row.config == null
                              ? '-'
                              : (row.config!.startAt != null
                                  ? row.config!.startAt!.toLocal().toString()
                                  : '-'),
                        ),
                      ),
                      DataCell(
                        Text(
                          row.config == null
                              ? '-'
                              : (row.config!.endAt != null
                                  ? row.config!.endAt!.toLocal().toString()
                                  : '-'),
                        ),
                      ),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'Editar',
                              onPressed: () => _editBanner(row),
                            ),
                            if (row.config != null)
                              IconButton(
                                icon: const Icon(Icons.delete),
                                tooltip: 'Remover agendamento',
                                onPressed: () => _deleteBanner(row.config!),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeaturedBanner {
  final String id;
  final String productId;
  final int position;
  final DateTime? startAt;
  final DateTime? endAt;

  _FeaturedBanner({
    required this.id,
    required this.productId,
    required this.position,
    required this.startAt,
    required this.endAt,
  });

  factory _FeaturedBanner.fromMap(Map<String, dynamic> map) {
    final startRaw = map['start_at'];
    final endRaw = map['end_at'];
    return _FeaturedBanner(
      id: (map['id'] ?? '').toString(),
      productId: (map['product_id'] ?? '').toString(),
      position: (map['position'] ?? 1) as int,
      startAt:
          startRaw == null || (startRaw is String && startRaw.isEmpty)
              ? null
              : DateTime.parse(startRaw as String),
      endAt:
          endRaw == null || (endRaw is String && endRaw.isEmpty)
              ? null
              : DateTime.parse(endRaw as String),
    );
  }
}

/// Linha da tabela de gestão de banners: agrupa o produto que tem banner
/// com a configuração opcional em featured_banners (datas, posição, etc.).
class _BannerRow {
  final String productId;
  final String productName;
  final String? bannerImage;
  final _FeaturedBanner? config;

  const _BannerRow({
    required this.productId,
    required this.productName,
    required this.bannerImage,
    required this.config,
  });
}
