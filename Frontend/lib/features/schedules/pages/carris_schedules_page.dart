import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../widgets/departure_card.dart';
import '../data/carris_api.dart';

/// Página de horários da Carris / rede urbana.
///
/// Funcionalidades:
/// - Pesquisar paragens Carris.
/// - Ver próximas partidas para uma paragem seleccionada.
/// - Mostrar estados de carregamento/erro de forma amigável.
class CarrisSchedulesPage extends StatefulWidget {
  const CarrisSchedulesPage({super.key});

  @override
  State<CarrisSchedulesPage> createState() => _CarrisSchedulesPageState();
}

class _CarrisSchedulesPageState extends State<CarrisSchedulesPage> {
  /// Amarelo institucional aproximado da Carris.
  static const _carrisYellow = Color(0xFFFFD600);

  /// Campo de pesquisa de paragem Carris.
  final TextEditingController _searchController = TextEditingController();

  /// Cliente de API para interagir com dados da Carris.
  final CarrisApiClient _api = CarrisApiClient();

  /// Query de pesquisa actual.
  String _searchQuery = '';

  /// Flag de carregamento durante pesquisa de paragens.
  bool _loadingSearch = false;

  /// Flag de carregamento durante obtenção de partidas.
  bool _loadingDepartures = false;

  /// Mensagem de erro global.
  String? _error;

  /// Paragem actualmente seleccionada.
  CarrisStopSearchResult? _selectedStop;

  /// Resultados da pesquisa de paragens.
  List<CarrisStopSearchResult> _searchResults = [];

  /// Lista de partidas próximas para a paragem seleccionada.
  List<CarrisUpcomingDeparture> _departures = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==================== SEARCH STOPS ====================

  /// Pesquisa por paragens Carris com base na query do utilizador.
  ///
  /// - Ignora queries com menos de 2 caracteres.
  /// - Actualiza [_searchResults] com o resultado do backend.
  Future<void> _performSearch() async {
    final q = _searchController.text.trim();
    debugPrint('[CARRIS PAGE] _performSearch("$q")');

    if (q.length < 2) {
      setState(() {
        _searchQuery = q;
        _searchResults = [];
      });
      debugPrint('[CARRIS PAGE] query muito curta, a sair.');
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
        '[CARRIS PAGE] _performSearch -> ${results.length} paragens encontradas.',
      );
    } catch (e) {
      debugPrint('[CARRIS PAGE] _performSearch ERROR: $e');
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

  /// Handler chamado quando o utilizador selecciona uma paragem.
  ///
  /// - Guarda a paragem em [_selectedStop].
  /// - Preenche o campo de texto com o nome da paragem.
  /// - Dispara o carregamento de partidas via [_loadDepartures].
  void _onSelectStop(CarrisStopSearchResult stop) {
    debugPrint('[CARRIS PAGE] _onSelectStop -> ${stop.name} (${stop.gtfsId})');
    setState(() {
      _selectedStop = stop;
      _searchResults = [];
      _searchController.text = stop.name;
    });
    _loadDepartures();
  }

  // ===================== LOAD DEPARTURES =====================

  /// Carrega as próximas partidas (upcoming departures) para a paragem seleccionada.
  Future<void> _loadDepartures() async {
    if (_selectedStop == null) {
      debugPrint('[CARRIS PAGE] _loadDepartures sem paragem selecionada');
      return;
    }

    debugPrint(
      '[CARRIS PAGE] _loadDepartures -> stop=${_selectedStop!.gtfsId}',
    );

    setState(() {
      _loadingDepartures = true;
      _error = null;
    });

    try {
      final deps = await _api.getUpcomingDepartures(
        stopGtfsId: _selectedStop!.gtfsId,
        limit: 40,
      );
      setState(() {
        _departures = deps;
      });
      debugPrint(
        '[CARRIS PAGE] _loadDepartures -> ${deps.length} partidas carregadas.',
      );
    } catch (e) {
      debugPrint('[CARRIS PAGE] _loadDepartures ERROR: $e');
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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _carrisYellow,
        foregroundColor: Colors.black,
        title: const Text('Horários Carris'),
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

                    // ==== SEARCH POR PARAGEM ====
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: (_) => _performSearch(),
                        decoration: InputDecoration(
                          hintText: 'Procurar paragem Carris...',
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
                                              Colors.black),
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

                    // ==== RESULTADOS DA PESQUISA DE PARAGENS ====
                    if (_searchResults.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: t.colorScheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _searchResults.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final stop = _searchResults[index];
                              return ListTile(
                                dense: true,
                                title: Text(stop.name),
                                subtitle: (stop.lat != null && stop.lon != null)
                                    ? Text(
                                        '(${stop.lat!.toStringAsFixed(4)}, ${stop.lon!.toStringAsFixed(4)})',
                                        style: t.textTheme.bodySmall?.copyWith(
                                          color: t.hintColor,
                                        ),
                                      )
                                    : null,
                                onTap: () => _onSelectStop(stop),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // ==== LISTA DE PARTIDAS ====
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: _buildDeparturesSection(context),
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

  /// Constrói a secção com as partidas da paragem seleccionada,
  /// incluindo mensagens de estado (erro, sem paragem, sem partidas).
  Widget _buildDeparturesSection(BuildContext context) {
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
            'Procura uma paragem Carris e seleciona-a para veres as próximas partidas.',
            textAlign: TextAlign.center,
            style: t.textTheme.bodyMedium,
          ),
        ),
      );
    }

    if (_loadingDepartures && _departures.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_carrisYellow),
          ),
        ),
      );
    }

    if (_departures.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          child: Text(
            'Não foram encontradas partidas próximas para esta paragem.',
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
          itemCount: _departures.length,
          itemBuilder: (context, index) {
            final row = _departures[index];

            final departure = Departure(
              time: row.timeLabel,
              destination: row.destinationLabel,
              line: row.lineLabel,
              platform: '—',
              operator: 'Carris',
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DepartureCard(
                departure: departure,
                accentColor: _carrisYellow,
              ),
            );
          },
        ),

        if (_loadingDepartures)
          const Positioned(
            right: 16,
            top: 0,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_carrisYellow),
              ),
            ),
          ),
      ],
    );
  }
}
