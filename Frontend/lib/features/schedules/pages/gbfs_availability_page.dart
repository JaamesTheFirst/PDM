import 'package:flutter/material.dart';

class GbfsAvailabilityPage extends StatelessWidget {
  const GbfsAvailabilityPage({super.key});

  static const _gbfsGreen = Color(0xFF3CD4A0);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    // dummy data – depois trocas por chamada /gbfs/:systemId/stations
    final stations = [
      const _GbfsStationExample(
        name: 'Bird – Entrecampos',
        freeVehicles: 5,
        totalDocks: 10,
      ),
      const _GbfsStationExample(
        name: 'Bird – Cais do Sodré',
        freeVehicles: 2,
        totalDocks: 8,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _gbfsGreen,
        foregroundColor: Colors.black,
        title: const Text('Disponibilidade GBFS'),
      ),
      body: ListView.builder(
        padding:
            const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: stations.length,
        itemBuilder: (context, index) {
          final s = stations[index];
          final used = s.totalDocks - s.freeVehicles;
          final occupancy = s.totalDocks == 0
              ? 0
              : (used / s.totalDocks.toDouble() * 100).round();

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  _gbfsGreen.withOpacity(0.18),
                  t.colorScheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  style: t.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${s.freeVehicles} veículos disponíveis de ${s.totalDocks}',
                  style: t.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: s.totalDocks == 0
                      ? 0
                      : used / s.totalDocks.toDouble(),
                  color: _gbfsGreen,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 4),
                Text(
                  'Ocupação aproximada: $occupancy%',
                  style: t.textTheme.bodySmall?.copyWith(
                    color: t.hintColor,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GbfsStationExample {
  final String name;
  final int freeVehicles;
  final int totalDocks;

  const _GbfsStationExample({
    required this.name,
    required this.freeVehicles,
    required this.totalDocks,
  });
}
