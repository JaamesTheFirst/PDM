import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_controller.dart';
import '../../../screens/home_screen.dart';
import 'signup_screen.dart';

/// === ECO THEME (igual ao teu) ===
class EcoTheme {
  static const ecoMint = Color(0xFF3CD4A0);
  static const vibrantCoral = Color(0xFFFF6B6B);
  static const solarYellow = Color(0xFFFFD166);
  static const offWhiteSand = Color(0xFFF8F7F4);
  static const deepCharcoal = Color(0xFF1C1C1C);
  static const coolGrey = Color(0xFFA1A1A1);

  static const radius = 16.0;

  static const h1 = TextStyle(
    fontFamily: 'Poppins',
    fontWeight: FontWeight.w700,
    fontSize: 32,
    height: 1.15,
    color: deepCharcoal,
  );
  static const small = TextStyle(fontFamily: 'Inter', fontSize: 12, color: coolGrey);

  static InputDecorationTheme get inputTheme => InputDecorationTheme(
        labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: deepCharcoal),
        hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: coolGrey),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: coolGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: ecoMint, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: vibrantCoral),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: vibrantCoral, width: 2),
        ),
      );

  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: ecoMint,
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    elevation: 0,
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController(); // email ou username
  final _password = TextEditingController();
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await context.read<AuthController>().login(
          identifier: _identifier.text.trim(),
          password: _password.text,
        );
    if (!context.mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      setState(() => _error = 'Credenciais inválidas ou servidor indisponível.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthController>().isLoading;

    return Scaffold(
      backgroundColor: EcoTheme.offWhiteSand,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Theme(
              data: Theme.of(context).copyWith(inputDecorationTheme: EcoTheme.inputTheme),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(color: EcoTheme.ecoMint, shape: BoxShape.circle),
                      child: const Icon(Icons.eco, color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 16),
                    const Text('Bem-vindo à EcoMove', style: EcoTheme.h1),
                    const SizedBox(height: 8),
                    const Text('Entra para escolher as rotas mais eco-friendly.', style: EcoTheme.small, textAlign: TextAlign.center),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _identifier,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 16, color: EcoTheme.deepCharcoal),
                      decoration: const InputDecoration(
                        labelText: 'Email ou username',
                        hintText: 'ex.: joana | joana@email.com',
                      ),
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Escreve o email ou username' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _password,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 16, color: EcoTheme.deepCharcoal),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Mostrar' : 'Esconder',
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, color: EcoTheme.coolGrey),
                        ),
                      ),
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      validator: (v) => (v == null || v.isEmpty) ? 'Insere a password' : null,
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: EcoTheme.primaryButtonStyle,
                        onPressed: isLoading ? null : _submit,
                        child: isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Entrar', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 16)),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.error_outline, color: EcoTheme.vibrantCoral),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: EcoTheme.vibrantCoral)),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Ainda não tens conta?',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: EcoTheme.deepCharcoal)),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignUpScreen())),
                          child: const Text('Criar conta',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: EcoTheme.ecoMint)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Text('Dica (mock mode): password correta = 123456', style: EcoTheme.small),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
