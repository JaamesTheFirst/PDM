import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/state/auth_controller.dart';
import '../features/auth/pages/login_screen.dart';
import '../features/auth/pages/signup_screen.dart';
import '../features/impact/pages/impact_page.dart';
import 'app_shell.dart';
import '../features/map/pages/map_page.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const AuthGate());
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/signup':
        return MaterialPageRoute(builder: (_) => const SignUpScreen());
      case '/home':
        return MaterialPageRoute(builder: (_) => const AppShell());
      case '/map':
        return MaterialPageRoute(builder: (_) => const MapPage());
      case '/impact':
        return MaterialPageRoute(builder: (_) => const ImpactPage());
      default:
        return MaterialPageRoute(builder: (_) => const AuthGate());
    }
  }
}

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

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
