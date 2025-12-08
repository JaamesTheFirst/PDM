// lib/app/app_router.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/state/auth_controller.dart';
import '../features/auth/pages/login_screen.dart';
import '../features/auth/pages/signup_screen.dart';
import '../features/impact/pages/impact_page.dart';
import '../features/map/pages/map_page.dart';
import '../features/settings/pages/settings_page.dart';
import 'app_shell.dart';

/// Responsável por criar as rotas nomeadas da aplicação.
///
/// Este router é usado no `MaterialApp.onGenerateRoute` para mapear
/// nomes de rotas (`/`, `/login`, `/home`, etc.) para os respetivos
/// widgets (screens).
class AppRouter {
  /// Função de factory de rotas para o `MaterialApp`.
  ///
  /// Usa [RouteSettings.name] para decidir qual página criar.
  /// Se o nome não for reconhecido, cai por omissão na [AuthGate].
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        // Primeira rota: decide se vai para /home ou /login.
        return MaterialPageRoute(builder: (_) => const AuthGate());

      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case '/signup':
        return MaterialPageRoute(builder: (_) => const SignUpScreen());

      case '/home':
        // Shell com bottom navigation e as principais tabs.
        return MaterialPageRoute(builder: (_) => const AppShell());

      case '/map':
        return MaterialPageRoute(builder: (_) => const MapPage());

      case '/impact':
        return MaterialPageRoute(builder: (_) => const ImpactPage());

      case '/settings':
        return MaterialPageRoute(builder: (_) => const SettingsPage());

      default:
        // Qualquer rota desconhecida volta a passar pelo AuthGate.
        return MaterialPageRoute(builder: (_) => const AuthGate());
    }
  }
}

/// Widget inicial que decide se o utilizador deve ir para
/// a área autenticada (`/home`) ou para o ecrã de login (`/login`).
///
/// Usa o [AuthController] para verificar o estado de autenticação assim
/// que é criado.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  /// Verifica de forma assíncrona se o utilizador está autenticado
  /// e redireciona para a rota apropriada.
  ///
  /// - Se [AuthController.isLoggedIn] devolver `true`, navega para `/home`.
  /// - Caso contrário, navega para `/login`.
  ///
  /// Utiliza [Navigator.pushReplacementNamed] para substituir o [AuthGate]
  /// na stack de navegação, evitando que o utilizador volte atrás para este ecrã.
  Future<void> _check() async {
    final auth = context.read<AuthController>();
    final logged = await auth.isLoggedIn();
    if (!mounted) return;

    if (logged) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  /// Enquanto a verificação de autenticação decorre,
  /// mostra apenas um indicador de carregamento centrado.
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
