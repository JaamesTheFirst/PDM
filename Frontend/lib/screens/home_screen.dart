//import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../state/auth_controller.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _health = 'A testar…';

  Future<void> _testHealth() async {
    try {
      final res = await ApiClient.instance.get('/health');
      setState(() {
        _health = '${res.statusCode} • ${res.body}';
      });
    } catch (e) {
      setState(() => _health = 'Erro: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _testHealth();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          )
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Ligação ao Backend (GET /health)'),
              const SizedBox(height: 8),
              SelectableText(_health, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _testHealth, child: const Text('Voltar a testar')),
            ]),
          ),
        ),
      ),
    );
  }
}
