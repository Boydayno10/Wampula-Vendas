import 'package:flutter/material.dart';
import '../../routes.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../profile/edit_profile_screen.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/wv_primary_button.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  
  String? phone;
  bool isCreatingAccount = false;
  String? registrationType;
  Map<String, dynamic>? userData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Pega os argumentos da navegação
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    if (args != null) {
      phone = args['phone'];
      isCreatingAccount = args['isCreatingAccount'] ?? false;
      registrationType = args['registrationType'];
      userData = args['userData'];
    }
  }

  void _confirmOtp() async {
    // NOTA: Esta tela não está mais em uso - autenticação OTP foi desativada
    // Mantida apenas para evitar erros de navegação
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Autenticação com OTP não está disponível no momento'),
        backgroundColor: Colors.orange,
      ),
    );
    
    // Redireciona de volta para login
    Navigator.pushNamedAndRemoveUntil(
      context,
      Routes.login,
      (route) => false,
    );
    return;
    
    /* CÓDIGO ORIGINAL DESATIVADO
    // Junta os 6 dígitos
    final otp = otpControllers.map((c) => c.text).join();
    
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, insira o código completo')),
      );
      return;
    }

    if (!mounted) return;
    */
    
    if (isCreatingAccount) {
      // Se está criando conta
      if (registrationType == 'phone') {
        // Veio direto do telefone, vai para edit profile para completar dados
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EditProfileScreen(),
            settings: RouteSettings(
              arguments: {
                'isCreatingAccount': true,
                'phone': phone,
                'registrationType': 'phone',
              },
            ),
          ),
        );
      } else if (registrationType == 'email' && userData != null) {
        // Veio do email, já tem todos os dados, cria a conta e vai para home
        
        // Criar usuário
        final newUser = UserModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: userData!['name'],
          email: userData!['email'],
          phone: userData!['phone'],
          bairro: userData!['bairro'],
          // Cadastro por email entra sempre como cliente; vendedor é definido pelo admin
          isSeller: false,
          verified: false,
        );
        
        AuthService.createUser(newUser);
        
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
      }
    } else {
      // Se é login, vai direto para home
      AuthService.login();
      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.home,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageHeight = ResponsiveHelper.getResponsiveImageHeight(context, 200);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              /// ▌ Topo com imagem + seta voltar
              Stack(
                children: [
                  SizedBox(
                    height: imageHeight,
                    width: double.infinity,
                    child: Image.asset(
                      "assets/images/nampula.jpg",
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),

              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 24)),

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
                        "Verificação do número",
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 20),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 8)),
                      Text(
                        "Enviamos um código de 6 dígitos por SMS para ${phone ?? 'seu número'}.",
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 13),
                        ),
                      ),

                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 24)),

                      /// ▌ Caixas OTP
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (i) {
                          return _OtpBox(controller: otpControllers[i]);
                        }),
                      ),

                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 24)),

                      /// ▌ Botão Confirmar
                      WVPrimaryButton(
                        label: 'Confirmar',
                        onPressed: _confirmOtp,
                      ),

                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 16)),

                      /// ▌ Reenviar link
                      Center(
                        child: TextButton(
                          onPressed: () {
                            // TODO: Implementar reenvio de código
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Código reenviado!'),
                              ),
                            );
                          },
                          child: const Text(
                            "Reenviar código",
                            style: TextStyle(decoration: TextDecoration.underline),
                          ),
                        ),
                      ),
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

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  const _OtpBox({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      width: 44,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.only(top: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        onChanged: (value) {
          if (value.isNotEmpty) {
            FocusScope.of(context).nextFocus();
          } else {
            FocusScope.of(context).previousFocus();
          }
        },
      ),
    );
  }
}
