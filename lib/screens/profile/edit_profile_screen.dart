import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/image_upload_service.dart';
import '../../routes.dart';
import '../../widgets/image_picker_widget.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late String _selectedBairro;
  List<String> _profileImages = [];
  
  bool isCreatingAccount = false;
  String? email;
  String? password;
  String? phone;
  String? registrationType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _selectedBairro = 'Piloto';
  }

  // Lista completa de bairros de Nampula
  final List<String> _bairrosDisponiveis = const [
    'Piloto',
    'Muhala',
    'Muatala',
    'Namutequeliua',
    'Napipine',
    'Central',
    'Natikiri',
    'Namicopo',
    'Mutauanha',
    'Maratane',
    'Anchilo',
    'Namicunde',
    'Namаприкano',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Pega os argumentos da navegação
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    if (args != null) {
      isCreatingAccount = args['isCreatingAccount'] ?? false;
      email = args['email'];
      password = args['password'];
      phone = args['phone'];
      registrationType = args['registrationType'];
      
      // Se está criando conta com email, preenche o email
      if (isCreatingAccount && email != null) {
        _emailController.text = email!;
      }
      
      // Se está criando conta com telefone, preenche o telefone
      if (isCreatingAccount && phone != null) {
        _phoneController.text = phone!;
      }
    } else {
      // Modo edição - carrega dados do usuário atual
      final user = AuthService.currentUser;
      _nameController.text = user.name;
      _phoneController.text = user.phone;
      _emailController.text = user.email;
      // Garante que o bairro seja válido
      if (_bairrosDisponiveis.contains(user.bairro)) {
        _selectedBairro = user.bairro;
      } else {
        _selectedBairro = 'Piloto'; // Fallback para valor válido
      }
      // Carrega foto de perfil existente
      if (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty) {
        _profileImages = [user.profileImageUrl!];
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      // Upload da foto de perfil se foi selecionada
      String? uploadedProfileImageUrl;
      if (_profileImages.isNotEmpty) {
        final profileImage = _profileImages.first;
        if (!profileImage.startsWith('http') && !profileImage.startsWith('assets/')) {
          try {
            uploadedProfileImageUrl = await ImageUploadService.uploadProfileImage(profileImage);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erro ao fazer upload da foto: $e')),
              );
            }
            return;
          }
        } else {
          uploadedProfileImageUrl = profileImage;
        }
      }

      // Se está criando conta, precisa validar nome e telefone
      if (isCreatingAccount) {
        if (_nameController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor, insira seu nome'),
            ),
          );
          return;
        }

        if (_phoneController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor, insira seu número de telefone'),
            ),
          );
          return;
        }

        // Criar conta com Supabase
        final success = await AuthService.createUserWithEmail(
          email: email!,
          password: password!,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          bairro: _selectedBairro,
        );
        
        if (success && mounted) {
          // Atualizar foto de perfil se foi feito upload
          if (uploadedProfileImageUrl != null) {
            AuthService.currentUser.profileImageUrl = uploadedProfileImageUrl;
          }
          
          Navigator.pushNamedAndRemoveUntil(
            context,
            Routes.home,
            (route) => false,
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conta criada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao criar conta. Tente novamente.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Editar perfil existente
        final success = await AuthService.updateProfile(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          bairro: _selectedBairro,
          profileImageUrl: uploadedProfileImageUrl,
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Perfil atualizado com sucesso!'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pop(context);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao atualizar perfil. Tente novamente.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isCreatingAccount ? 'Criar Conta' : 'Editar Perfil',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 👤 AVATAR com picker de imagem
              ImagePickerWidget(
                selectedImages: _profileImages,
                maxImages: 1,
                isCircular: true,
                size: 100,
                onImagesChanged: (images) {
                  setState(() {
                    _profileImages = images;
                  });
                },
              ),

              const SizedBox(height: 32),

              // 📝 NOME COMPLETO
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome completo',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, insira seu nome';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // � EMAIL (se veio da criação com email ou modo edição)
              if (isCreatingAccount && registrationType == 'email' || !isCreatingAccount)
                Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      enabled: false, // Nunca editável
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.grey[200],
                      ),
                      validator: (value) {
                        if (isCreatingAccount && registrationType == 'email') {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, insira seu email';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

              // 📞 TELEFONE
              TextFormField(
                controller: _phoneController,
                enabled: isCreatingAccount && registrationType == 'email', // Só editável se veio de email
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Número de telefone',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: const OutlineInputBorder(),
                  filled: isCreatingAccount && registrationType == 'phone',
                  fillColor: Colors.grey[200],
                ),
                validator: (value) {
                  if (isCreatingAccount && registrationType == 'email') {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, insira seu telefone';
                    }
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 🌍 PROVÍNCIA (fixo)
              DropdownButtonFormField<String>(
                value: 'Nampula',
                decoration: const InputDecoration(
                  labelText: 'Província',
                  prefixIcon: Icon(Icons.location_city_outlined),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Nampula', child: Text('Nampula')),
                ],
                onChanged: null,
              ),

              const SizedBox(height: 16),

              // 🏘️ BAIRRO
              DropdownButtonFormField<String>(
                value: _selectedBairro,
                decoration: const InputDecoration(
                  labelText: 'Bairro',
                  prefixIcon: Icon(Icons.home_outlined),
                  border: OutlineInputBorder(),
                ),
                items: _bairrosDisponiveis.map((bairro) {
                  return DropdownMenuItem(
                    value: bairro,
                    child: Text(bairro),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedBairro = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 32),

              // BOTAO SALVAR / CRIAR PERFIL
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isCreatingAccount ? 'Criar perfil' : 'Salvar alterações',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // BOTAO ALTERAR SENHA (so aparece em modo edicao)
              if (!isCreatingAccount) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      // TODO: Implementar alteração de senha
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Funcionalidade em desenvolvimento'),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Alterar palavra-passe',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
