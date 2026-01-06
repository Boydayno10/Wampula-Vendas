import 'package:flutter/material.dart';
import '../../routes.dart';
import '../../services/auth_service.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/wv_primary_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController inputCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();
  final TextEditingController confirmPasswordCtrl = TextEditingController();
  
  bool isPhone = false;
  bool isEmail = false;
  bool showPasswordFields = false; // Controla quando mostrar campos de senha
  bool isExistingEmail = false; // Se é email existente (login) ou novo (registro)
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    inputCtrl.dispose();
    passwordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _handleContinue() async {
    final input = inputCtrl.text.trim();
    
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, insira email ou telefone')),
      );
      return;
    }

    // Se for telefone, mostra mensagem de indisponível
    if (isPhone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Autenticação com número não está disponível no momento. Por favor, use email.'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    } 
    // Se for email, primeiro verifica se já existe
    else if (isEmail && !showPasswordFields) {
      setState(() => isLoading = true);
      
      final exists = await AuthService.emailExists(input);
      
      setState(() => isLoading = false);
      
      if (exists) {
        // Email já existe, é login - mostra apenas 1 campo de senha
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conta encontrada! Insira sua senha para fazer login.'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
          setState(() {
            showPasswordFields = true;
            isExistingEmail = true;
          });
        }
      } else {
        // Email novo, é registro - mostra 2 campos (senha e confirmar senha)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email não cadastrado. Crie sua senha para registrar.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          setState(() {
            showPasswordFields = true;
            isExistingEmail = false;
          });
        }
      }
    }
    // Se já mostrou os campos de senha, valida e continua
    else if (isEmail && showPasswordFields) {
      if (passwordCtrl.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, insira sua senha')),
        );
        return;
      }

      if (passwordCtrl.text.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A senha deve ter pelo menos 6 caracteres')),
        );
        return;
      }

      // Se é registro (email novo)
      if (!isExistingEmail) {
        if (confirmPasswordCtrl.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Por favor, confirme sua senha')),
          );
          return;
        }

        if (passwordCtrl.text != confirmPasswordCtrl.text) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('As senhas não coincidem')),
          );
          return;
        }

        // Vai para editar perfil (novo registro)
        Navigator.pushNamed(
          context,
          Routes.editProfile,
          arguments: {
            'isCreatingAccount': true,
            'email': input,
            'password': passwordCtrl.text,
            'registrationType': 'email',
          },
        );
      } else {
        // É login - valida senha
        setState(() => isLoading = true);
        
        final success = await AuthService.loginWithEmail(input, passwordCtrl.text);
        
        setState(() => isLoading = false);
        
        if (success && mounted) {
          AuthService.login();
          Navigator.pushNamedAndRemoveUntil(
            context,
            Routes.home,
            (route) => false,
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email ou senha incorretos')),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, insira um email ou telefone válido')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageHeight = ResponsiveHelper.getResponsiveImageHeight(context, 210);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ▌ Topo com imagem + botão voltar
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: imageHeight,
                    child: Image.asset(
                      "assets/images/nampula.jpg",
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: IconButton(
                      iconSize: 24,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),

              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 20)),

              // ▌ Conteúdo em card
              Padding(
                padding: ResponsiveHelper.getResponsivePadding(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bem-vindo à WV',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 20),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 6)),
                      Text(
                        'Entre ou crie sua conta para começar a vender e comprar com segurança.',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 13),
                          color: Colors.grey[600],
                        ),
                      ),

                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 20)),

                      /// 🔹 Campo único Email ou Telefone
                      TextField(
                        controller: inputCtrl,
                        keyboardType: isPhone
                            ? TextInputType.phone
                            : TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: "Email ou número de telefone",

                          /// Prefixo +258 |
                          prefixIcon: isPhone
                              ? SizedBox(
                                  width: 80,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Text(
                                        "+258",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "|",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : null,

                          /// 👇 Botão X que apaga o texto
                          suffixIcon: inputCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, color: Colors.grey),
                                  onPressed: () {
                                    setState(() {
                                      inputCtrl.clear();
                                      isPhone = false;
                                      isEmail = false;
                                      showPasswordFields = false;
                                      passwordCtrl.clear();
                                      confirmPasswordCtrl.clear();
                                    });
                                  },
                                )
                              : null,

                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),

                        /// Detecta se é número ou email
                        onChanged: (value) {
                          setState(() {
                            if (RegExp(r'^[0-9]+$').hasMatch(value)) {
                              isPhone = true;
                              isEmail = false;
                            } else if (_isValidEmail(value)) {
                              isEmail = true;
                              isPhone = false;
                            } else {
                              isPhone = false;
                              isEmail = false;
                            }
                          });
                        },
                      ),

                      /// 🔐 Campos de senha (aparecem só se for email e após verificação)
                      if (showPasswordFields) ...[
                        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 16)),
                        TextField(
                          controller: passwordCtrl,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: "Senha",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                        // Confirmar senha só aparece para registro (email novo)
                        if (!isExistingEmail) ...[
                          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 16)),
                          TextField(
                            controller: confirmPasswordCtrl,
                            obscureText: obscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: "Confirmar senha",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    obscureConfirmPassword = !obscureConfirmPassword;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ],

                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 22)),

                      /// 🔘 Botão Continuar
                      WVPrimaryButton(
                        label: 'Continuar',
                        onPressed: isLoading ? null : _handleContinue,
                        isLoading: isLoading,
                      ),

                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 12)),

                      /// 🔗 Recuperar senha
                      GestureDetector(
                        onTap: () {
                          // TODO: Implementar recuperação de senha
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Funcionalidade em desenvolvimento'),
                            ),
                          );
                        },
                        child: const Text(
                          "Problemas para entrar?",
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            color: Colors.grey,
                          ),
                        ),
                      ),

                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 22)),

                      /// ─── OU CONTINUAR COM ───
                      Row(
                        children: const [
                          Expanded(
                            child: Divider(color: Colors.grey, thickness: 0.5),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              "Ou continuar com",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          Expanded(
                            child: Divider(color: Colors.grey, thickness: 0.5),
                          ),
                        ],
                      ),

                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 22)),

                      /// 🔵 Google
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            // TODO: Implementar login com Google
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Funcionalidade em desenvolvimento'),
                              ),
                            );
                          },
                          child: const Text("Google"),
                        ),
                      ),

                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 12)),

                      /// 🔵 Facebook
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            // TODO: Implementar login com Facebook
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Funcionalidade em desenvolvimento'),
                              ),
                            );
                          },
                          child: const Text("Facebook"),
                        ),
                      ),

                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 16)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
