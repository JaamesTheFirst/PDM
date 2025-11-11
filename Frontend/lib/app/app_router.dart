import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/state/auth_controller.dart';
import '../features/auth/pages/login_screen.dart';
import '../features/auth/pages/signup_screen.dart';
import '../features/impact/pages/impact_page.dart';
import '../features/map/pages/map_page.dart';
import '../features/map/pages/route_search_page.dart';
import 'app_shell.dart';

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

      case '/route-search':
        return PageRouteBuilder(
          pageBuilder: (_, __, ___) => const RouteSearchPage(),
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (_, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );

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
