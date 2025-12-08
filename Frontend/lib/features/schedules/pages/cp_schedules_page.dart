import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../widgets/departure_card.dart';
import '../data/cp_api.dart';

class CpSchedulesPage extends StatefulWidget {
  const CpSchedulesPage({super.key});

  @override
  State<CpSchedulesPage> createState() => _CpSchedulesPageState();
}

class _CpSchedulesPageState extends State<CpSchedulesPage> {
  static const _cpBlue = Color(0xFF00549A);

  final TextEditingController _searchController = TextEditingController();
  final CpApiClient _api = CpApiClient();

  String _searchQuery = '';
  bool _loadingSearch = false;
  bool _loadingBoard = false;
  bool _showCalendar = false;
  String? _error;

  DateTime _selectedDay = DateTime.now();
  CpStopSearchResult? _selectedStop;
  List<CpStopSearchResult> _searchResults = [];
  CpStopBoard? _board;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==================== SEARCH STOPS ====================

  Future<void> _performSearch() async {
    final q = _searchController.text.trim();
    debugPrint('[CP PAGE] _performSearch("$q")');

    if (q.length < 2) {
      setState(() {
        _searchQuery = q;
        _searchResults = [];
      });
      debugPrint('[CP PAGE] query muito curta, a sair.');
      return;
    }

    setState(() {
      _searchQuery = q;
      _loadingSearch = true;
      _error = null;
    });

    try {
      final results = await _api.searchStops(q);
      setState(() {
        _searchResults = results;
      });
      debugPrint(
        '[CP PAGE] _performSearch -> ${results.length} estações encontradas.',
      );
    } catch (e) {
      debugPrint('[CP PAGE] _performSearch ERROR: $e');
      setState(() {
        _error = e.toString();
        _searchResults = [];
      });
    } finally {
      setState(() {
        _loadingSearch = false;
      });
    }
  }

  void _onSelectStop(CpStopSearchResult stop) {
    debugPrint('[CP PAGE] _onSelectStop -> ${stop.name} (${stop.gtfsId})');
    setState(() {
      _selectedStop = stop;
      _searchResults = [];
      _searchController.text = stop.name;
    });
    _loadBoard();
  }

  // ===================== LOAD BOARD =====================

  Future<void> _loadBoard() async {
    if (_selectedStop == null) {
      debugPrint('[CP PAGE] _loadBoard chamado sem estação selecionada');
      return;
    }

    debugPrint(
      '[CP PAGE] _loadBoard -> stop=${_selectedStop!.gtfsId}, day=$_selectedDay',
    );

    setState(() {
      _loadingBoard = true;
      _error = null;
    });

    try {
      final board = await _api.getStopBoard(
        stopGtfsId: _selectedStop!.gtfsId,
        day: _selectedDay,
      );
      setState(() {
        _board = board;
      });
      debugPrint(
        '[CP PAGE] _loadBoard -> ${board.departures.length} partidas carregadas.',
      );
    } catch (e) {
      debugPrint('[CP PAGE] _loadBoard ERROR: $e');
      setState(() {
        _error = e.toString();
        _board = null;
      });
    } finally {
      setState(() {
        _loadingBoard = false;
      });
    }
  }

  // ======================= UI HELPERS =======================

  String _formatDay(BuildContext context, DateTime day) {
    final localizations = MaterialLocalizations.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = DateUtils.dateOnly(day);

    final base = localizations.formatFullDate(day);

    if (selected == today) {
      return '$base (hoje)';
    }

    return base;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _cpBlue,
        foregroundColor: Colors.white,
        title: const Text('Horários CP'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),

                    // ==== SEARCH POR ESTAÇÃO ====
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: (_) => _performSearch(),
                        decoration: InputDecoration(
                          hintText: 'Procurar estação CP...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _loadingSearch
                              ? Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                              _cpBlue),
                                    ),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.arrow_forward),
                                  onPressed: _performSearch,
                                ),
                          filled: true,
                          fillColor:
                              t.colorScheme.surfaceVariant.withValues(alpha: 0.25),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ==== SELECTOR DE DIA + CALENDÁRIO INLINE ====
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
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: _cpBlue,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _formatDay(context, _selectedDay),
                                  style: t.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Icon(
                                _showCalendar
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Theme(
                          data: t.copyWith(
                            colorScheme: t.colorScheme.copyWith(
                              primary: _cpBlue,
                              onPrimary: Colors.white,
                              surface: t.colorScheme.surface,
                              onSurface: t.colorScheme.onSurface,
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: _cpBlue,
                              ),
                            ),
                          ),
                          child: CalendarDatePicker(
                            initialDate: _selectedDay,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 7)),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 60)),
                            onDateChanged: (date) {
                              setState(() {
                                _selectedDay = date;
                              });
                              _loadBoard();
                            },
                          ),
                        ),
                      ),
                      crossFadeState: _showCalendar
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                    ),

                    // ==== RESULTADOS DA PESQUISA DE ESTAÇÕES ====
                    if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: t.colorScheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
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

                    // ==== LISTA DE HORÁRIOS / ESTADOS ====
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: _buildBoardSection(context),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBoardSection(BuildContext context) {
    final t = Theme.of(context);

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          child: Text(
            'Procura uma estação CP e seleciona-a para veres os horários das partidas.',
            textAlign: TextAlign.center,
            style: t.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final departures = _board?.departures ?? [];

    if (_loadingBoard && departures.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(
          child: CircularProgressIndicator(
            valueColor:
                AlwaysStoppedAnimation<Color>(_cpBlue),
          ),
        ),
      );
    }

    if (departures.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          child: Text(
            'Não foram encontradas partidas para este dia.',
            textAlign: TextAlign.center,
            style: t.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: departures.length,
          itemBuilder: (context, index) {
            final row = departures[index];

            final departure = Departure(
              time: row.time,
              destination: row.destination ?? '—',
              line: row.lineShortName ?? row.lineLongName ?? '',
              platform: '—', // se o board trouxer plataforma, metes aqui
              operator: 'CP',
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DepartureCard(
                departure: departure,
                accentColor: _cpBlue,
              ),
            );
          },
        ),

        if (_loadingBoard)
          Positioned(
            right: 16,
            top: 0,
            child: SizedBox(
              width: 20,
              height: 20,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(_cpBlue),
              ),
            ),
          ),
      ],
    );
  }
}
