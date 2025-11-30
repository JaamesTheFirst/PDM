import 'package:flutter/material.dart';
import '../widgets/departure_card.dart';

class CarrisSchedulesPage extends StatefulWidget {
  const CarrisSchedulesPage({super.key});

  @override
  State<CarrisSchedulesPage> createState() =>
      _CarrisSchedulesPageState();
}

class _CarrisSchedulesPageState
    extends State<CarrisSchedulesPage> {
  static const _carrisYellow = Color(0xFFFFD600);

  final TextEditingController _searchController =
      TextEditingController();

  final List<Departure> _allDepartures = const [
    Departure(
      time: '19:10',
      destination: 'Cais do Sodré',
      line: '15E',
      platform: 'Paragem 3',
      operator: 'Carris',
    ),
    Departure(
      time: '19:18',
      destination: 'Belém',
      line: '728',
      platform: 'Paragem 1',
      operator: 'Carris',
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
        backgroundColor: _carrisYellow,
        foregroundColor: Colors.black,
        title: const Text('Horários Carris'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _query = value);
              },
              decoration: InputDecoration(
                hintText: 'Filtrar por destino ou linha...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor:
                    t.colorScheme.surfaceVariant.withOpacity(0.25),
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
              padding: const EdgeInsets.fromLTRB(
                  16, 8, 16, 24),
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final d = _filtered[index];
                return Padding(
                  padding:
                      const EdgeInsets.only(bottom: 10),
                  child: DepartureCard(
                    departure: d,
                    accentColor: _carrisYellow,
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
