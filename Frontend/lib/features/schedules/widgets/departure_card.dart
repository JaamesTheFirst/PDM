import 'package:flutter/material.dart';

/// Modelo que representa uma partida num painel de horários.
///
/// Pode ser usado para comboios, metro, autocarros ou outros modos,
/// desde que seja possível mapear:
/// - [time]: hora de partida formatada (ex.: "14:32").
/// - [destination]: nome do destino (ex.: "Trindade").
/// - [line]: código ou nome da linha (ex.: "Linha A").
/// - [platform]: número ou identificação de plataforma.
/// - [operator]: nome do operador (ex.: "CP", "Metro do Porto").
class Departure {
  /// Hora de partida no formato legível (não é um DateTime).
  final String time;

  /// Destino desta partida (ex.: estação ou terminal).
  final String destination;

  /// Linha associada à partida (ex.: "Linha Amarela").
  final String line;

  /// Plataforma / cais / via onde o veículo parte.
  final String platform;

  /// Nome do operador que explora a partida (ex.: CP, Metro do Porto).
  final String operator;

  const Departure({
    required this.time,
    required this.destination,
    required this.line,
    required this.platform,
    required this.operator,
  });
}

/// Cartão visual que apresenta a informação de uma [Departure].
///
/// Mostra:
/// - Hora de partida em destaque.
/// - Linha.
/// - Destino.
/// - Operador.
/// - Plataforma, realçada com o [accentColor].
///
/// O widget não faz formatação de datas/horas; espera receber strings
/// prontas a apresentar.
class DepartureCard extends StatelessWidget {
  /// Partida a ser desenhada no cartão.
  final Departure departure;

  /// Cor de destaque usada no gradiente de fundo e chip de plataforma.
  final Color accentColor;

  const DepartureCard({
    super.key,
    required this.departure,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            accentColor.withOpacity(0.14),
            t.colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Hora + linha
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                departure.time,
                style: t.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                departure.line,
                style: t.textTheme.bodySmall?.copyWith(
                  color: t.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Destino + operador
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  departure.destination,
                  style: t.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Operador: ${departure.operator}',
                  style: t.textTheme.bodySmall?.copyWith(
                    color: t.textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Plataforma
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Plataforma',
                style: t.textTheme.bodySmall?.copyWith(
                  color: t.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: accentColor.withOpacity(0.14),
                ),
                child: Text(
                  departure.platform,
                  style: t.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
