import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math';
import '../../services/auth_service.dart';
import '../../services/seller_product_service.dart';
import '../../services/image_upload_service.dart';
import 'seller_products_screen.dart';
import 'seller_orders_screen.dart';
import 'seller_finance_screen.dart';

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({super.key});

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> {
  Future<void> _refresh() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final sellerId = AuthService.currentUser.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do Vendedor'),
        elevation: 0,
      ),
      body: FutureBuilder(
        future: Future.wait([
          SellerProductService.bySeller(sellerId),
          SellerProductService.getOrdersBySeller(sellerId),
          SellerProductService.getFinanceSummary(sellerId),
        ]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = snapshot.data![0] as List;
          final orders = snapshot.data![1] as List;
          final finance = snapshot.data![2];

          return RefreshIndicator(
            onRefresh: _refresh,
            child: _buildContent(products, orders, finance),
          );
        },
      ),
    );
  }

  Widget _buildContent(List products, List orders, dynamic finance) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
            // Card de Boas-vindas / Informações da Loja (Editável)
            GestureDetector(
              onTap: () {
                _showEditStoreDialog();
              },
              child: Card(
                color: Colors.deepPurple,
                child: Stack(
                  children: [
                    // Banner de fundo (se existir)
                    if (AuthService.currentUser.storeBanner != null)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Opacity(
                            opacity: 0.3,
                            child: AuthService.currentUser.storeBanner!.startsWith('http')
                                ? Image.network(
                                    AuthService.currentUser.storeBanner!,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: Colors.deepPurple,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                : null,
                                            color: Colors.white,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(color: Colors.deepPurple);
                                    },
                                  )
                                : AuthService.currentUser.storeBanner!.startsWith('assets/')
                                    ? Image.asset(
                                        AuthService.currentUser.storeBanner!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(color: Colors.deepPurple);
                                        },
                                      )
                                    : Image.file(
                                        File(AuthService.currentUser.storeBanner!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(color: Colors.deepPurple);
                                        },
                                      ),
                          ),
                        ),
                      ),
                    
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  AuthService.currentUser.storeName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AuthService.currentUser.storeDescription,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Cards de Estatísticas
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Produtos',
                    products.length.toString(),
                    Icons.inventory_2,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Pedidos',
                    orders.length.toString(),
                    Icons.shopping_bag,
                    Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Entregues',
                    finance.deliveredOrders.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Saldo',
                    '${finance.availableBalance.toStringAsFixed(0)} MT',
                    Icons.account_balance_wallet,
                    Colors.purple,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Receita Total
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resumo Financeiro',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFinanceRow(
                      'Vendas Totais',
                      '${finance.totalSales.toStringAsFixed(2)} MT',
                      Colors.green,
                    ),
                    const SizedBox(height: 8),
                    _buildFinanceRow(
                      'Comissões',
                      '-${finance.totalCommission.toStringAsFixed(2)} MT',
                      Colors.red,
                    ),
                    const Divider(height: 24),
                    _buildFinanceRow(
                      'Receita Líquida',
                      '${finance.netRevenue.toStringAsFixed(2)} MT',
                      Colors.deepPurple,
                      bold: true,
                    ),
                    if (finance.pendingBalance > 0) ...[
                      const SizedBox(height: 8),
                      _buildFinanceRow(
                        'Pendente',
                        '${finance.pendingBalance.toStringAsFixed(2)} MT',
                        Colors.orange,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Acesso Rápido',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Menu de Acesso Rápido
            _buildMenuCard(
              icon: Icons.inventory,
              title: 'Meus Produtos',
              subtitle: '${products.length} produtos cadastrados',
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SellerProductsScreen(),
                  ),
                ).then((_) => setState(() {}));
              },
            ),

            _buildMenuCard(
              icon: Icons.receipt_long,
              title: 'Pedidos',
              subtitle: '${orders.where((o) => o.status.index < 3).length} pedidos ativos',
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SellerOrdersScreen(),
                  ),
                ).then((_) => setState(() {}));
              },
            ),

            _buildMenuCard(
              icon: Icons.account_balance_wallet,
              title: 'Finanças',
              subtitle: 'Saldo: ${finance.availableBalance.toStringAsFixed(2)} MT',
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SellerFinanceScreen(),
                  ),
                ).then((_) => setState(() {}));
              },
            ),
          ],
        );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceRow(String label, String value, Color color, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  void _showEditStoreDialog() {
    final storeNameController = TextEditingController(text: AuthService.currentUser.storeName);
    final storeDescController = TextEditingController(text: AuthService.currentUser.storeDescription);
    String? currentBanner = AuthService.currentUser.storeBanner;

    // Lista de imagens mockadas para fallback
    final mockImages = [
      'assets/images/mock1.jpg',
      'assets/images/mock2.jpg',
      'assets/images/mock3.jpg',
      'assets/images/mock4.jpg',
      'assets/images/mock5.jpg',
      'assets/images/mock6.jpg',
      'assets/images/mock7.jpg',
      'assets/images/mock8.jpg',
      'assets/images/mock9.jpg',
      'assets/images/mock10.jpg',
    ];

    Future<void> pickBannerImage(StateSetter setDialogState) async {
      try {
        // Mostra opções: Câmera ou Galeria
        final ImageSource? source = await showModalBottomSheet<ImageSource>(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (BuildContext context) {
            return SafeArea(
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library, color: Colors.deepPurple),
                    title: const Text('Galeria'),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_camera, color: Colors.deepPurple),
                    title: const Text('Câmera'),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.close, color: Colors.grey),
                    title: const Text('Cancelar'),
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          },
        );

        if (source == null) return;

        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (image != null) {
          setDialogState(() {
            currentBanner = image.path;
          });
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Banner selecionado - pronto para upload'),
                duration: Duration(milliseconds: 800),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        // Fallback para imagem mockada
        final random = Random();
        setDialogState(() {
          currentBanner = mockImages[random.nextInt(mockImages.length)];
        });
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Banner mockado adicionado (para desenvolvimento)'),
              duration: Duration(milliseconds: 800),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isAssetImage = currentBanner?.startsWith('assets/') ?? false;
          
          return AlertDialog(
            title: const Text('Editar Loja'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Banner Preview e Seleção
                  if (currentBanner != null)
                    SizedBox(
                      width: MediaQuery.of(context).size.width - 80,
                      height: 120,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: currentBanner!.startsWith('http')
                            ? Image.network(
                                currentBanner!,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey[300],
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.image_not_supported, size: 50),
                                  );
                                },
                              )
                            : isAssetImage
                                ? Image.asset(
                                    currentBanner!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.image_not_supported, size: 50),
                                      );
                                    },
                                  )
                                : Image.file(
                                    File(currentBanner!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.image_not_supported, size: 50),
                                      );
                                    },
                                  ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => pickBannerImage(setDialogState),
                    icon: const Icon(Icons.add_photo_alternate),
                    label: Text(currentBanner == null ? 'Adicionar Banner' : 'Alterar Banner'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: storeNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome da Loja',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: storeDescController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Mostrar loading
                  final navigator = Navigator.of(context);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  
                  // Upload do banner se foi alterado
                  String? uploadedBannerUrl = currentBanner;
                  if (currentBanner != null && 
                      !currentBanner!.startsWith('http') && 
                      !currentBanner!.startsWith('assets/')) {
                    try {
                      uploadedBannerUrl = await ImageUploadService.uploadStoreBanner(currentBanner!);
                    } catch (e) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text('Erro ao fazer upload do banner: $e')),
                      );
                      return;
                    }
                  }
                  
                  // Atualizar informações da loja no Supabase
                  final success = await AuthService.updateStoreInfo(
                    storeName: storeNameController.text.trim(),
                    storeDescription: storeDescController.text.trim(),
                    storeBanner: uploadedBannerUrl,
                  );
                  
                  if (success) {
                    // Atualizar produtos do vendedor com o novo nome da loja
                    await SellerProductService.updateSellerStoreName(
                      AuthService.currentUser.id,
                      storeNameController.text.trim(),
                    );

                    navigator.pop();
                    setState(() {});
                    
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Loja atualizada com sucesso!')),
                    );
                  } else {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Erro ao atualizar loja. Tente novamente.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
