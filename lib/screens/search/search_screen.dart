import 'package:flutter/material.dart';
import '../../data/mock_products.dart';
import '../../widgets/product_card.dart';

class SearchScreen extends StatefulWidget {
  final String searchQuery;
  const SearchScreen({super.key, this.searchQuery = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late TextEditingController _searchController;
  String _currentQuery = '';
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
    _currentQuery = widget.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    setState(() {
      _currentQuery = query;
      _showResults = query.isNotEmpty;
    });
  }

  Future<void> _refreshSearch() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {});
  }

  List<String> _getSuggestions() {
    if (_currentQuery.isEmpty) return [];

    final suggestions = mockProducts
        .where(
          (p) => p.name.toLowerCase().contains(_currentQuery.toLowerCase()),
        )
        .map((p) => p.name)
        .toSet()
        .take(8)
        .toList();

    return suggestions;
  }

  /// 🔥 Gera textos recomendados (nomes de produtos em texto)
  List<String> _getRecommendedTexts() {
    return mockProducts.map((e) => e.name).toSet().take(7).toList();
  }

  /// 🔥 Produtos recomendados visualmente
  List<dynamic> _getRecommendedProducts() {
    final products = mockProducts.toList()..shuffle();
    return products.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _getSuggestions();
    final results = mockProducts.where((product) {
      return product.name.toLowerCase().contains(_currentQuery.toLowerCase());
    }).toList();

    final recommendedTexts = _getRecommendedTexts();
    final recommendedProducts = _getRecommendedProducts();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(
                Icons.search,
                color: Colors.grey[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Procure produtos baratos...',
                    hintStyle: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _currentQuery = value;
                      _showResults = false;
                    });
                  },
                  onSubmitted: (value) {
                    _performSearch(value);
                  },
                ),
              ),
              if (_currentQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _currentQuery = '';
                      _showResults = false;
                    });
                  },
                  child: Icon(
                    Icons.close,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
      body: _currentQuery.isEmpty
          ? _buildRecommendedBlock(recommendedTexts, recommendedProducts)
          : _showResults
              ? _buildResults(results)
              : _buildSuggestions(suggestions),
    );
  }

  /// 🔥 BLOCO COMPLETO DE RECOMENDAÇÕES
  Widget _buildRecommendedBlock(List<String> texts, List<dynamic> products) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '  Pesquisas populares',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // 🟣 Lista de 7 textos recomendados
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: texts
                .map(
                  (t) => GestureDetector(
                    onTap: () {
                      _searchController.text = t;
                      _performSearch(t);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          color: Colors.deepPurple.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: 22),

          const Text(
            '  Recomendados para você',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.65,
            ),
            itemBuilder: (_, index) {
              return ProductCard(
                key: ValueKey('recommended_${products[index].id}'),
                product: products[index],
              );
            },
          ),
        ],
      ),
    );
  }

  /// 🟡 sugestões ao digitar
  Widget _buildSuggestions(List<String> suggestions) {
    if (suggestions.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma sugestão encontrada',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (_, index) {
        final suggestion = suggestions[index];
        return ListTile(
          leading: const Icon(Icons.search, color: Colors.grey),
          title: Text(suggestion),
          onTap: () {
            _searchController.text = suggestion;
            _performSearch(suggestion);
          },
        );
      },
    );
  }

  /// 🟢 resultados finais
  Widget _buildResults(List<dynamic> results) {
    if (results.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum produto encontrado',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshSearch,
      child: GridView.builder(
        padding: const EdgeInsets.all(14),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.65,
        ),
        itemCount: results.length,
        itemBuilder: (_, index) {
          return ProductCard(
            key: ValueKey('search_result_${results[index].id}'),
            product: results[index],
          );
        },
      ),
    );
  }
}
