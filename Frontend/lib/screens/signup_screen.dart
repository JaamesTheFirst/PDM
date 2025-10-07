import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_controller.dart';
import 'home_screen.dart';

/// === ECO THEME (igual ao do login) ===
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
    fontSize: 28,
    height: 1.2,
    color: deepCharcoal,
  );

  static const small = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    color: coolGrey,
  );

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
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await context.read<AuthController>().register(
          username: _username.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          firstName: _firstName.text.trim().isEmpty ? null : _firstName.text.trim(),
          lastName: _lastName.text.trim().isEmpty ? null : _lastName.text.trim(),
        );
    if (!context.mounted) return;
    if (ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } else {
      setState(() => _error = 'Não foi possível criar a conta agora.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthController>().isLoading;

    return Scaffold(
      backgroundColor: EcoTheme.offWhiteSand,
      appBar: AppBar(
        backgroundColor: EcoTheme.offWhiteSand,
        elevation: 0,
        title: const Text('Criar conta', style: TextStyle(color: EcoTheme.deepCharcoal)),
        iconTheme: const IconThemeData(color: EcoTheme.deepCharcoal),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Theme(
              data: Theme.of(context).copyWith(inputDecorationTheme: EcoTheme.inputTheme),
              child: Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const Text('Bem-vindo!', style: EcoTheme.h1),
                    const SizedBox(height: 8),
                    const Text('Cria a tua conta para começares já a poupar CO₂.', style: EcoTheme.small),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstName,
                            decoration: const InputDecoration(labelText: 'Primeiro nome (opcional)'),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lastName,
                            decoration: const InputDecoration(labelText: 'Último nome (opcional)'),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _username,
                      decoration: const InputDecoration(labelText: 'Username'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Escolhe um username' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Insere o email';
                        final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
                        return ok ? null : 'Email inválido';
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _password,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Mostrar' : 'Esconder',
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, color: EcoTheme.coolGrey),
                        ),
                      ),
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Insere a password';
                        if (v.length < 6) return 'Mínimo 6 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _confirm,
                      decoration: const InputDecoration(labelText: 'Confirmar password'),
                      obscureText: true,
                      validator: (v) => (v != _password.text) ? 'As passwords não coincidem' : null,
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.error_outline, color: EcoTheme.vibrantCoral),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: const TextStyle(color: EcoTheme.vibrantCoral))),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EcoTheme.ecoMint,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          elevation: 0,
                        ),
                        onPressed: isLoading ? null : _submit,
                        child: isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Criar conta',
                                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
