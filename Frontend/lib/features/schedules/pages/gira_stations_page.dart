import 'package:flutter/material.dart';

class GiraStationsPage extends StatelessWidget {
  const GiraStationsPage({super.key});

  static const _giraGreen = Color(0xFF8CC63F);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    // TODO: substituir por chamada real a /gira/stations (limit/offset)
    final stations = [
      const _GiraStationExample(
        name: 'Campo Grande',
        parish: 'Alvalade',
        capacity: 30,
      ),
      const _GiraStationExample(
        name: 'Campo Pequeno',
        parish: 'Avenidas Novas',
        capacity: 25,
      ),
      const _GiraStationExample(
        name: 'Cais do Sodré',
        parish: 'Misericórdia',
        capacity: 40,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _giraGreen,
        foregroundColor: Colors.black,
        title: const Text('Estações GIRA'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: stations.length,
        itemBuilder: (context, index) {
          final s = stations[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  _giraGreen.withOpacity(0.18),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  style: t.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.parish,
                  style: t.textTheme.bodyMedium?.copyWith(
                    color: t.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Capacidade aproximada: ${s.capacity} docks',
                  style: t.textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GiraStationExample {
  final String name;
  final String parish;
  final int capacity;

  const _GiraStationExample({
    required this.name,
    required this.parish,
    required this.capacity,
  });
}
