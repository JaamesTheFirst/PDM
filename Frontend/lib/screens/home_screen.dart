import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../state/auth_controller.dart';
import 'login_screen.dart';

/// === ECO THEME (inline para este ficheiro) ===
class EcoTheme {
  // Cores
  static const ecoMint = Color(0xFF3CD4A0);
  static const vibrantCoral = Color(0xFFFF6B6B);
  static const solarYellow = Color(0xFFFFD166);
  static const offWhiteSand = Color(0xFFF8F7F4);
  static const deepCharcoal = Color(0xFF1C1C1C);
  static const coolGrey = Color(0xFFA1A1A1);

  // Raio e sombras
  static const radius = 16.0;
  static const cardShadow = [
    BoxShadow(
      color: Colors.black12,
      blurRadius: 12,
      offset: Offset(0, 6),
    ),
  ];

  // Tipografia
  static const h2 = TextStyle(
    fontFamily: 'Poppins',
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 1.2,
    color: deepCharcoal,
  );
  static const body = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    height: 1.4,
    color: deepCharcoal,
  );
  static const bodyMuted = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    height: 1.4,
    color: coolGrey,
  );
  static const caption = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    color: coolGrey,
  );

  // Botões
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: ecoMint,
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    elevation: 0,
  );
  static ButtonStyle secondaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: solarYellow,
    foregroundColor: deepCharcoal,
    minimumSize: const Size(double.infinity, 48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    elevation: 0,
  );
}

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
      if (!mounted) return;
      setState(() {
        _health = '${res.statusCode} • ${res.body}';
      });
    } catch (e) {
      if (!mounted) return;
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
    return Scaffold(
      backgroundColor: EcoTheme.offWhiteSand,
      appBar: AppBar(
        backgroundColor: EcoTheme.offWhiteSand,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'EcoMove',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: EcoTheme.deepCharcoal,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Sair',
              icon: const Icon(Icons.logout, color: EcoTheme.deepCharcoal),
              onPressed: () async {
                final auth = context.read<AuthController>();
                await auth.logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
            ),
          )
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Card principal
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(EcoTheme.radius),
                    boxShadow: EcoTheme.cardShadow,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: const [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: EcoTheme.ecoMint,
                            child: Icon(Icons.eco, color: Colors.white, size: 18),
                          ),
                          SizedBox(width: 12),
                          Expanded(child: Text('Ligação ao Backend', style: EcoTheme.h2)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('GET /health', style: EcoTheme.caption),
                      const SizedBox(height: 12),
                      SelectableText(_health, textAlign: TextAlign.left, style: EcoTheme.body),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: EcoTheme.primaryButtonStyle,
                        onPressed: _testHealth,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Voltar a testar'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Map button
                ElevatedButton.icon(
                  style: EcoTheme.primaryButtonStyle,
                  onPressed: () => Navigator.of(context).pushNamed('/map'),
                  icon: const Icon(Icons.map),
                  label: const Text('Ver mapa'),
                ), 
                
                // Pills informativas
                Row(
                  children: const [
                    Expanded(
                      child: _InfoPill(
                        color: EcoTheme.ecoMint,
                        icon: Icons.savings,
                        label: 'Meta Eco',
                        value: '5kg CO₂/sem',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _InfoPill(
                        color: EcoTheme.solarYellow,
                        icon: Icons.route,
                        label: 'Rotas',
                        value: '3 opções',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final String value;

  const _InfoPill({
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12), // was withOpacity
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withValues(alpha: .4)), // was withOpacity
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: EcoTheme.bodyMuted, overflow: TextOverflow.ellipsis),
          ),
          Text(value, style: EcoTheme.body.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
