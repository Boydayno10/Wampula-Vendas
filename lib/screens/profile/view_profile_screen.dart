import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../models/client_publicacao_model.dart';
import '../../services/client_publicacao_service.dart';
import '../../services/seller_product_service.dart';
import '../../services/auth_service.dart';
import '../product/product_detail_screen.dart';
import '../client/nova_publicacao_screen.dart';
import 'edit_profile_screen.dart';

class ViewProfileScreen extends StatelessWidget {
  final UserModel user;

  const ViewProfileScreen({super.key, required this.user});

  Future<void> _openPublicationDetail(
    BuildContext context,
    ClientPublicacaoModel pub,
  ) async {
    try {
      final sellerProduct = await SellerProductService.getById(pub.id);
      if (sellerProduct == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível abrir esta publicação.'),
            ),
          );
        }
        return;
      }

      final product = sellerProduct.toProductModel();

      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir publicação: $e')),
        );
      }
    }
  }

  Widget _buildHeader(BuildContext context, UserModel displayUser) {
    final hasImage = displayUser.profileImageUrl != null &&
        displayUser.profileImageUrl!.startsWith('http');
    final String formattedPhone = displayUser.phone.startsWith('+258')
      ? displayUser.phone
      : '+258 ${displayUser.phone}';
    final String formattedBairro = displayUser.bairro
        .startsWith('Cidade de Nampula')
      ? displayUser.bairro
      : 'Cidade de Nampula, ${displayUser.bairro}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.deepPurple.shade50,
          backgroundImage:
              hasImage ? NetworkImage(displayUser.profileImageUrl!) : null,
          child: !hasImage
              ? const Icon(
                  Icons.person,
                  size: 40,
                  color: Colors.deepPurple,
                )
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          displayUser.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (user.email.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            displayUser.email,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Contacto',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedPhone,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              width: 1,
              height: 32,
              color: Colors.grey.shade300,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bairro',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedBairro,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPublicationTile(
    BuildContext context,
    ClientPublicacaoModel pub,
    bool isOwner,
  ) {
    final imageUrl = pub.images.isNotEmpty
        ? pub.images.first
        : 'assets/images/default.png';
    final isNetwork = imageUrl.startsWith('http');
    return GestureDetector(
      onTap: () {
        if (isOwner) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NovaPublicacaoScreen(publicacao: pub),
            ),
          );
        } else {
          _openPublicationDetail(context, pub);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: isNetwork
                    ? Image.network(
                        imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Image.asset(
                        imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pub.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pub.promoPrice != null
                        ? 'MT ${pub.promoPrice!.toStringAsFixed(2)}'
                        : 'MT ${pub.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isCurrentUser = AuthService.currentUser.id == user.id;

    Widget buildScaffold(UserModel displayUser) {
      final bool isOwner = displayUser.id == AuthService.currentUser.id;

      return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(isOwner ? 'Meu perfil' : 'Perfil do negociante'),
        actions: [
          if (isOwner)
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EditProfileScreen(),
                  ),
                );
              },
              child: const Text(
                'Editar',
                style: TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _buildHeader(context, displayUser)),
              const SizedBox(height: 16),
              Divider(color: Colors.grey.shade300),
              const SizedBox(height: 8),
              const Text(
                'Publicações ativas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<ClientPublicacaoModel>>(
                future:
                  ClientPublicacaoService.getPublicationsForUser(displayUser.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'Erro ao carregar publicações: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final pubs = snapshot.data ?? [];

                  if (pubs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'Este negociante ainda não tem publicações ativas.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: pubs.length,
                    itemBuilder: (context, index) {
                      final pub = pubs[index];
                      return _buildPublicationTile(
                        context,
                        pub,
                        isOwner,
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
      );
    }

    if (isCurrentUser) {
      return ValueListenableBuilder<UserModel>(
        valueListenable: AuthService.currentUserNotifier,
        builder: (context, currentUser, _) {
          return buildScaffold(currentUser);
        },
      );
    }

    return buildScaffold(user);
  }
}
