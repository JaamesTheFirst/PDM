import 'package:flutter/material.dart';

import 'cp_schedules_page.dart';
import 'flixbus_schedules_page.dart';
import 'metro_porto_schedules_page.dart';
import 'carris_schedules_page.dart';
import 'gbfs_availability_page.dart';
import 'gira_stations_page.dart';

/// Página principal de “Horários & disponibilidade”.
///
/// Lista os diferentes operadores/serviços integrados na app
/// (CP, FlixBus, Metro do Porto, Carris, GIRA, sistemas GBFS) e
/// faz navegação para as páginas dedicadas de cada um.
class SchedulesPage extends StatelessWidget {
  const SchedulesPage({super.key});

  /// Cor institucional aproximada da CP (Comboios de Portugal).
  static const _cpBlue = Color(0xFF00549A);

  /// Verde aproximado da identidade FlixBus.
  static const _flixbusGreen = Color(0xFF73BF15);

  /// Roxo aproximado do Metro do Porto.
  static const _metroPortoPurple = Color(0xFF5A2A82);

  /// Amarelo aproximado da Carris.
  static const _carrisYellow = Color(0xFFFFD600);

  /// Verde usado para sistemas GBFS (bike/scooter sharing).
  static const _gbfsGreen = Color(0xFF3CD4A0);

  /// Verde aproximado da marca GIRA.
  static const _giraGreen = Color(0xFF8CC63F);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          'Horários & disponibilidade',
          style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Escolhe o operador para ver partidas ou veículos disponíveis.',
          style: t.textTheme.bodyMedium?.copyWith(
            color: t.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 20),

        // CP – Comboios de Portugal
        _OperatorCard(
          title: 'CP – Comboios de Portugal',
          subtitle: 'Quadros de partidas por estação (GTFS CP).',
          icon: Icons.train,
          color: _cpBlue,
          chipLabel: 'Comboios',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CpSchedulesPage()),
            );
          },
        ),
        const SizedBox(height: 12),

        // FlixBus
        _OperatorCard(
          title: 'FlixBus Portugal',
          subtitle: 'Horários de autocarros de longo curso (GTFS FlixBus).',
          icon: Icons.directions_bus_filled,
          color: _flixbusGreen,
          chipLabel: 'Longo curso',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => FlixbusSchedulesPage()),
            );
          },
        ),
        const SizedBox(height: 12),

        // Metro do Porto
        _OperatorCard(
          title: 'Metro do Porto',
          subtitle: 'Partidas por estação (GTFS Metro Porto).',
          icon: Icons.subway,
          color: _metroPortoPurple,
          chipLabel: 'Metro',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MetroPortoSchedulesPage(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // Carris
        _OperatorCard(
          title: 'Carris / rede urbana',
          subtitle: 'Linhas urbanas a partir do grafo OTP (GTFS Carris).',
          icon: Icons.directions_bus,
          color: _carrisYellow,
          chipLabel: 'Autocarros',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CarrisSchedulesPage()),
            );
          },
        ),
        const SizedBox(height: 12),

        // GIRA – Lisboa
        _OperatorCard(
          title: 'GIRA – Lisboa bike-share',
          subtitle: 'Estações e capacidade histórica (dataset GIRA na BD).',
          icon: Icons.pedal_bike,
          color: _giraGreen,
          chipLabel: 'GIRA',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GiraStationsPage()),
            );
          },
        ),
        const SizedBox(height: 12),

        // Sistemas GBFS
        _OperatorCard(
          title: 'Sistemas GBFS',
          subtitle:
              'Disponibilidade em tempo real de bikes/trotinetes (Bird, etc.).',
          icon: Icons.pedal_bike,
          color: _gbfsGreen,
          chipLabel: 'GBFS',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GbfsAvailabilityPage()),
            );
          },
        ),
      ],
    );
  }
}

/// Cartão de operador apresentado na [SchedulesPage].
///
/// Mostra:
/// - Ícone grande de fundo.
/// - Título (nome do operador).
/// - Descrição curta.
/// - “Chip” com o tipo de serviço (ex.: Comboios, Metro, GBFS).
/// - Seta de navegação.
///
/// Ao tocar no cartão, executa o [onTap] recebido.
class _OperatorCard extends StatelessWidget {
  /// Título principal (ex.: "CP – Comboios de Portugal").
  final String title;

  /// Descrição/explicação do tipo de dados disponíveis.
  final String subtitle;

  /// Ícone representativo do modo de transporte (comboio, metro, etc.).
  final IconData icon;

  /// Cor base do gradiente do cartão.
  final Color color;

  /// Texto exibido no chip (ex.: "Metro", "Comboios").
  final String chipLabel;

  /// Se `true`, usa texto escuro; se `false`, usa texto branco.
  ///
  /// Útil para fundos mais claros (ex.: amarelo Carris).
  final bool darkText;

  /// Callback executado quando o cartão é tocado.
  final VoidCallback onTap;

  const _OperatorCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.chipLabel,
    required this.onTap,
    this.darkText = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final textColor = darkText ? Colors.black87 : Colors.white;
    final subColor = darkText ? Colors.black54 : Colors.white70;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 120),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [color, Color.lerp(color, Colors.black, 0.35)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Ícone gigante de fundo
              Positioned.fill(
                child: Align(
                  alignment: const Alignment(-0.9, -0.6),
                  child: Icon(
                    icon,
                    size: 140,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
              ),

              // Overlay suave
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),

              // Conteúdo (texto + chip + seta)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.textTheme.bodySmall?.copyWith(
                              color: subColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: Colors.black.withValues(alpha: 0.18),
                            ),
                            child: Text(
                              chipLabel,
                              style: t.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
