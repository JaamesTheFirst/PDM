import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../features/auth/state/auth_controller.dart';
import '../features/auth/pages/login_screen.dart';

/// Tema visual "Eco" utilizado neste ecrã.
///
/// Contém cores, tipografia e estilos de botões prontos a usar.
/// Aqui está definido inline apenas para este ficheiro, mas pode ser
/// extraído para um tema global se fizer sentido mais tarde.
class EcoTheme {
  // ===== CORES PRINCIPAIS =====

  /// Verde principal da identidade EcoMove (botões primários, acentos).
  static const ecoMint = Color(0xFF3CD4A0);

  /// Coral vibrante (avisos/estados de atenção, se necessário).
  static const vibrantCoral = Color(0xFFFF6B6B);

  /// Amarelo solar (botões secundários, destaques).
  static const solarYellow = Color(0xFFFFD166);

  /// Fundo claro “areia” usado no background do ecrã.
  static const offWhiteSand = Color(0xFFF8F7F4);

  /// Cinzento muito escuro para texto principal.
  static const deepCharcoal = Color(0xFF1C1C1C);

  /// Cinzento frio para textos secundários.
  static const coolGrey = Color(0xFFA1A1A1);

  // ===== RAIO E SOMBRAS =====

  /// Raio de canto padrão para cartões e elementos arredondados.
  static const radius = 16.0;

  /// Sombra padrão usada em cartões principais.
  static const cardShadow = [
    BoxShadow(
      color: Colors.black12,
      blurRadius: 12,
      offset: Offset(0, 6),
    ),
  ];

  // ===== TIPOGRAFIA =====

  /// Estilo de título médio/grande para headings dentro de cartões.
  static const h2 = TextStyle(
    fontFamily: 'Poppins',
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 1.2,
    color: deepCharcoal,
  );

  /// Estilo de corpo principal (texto normal).
  static const body = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    height: 1.4,
    color: deepCharcoal,
  );

  /// Estilo de corpo secundário (texto descritivo, legendas).
  static const bodyMuted = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    height: 1.4,
    color: coolGrey,
  );

  /// Estilo para captions e meta-informação.
  static const caption = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    color: coolGrey,
  );

  // ===== ESTILOS DE BOTÕES =====

  /// Estilo de botão primário (usar para ações principais).
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: ecoMint,
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    elevation: 0,
  );

  /// Estilo de botão secundário (ações alternativas/destaques).
  static ButtonStyle secondaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: solarYellow,
    foregroundColor: deepCharcoal,
    minimumSize: const Size(double.infinity, 48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    elevation: 0,
  );
}

/// Ecrã principal (home) da app pós-login.
///
/// Funções principais:
/// - Testar a ligação ao backend chamando `GET /health`.
/// - Mostrar o estado atual da saúde da API.
/// - Permitir logout do utilizador.
/// - Dar acesso ao mapa (`/map`) e mostrar algumas métricas estáticas
///   (pills informativas).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Texto atual com o resultado do teste de saúde da API.
  ///
  /// Exemplo: `200 • OK` ou mensagem de erro.
  String _health = 'A testar…';

  /// Faz uma chamada ao endpoint `/health` do backend e atualiza [_health].
  ///
  /// - Em caso de sucesso: mostra `statusCode • body`.
  /// - Em caso de erro: mostra a exceção capturada.
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
    // Testa a saúde do backend assim que o ecrã é aberto.
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
                // ===== CARD PRINCIPAL: SAÚDE DO BACKEND =====
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
                          Expanded(
                            child: Text(
                              'Ligação ao Backend',
                              style: EcoTheme.h2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('GET /health', style: EcoTheme.caption),
                      const SizedBox(height: 12),
                      SelectableText(
                        _health,
                        textAlign: TextAlign.left,
                        style: EcoTheme.body,
                      ),
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

                // ===== BOTÃO PARA MAPA =====
                ElevatedButton.icon(
                  style: EcoTheme.primaryButtonStyle,
                  onPressed: () => Navigator.of(context).pushNamed('/map'),
                  icon: const Icon(Icons.map),
                  label: const Text('Ver mapa'),
                ),

                // ===== PILLS INFORMATIVAS (ESTÁTICAS / PLACEHOLDER) =====
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

/// Pequeno cartão “pill” com uma métrica/resumo.
///
/// Exemplo de uso:
/// - Meta de CO₂ por semana.
/// - Número de rotas disponíveis.
/// - Qualquer KPI pequeno que caiba numa linha.
class _InfoPill extends StatelessWidget {
  /// Cor base da pill (ícone, borda e fundo translucido).
  final Color color;

  /// Ícone principal a mostrar à esquerda.
  final IconData icon;

  /// Label descritivo (ex.: "Meta Eco").
  final String label;

  /// Valor/indicador (ex.: "5kg CO₂/sem").
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
        color: color.withValues(alpha: .12), // equivalente a withOpacity(0.12)
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: color.withValues(alpha: .4), // equivalente a withOpacity(0.4)
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: EcoTheme.bodyMuted,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            value,
            style: EcoTheme.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
