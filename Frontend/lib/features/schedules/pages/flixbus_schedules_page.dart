import 'package:flutter/material.dart';
import '../widgets/departure_card.dart';

class FlixbusSchedulesPage extends StatefulWidget {
  const FlixbusSchedulesPage({super.key});

  @override
  State<FlixbusSchedulesPage> createState() => _FlixbusSchedulesPageState();
}

class _FlixbusSchedulesPageState extends State<FlixbusSchedulesPage> {
  static const _flixbusGreen = Color(0xFF73BF15);

  final TextEditingController _searchController = TextEditingController();

  // DUMMY DATA – depois ligas ao backend
  final List<Departure> _allDepartures = const [
    Departure(
      time: '21:15',
      destination: 'Lisboa Oriente',
      line: 'FLX 501',
      platform: 'B5',
      operator: 'FlixBus',
    ),
    Departure(
      time: '22:00',
      destination: 'Porto (Campanhã)',
      line: 'FLX 701',
      platform: 'A2',
      operator: 'FlixBus',
    ),
  ];

  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Departure> get _filtered {
    if (_query.trim().isEmpty) return _allDepartures;
    final q = _query.toLowerCase();
    return _allDepartures.where((d) {
      return d.destination.toLowerCase().contains(q) ||
          d.line.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _flixbusGreen,
        foregroundColor: Colors.white,
        title: const Text('Horários FlixBus'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _query = value);
              },
              decoration: InputDecoration(
                hintText: 'Filtrar por destino ou linha...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: t.colorScheme.surfaceVariant.withOpacity(0.25),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final d = _filtered[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DepartureCard(
                    departure: d,
                    accentColor: _flixbusGreen,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
