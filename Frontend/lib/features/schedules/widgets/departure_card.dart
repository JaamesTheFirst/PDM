import 'package:flutter/material.dart';

class Departure {
  final String time;
  final String destination;
  final String line;
  final String platform;
  final String operator;

  const Departure({
    required this.time,
    required this.destination,
    required this.line,
    required this.platform,
    required this.operator,
  });
}

class DepartureCard extends StatelessWidget {
  final Departure departure;
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
                  color:
                      t.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Destino
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
                    color: t.textTheme.bodySmall?.color
                        ?.withOpacity(0.7),
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
                  color: t.textTheme.bodySmall?.color
                      ?.withOpacity(0.7),
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
