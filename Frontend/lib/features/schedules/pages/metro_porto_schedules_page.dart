import 'package:flutter/material.dart';

import '../data/metro_porto_api.dart';
import '../widgets/departure_card.dart';

class MetroPortoSchedulesPage extends StatefulWidget {
  const MetroPortoSchedulesPage({super.key});

  @override
  State<MetroPortoSchedulesPage> createState() =>
      _MetroPortoSchedulesPageState();
}

class _MetroPortoSchedulesPageState
    extends State<MetroPortoSchedulesPage> {
  static const _metroPurple = Color(0xFF5A2A82);

  final TextEditingController _searchController =
      TextEditingController();
  final MetroPortoApiClient _api = MetroPortoApiClient();

  bool _loadingSearch = false;
  bool _loadingDepartures = false;
  bool _showCalendar = false;
  String? _error;

  DateTime _selectedDay = DateTime.now();
  List<MetroPortoStop> _searchResults = [];
  MetroPortoStop? _selectedStop;
  List<MetroPortoDepartureRow> _departures = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==================== SEARCH STOPS ====================

  Future<void> _performSearch() async {
    final q = _searchController.text.trim();
    debugPrint('[METRO PAGE] _performSearch("$q")');

    if (q.length < 2) {
      setState(() {
        _searchResults = [];
      });
      debugPrint('[METRO PAGE] query demasiado curta, a sair.');
      return;
    }

    setState(() {
      _loadingSearch = true;
      _error = null;
    });

    try {
      final results = await _api.searchStops(q);
      debugPrint(
        '[METRO PAGE] _performSearch -> ${results.length} stops',
      );
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      debugPrint('[METRO PAGE] _performSearch ERROR: $e');
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loadingSearch = false;
      });
    }
  }

  void _onSelectStop(MetroPortoStop stop) {
    debugPrint(
        '[METRO PAGE] _onSelectStop -> ${stop.name} (${stop.id})');
    setState(() {
      _selectedStop = stop;
      _searchResults = [];
      _searchController.text = stop.name;
    });
    _loadDepartures();
  }

  // ===================== LOAD DEPARTURES =====================

  Future<void> _loadDepartures() async {
    if (_selectedStop == null) {
      debugPrint(
          '[METRO PAGE] _loadDepartures chamado sem stop selecionada');
      return;
    }

    debugPrint(
        '[METRO PAGE] _loadDepartures stop=${_selectedStop!.id} day=$_selectedDay');

    setState(() {
      _loadingDepartures = true;
      _error = null;
    });

    try {
      // Nota: neste momento o dia NÃO é passado para o backend.
      // Se quiseres mesmo filtrar por dia no OTP, tens de adaptar
      // o endpoint como na CP (startTime/timeRange).
      final rows = await _api.getUpcomingDepartures(
        stopId: _selectedStop!.id,
      );
      setState(() {
        _departures = rows;
      });
      debugPrint(
          '[METRO PAGE] _loadDepartures -> ${rows.length} partidas');
    } catch (e) {
      debugPrint('[METRO PAGE] _loadDepartures ERROR: $e');
      setState(() {
        _error = e.toString();
        _departures = [];
      });
    } finally {
      setState(() {
        _loadingDepartures = false;
      });
    }
  }

  // ======================= UI HELPERS =======================

  String _formatDay(BuildContext context, DateTime day) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatFullDate(day);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _metroPurple,
        foregroundColor: Colors.white,
        title: const Text('Horários Metro do Porto'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),

          // ===== SEARCH POR ESTAÇÃO =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _performSearch(),
              decoration: InputDecoration(
                hintText: 'Procurar estação Metro do Porto...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _loadingSearch
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: _performSearch,
                      ),
                filled: true,
                fillColor: t.colorScheme.surfaceVariant
                    .withOpacity(0.25),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ===== SELECTOR DE DIA =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                setState(() {
                  _showCalendar = !_showCalendar;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color:
                      _metroPurple.withOpacity(0.10), // roxinho suave
                  border: Border.all(
                    color: _metroPurple.withOpacity(0.6),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _formatDay(context, _selectedDay),
                      style: t.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _showCalendar
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                  ],
                ),
              ),
            ),
          ),

          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8),
              child: Theme(
                data: t.copyWith(
                  colorScheme: t.colorScheme.copyWith(
                    primary: _metroPurple,
                    onPrimary: Colors.white,
                    surface: t.colorScheme.surface,
                    onSurface: t.colorScheme.onSurface,
                  ),
                ),
                child: CalendarDatePicker(
                  initialDate: _selectedDay,
                  firstDate: DateTime.now()
                      .subtract(const Duration(days: 1)),
                  lastDate: DateTime.now()
                      .add(const Duration(days: 60)),
                  onDateChanged: (date) {
                    setState(() {
                      _selectedDay = date;
                    });
                    _loadDepartures();
                  },
                ),
              ),
            ),
            crossFadeState: _showCalendar
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),

          // ===== RESULTADOS DA PESQUISA DAS ESTAÇÕES =====
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: t.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final stop = _searchResults[index];
                    return ListTile(
                      dense: true,
                      title: Text(stop.name),
                      subtitle: (stop.lat != null &&
                              stop.lon != null)
                          ? Text(
                              '(${stop.lat!.toStringAsFixed(4)}, ${stop.lon!.toStringAsFixed(4)})',
                              style: t.textTheme.bodySmall
                                  ?.copyWith(
                                      color: t.hintColor),
                            )
                          : null,
                      onTap: () => _onSelectStop(stop),
                    );
                  },
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),

          // ===== LISTA DE PARTIDAS / ESTADOS =====
          Expanded(
            child: _buildDeparturesContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDeparturesContent(BuildContext context) {
    final t = Theme.of(context);

    if (_error != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: t.textTheme.bodyMedium?.copyWith(
              color: Colors.redAccent,
            ),
          ),
        ),
      );
    }

    if (_selectedStop == null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Procura uma estação do Metro do Porto e seleciona-a para veres as próximas partidas.',
            textAlign: TextAlign.center,
            style: t.textTheme.bodyMedium,
          ),
        ),
      );
    }

    if (_departures.isEmpty && !_loadingDepartures) {
      return Center(
        child: Text(
          'Não foram encontradas partidas próximas para esta estação neste momento.',
          textAlign: TextAlign.center,
          style: t.textTheme.bodyMedium,
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: _departures.length,
          itemBuilder: (context, index) {
            final row = _departures[index];

            final departure = Departure(
              time: row.time,
              destination:
                  row.destination.isEmpty ? '—' : row.destination,
              line: row.line,
              platform: '—',
              operator: 'Metro do Porto',
            );

            return Padding(
              padding:
                  const EdgeInsets.only(bottom: 10),
              child: DepartureCard(
                departure: departure,
                accentColor: _metroPurple,
              ),
            );
          },
        ),

        if (_loadingDepartures)
          const Positioned(
            right: 16,
            top: 8,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          ),
      ],
    );
  }
}
