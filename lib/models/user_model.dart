class UserModel {
  final String id;
  String name;
  String email;
  String phone;
  String bairro;
  bool isSeller; // se já é vendedor
  bool verified; // se foi aprovado pela plataforma
  String? profileImageUrl; // URL da foto de perfil
  
  // Dados da loja (para vendedores)
  String storeName; // Nome da loja (editável)
  String storeDescription; // Descrição da loja (editável)
  String? storeBanner; // Caminho da imagem de banner da loja

  UserModel({
    required this.id,
    required this.name,
    this.email = '',
    required this.phone,
    required this.bairro,
    this.isSeller = false,
    this.verified = false,
    this.profileImageUrl,
    String? storeName,
    String? storeDescription,
    this.storeBanner,
  })  : storeName = storeName ?? name,
        storeDescription = storeDescription ?? 'Bem-vindo à nossa loja!';
}
