import 'package:flutter/material.dart';
import '../../routes.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../profile/edit_profile_screen.dart';

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
          isSeller: true, // Cliente e vendedor ao mesmo tempo
          verified: true,
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          /// ▌ Topo com imagem + seta voltar
          Stack(
            children: [
              SizedBox(
                height: 200,
                width: double.infinity,
                child: Image.asset(
                  "assets/images/nampula.jpg",
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                left: 12,
                top: 40,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          /// ▌ Título e texto
          const Text(
            "Verificação do número",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "Enviamos um código de 6 dígitos por SMS para ${phone ?? 'seu número'}.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
          ),

          const SizedBox(height: 32),

          /// ▌ Caixas OTP
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) {
              return _OtpBox(controller: otpControllers[i]);
            }),
          ),

          const SizedBox(height: 32),

          /// ▌ Botão Confirmar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text("Confirmar"),
              ),
            ),
          ),

          const SizedBox(height: 16),

          /// ▌ Reenviar link
          TextButton(
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
        ],
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
          fillColor: Colors.grey[200],
          contentPadding: const EdgeInsets.only(top: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
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
