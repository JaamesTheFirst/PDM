// lib/features/schedules/pages/flixbus_schedules_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../widgets/departure_card.dart';
import '../data/flixbus_api.dart';

class FlixbusSchedulesPage extends StatefulWidget {
  const FlixbusSchedulesPage({super.key});

  @override
  State<FlixbusSchedulesPage> createState() => _FlixbusSchedulesPageState();
}

class _FlixbusSchedulesPageState extends State<FlixbusSchedulesPage> {
  static const _flixbusGreen = Color(0xFF73BF15);

  final FlixbusApiClient _api = FlixbusApiClient();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = false;
  String? _error;

  List<FlixbusRoute> _allRoutes = [];
  List<FlixbusRoute> _pageRoutes = [];
  List<FlixbusRoute> _visibleRoutes = [];

  int _limit = 20;
  int _currentPage = 1;
  int _totalPages = 1;

  bool _showCalendar = false;
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _searchController.addListener(_applyLocalFilter);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyLocalFilter);
    _searchController.dispose();
    super.dispose();
  }

  // ==================== LOAD ROUTES + PAGINAÇÃO ====================

  Future<void> _loadRoutes() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final routes = await _api.getRoutes();
      _allRoutes = routes;
      _currentPage = 1;
      _rebuildPagination();
      debugPrint(
          '[FLIXBUS PAGE] carregadas ${routes.length} linhas FlixBus.');
    } catch (e) {
      debugPrint('[FLIXBUS PAGE] _loadRoutes ERROR: $e');
      setState(() {
        _error = e.toString();
        _allRoutes = [];
        _pageRoutes = [];
        _visibleRoutes = [];
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _rebuildPagination() {
    final total = _allRoutes.length;
    _totalPages = _limit > 0 ? ((total + _limit - 1) ~/ _limit) : 1;
    if (_totalPages == 0) _totalPages = 1;
    if (_currentPage > _totalPages) _currentPage = _totalPages;
    _updatePageRoutes();
    _applyLocalFilter();
  }

  void _updatePageRoutes() {
    final total = _allRoutes.length;
    final start = (_currentPage - 1) * _limit;
    if (start >= total) {
      _pageRoutes = [];
      return;
    }
    final end = (start + _limit) > total ? total : (start + _limit);
    _pageRoutes = _allRoutes.sublist(start, end);
  }

  void _goToPreviousPage() {
    if (_currentPage <= 1 || _loading) return;
    setState(() {
      _currentPage -= 1;
      _updatePageRoutes();
      _applyLocalFilter();
    });
  }

  void _goToNextPage() {
    if (_currentPage >= _totalPages || _loading) return;
    setState(() {
      _currentPage += 1;
      _updatePageRoutes();
      _applyLocalFilter();
    });
  }

  // ==================== SEARCH LOCAL POR LINHA ====================

  String _normalize(String input) {
    const mapping = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'Á': 'a',
      'À': 'a',
      'Â': 'a',
      'Ã': 'a',
      'Ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'É': 'e',
      'È': 'e',
      'Ê': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'Í': 'i',
      'Ì': 'i',
      'Î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'Ó': 'o',
      'Ò': 'o',
      'Ô': 'o',
      'Õ': 'o',
      'Ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'Ú': 'u',
      'Ù': 'u',
      'Û': 'u',
      'Ü': 'u',
      'ç': 'c',
      'Ç': 'c',
    };

    final buffer = StringBuffer();
    for (final ch in input.characters) {
      buffer.write(mapping[ch] ?? ch);
    }
    return buffer.toString().toLowerCase();
  }

  void _applyLocalFilter() {
    final raw = _searchController.text.trim();
    final q = _normalize(raw);

    setState(() {
      if (q.isEmpty) {
        _visibleRoutes = List.from(_pageRoutes);
      } else {
        _visibleRoutes = _pageRoutes.where((r) {
          final shortNorm = _normalize(r.shortName ?? '');
          final longNorm = _normalize(r.longName ?? '');
          final agencyNorm = _normalize(r.agencyName ?? '');
          return shortNorm.contains(q) ||
              longNorm.contains(q) ||
              agencyNorm.contains(q);
        }).toList();
      }
    });
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

  // ============================ UI ============================

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _flixbusGreen,
        foregroundColor: Colors.white,
        title: const Text('Horários FlixBus'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // ==== SEARCH POR LINHA / CIDADE ====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Procurar linha / cidade (ex. 501, Covilha)...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _applyLocalFilter();
                          },
                        )
                      : null,
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

            // ==== SELECTOR DE DIA (GLOBAL, ACIMA DAS SETAS) ====
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
                    color: _flixbusGreen,
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
                      primary: _flixbusGreen,
                      onPrimary: Colors.white,
                      surface: t.colorScheme.surface,
                      onSurface: t.colorScheme.onSurface,
                    ),
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        foregroundColor: _flixbusGreen,
                      ),
                    ),
                  ),
                  child: CalendarDatePicker(
                    initialDate: _selectedDay,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 7)),
                    lastDate:
                        DateTime.now().add(const Duration(days: 60)),
                    onDateChanged: (date) {
                      setState(() {
                        _selectedDay = date;
                      });
                    },
                  ),
                ),
              ),
              crossFadeState: _showCalendar
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),

            const SizedBox(height: 8),

            // ==== PAGINAÇÃO ====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      t.colorScheme.surfaceVariant.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new),
                      iconSize: 18,
                      onPressed: (_currentPage > 1 && !_loading)
                          ? _goToPreviousPage
                          : null,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Página $_currentPage / $_totalPages',
                            style: t.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _allRoutes.isEmpty
                                ? 'Sem linhas carregadas'
                                : '${_allRoutes.length} linhas FlixBus',
                            style: t.textTheme.bodySmall?.copyWith(
                              color: t.hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios),
                      iconSize: 18,
                      onPressed:
                          (_currentPage < _totalPages && !_loading)
                              ? _goToNextPage
                              : null,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: _buildBody(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final t = Theme.of(context);

    if (_loading && _allRoutes.isEmpty && _error == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor:
              AlwaysStoppedAnimation<Color>(_flixbusGreen),
        ),
      );
    }

    if (_error != null && _allRoutes.isEmpty) {
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

    if (_visibleRoutes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Text(
            _allRoutes.isEmpty
                ? 'Não foram encontradas linhas FlixBus.'
                : 'Nenhuma linha nesta página corresponde ao filtro.',
            textAlign: TextAlign.center,
            style: t.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: _visibleRoutes.length,
          itemBuilder: (context, index) {
            final r = _visibleRoutes[index];

            final title = (r.shortName != null && r.shortName!.isNotEmpty)
                ? 'Linha ${r.shortName}'
                : (r.longName ?? 'Linha sem nome');

            final subtitleParts = <String>[];
            if (r.longName != null && r.longName!.isNotEmpty) {
              subtitleParts.add(r.longName!);
            }
            if (r.agencyName != null && r.agencyName!.isNotEmpty) {
              subtitleParts.add(r.agencyName!);
            }

            final subtitle =
                subtitleParts.isEmpty ? null : subtitleParts.join(' · ');

            return InkWell(
              onTap: () => _openRouteDetailSheet(r),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      _flixbusGreen.withOpacity(0.16),
                      t.colorScheme.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // sem “ícone” quadrado, só texto
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: t.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios, size: 18),
                  ],
                ),
              ),
            );
          },
        ),

        if (_loading && _allRoutes.isNotEmpty)
          Positioned(
            right: 16,
            top: 12,
            child: SizedBox(
              width: 20,
              height: 20,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(_flixbusGreen),
              ),
            ),
          ),
      ],
    );
  }

  // ==================== BOTTOM SHEET DETALHE DA LINHA ====================

  void _openRouteDetailSheet(FlixbusRoute route) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return _FlixbusRouteDetailSheet(
              route: route,
              api: _api,
              scrollController: scrollController,
              selectedDay: _selectedDay, // usa o dia escolhido na página
            );
          },
        );
      },
    );
  }
}

// ===================================================================
//  SHEET COM PARAGENS + HORÁRIOS (POR LINHA)
// ===================================================================

class _FlixbusRouteDetailSheet extends StatefulWidget {
  final FlixbusRoute route;
  final FlixbusApiClient api;
  final ScrollController scrollController;
  final DateTime selectedDay;

  const _FlixbusRouteDetailSheet({
    required this.route,
    required this.api,
    required this.scrollController,
    required this.selectedDay,
  });

  @override
  State<_FlixbusRouteDetailSheet> createState() =>
      _FlixbusRouteDetailSheetState();
}

class _FlixbusRouteDetailSheetState
    extends State<_FlixbusRouteDetailSheet> {
  static const _flixbusGreen = Color(0xFF73BF15);

  bool _loadingDetail = true;
  String? _error;
  FlixbusRouteDetail? _detail;

  final Set<String> _openStops = {};
  final Map<String, List<FlixbusStopBoardRow>> _boardsByStop = {};
  String? _loadingStopId;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loadingDetail = true;
      _error = null;
    });

    try {
      final d = await widget.api.getRouteDetail(widget.route.gtfsId);
      setState(() {
        _detail = d;
      });
    } catch (e) {
      debugPrint('[FLIXBUS SHEET] _loadDetail ERROR: $e');
      setState(() {
        _error = e.toString();
        _detail = null;
      });
    } finally {
      setState(() {
        _loadingDetail = false;
      });
    }
  }

  Future<void> _toggleStopBoard(FlixbusStopBasic stop) async {
    final stopId = stop.gtfsId;

    if (_openStops.contains(stopId)) {
      setState(() {
        _openStops.remove(stopId);
      });
      return;
    }

    setState(() {
      _loadingStopId = stopId;
      _error = null;
    });

    try {
      final board = await widget.api.getStopBoard(
        stopGtfsId: stopId,
        day: widget.selectedDay, // usa o dia vindo da página
      );

      // filtra só partidas desta linha
      final filtered = board.departures
          .where((row) => row.routeGtfsId == widget.route.gtfsId)
          .toList();

      setState(() {
        _boardsByStop[stopId] = filtered;
        _openStops.add(stopId);
      });
    } catch (e) {
      debugPrint('[FLIXBUS SHEET] _toggleStopBoard ERROR: $e');
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loadingStopId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: t.dividerColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),

            // HEADER sem ícone
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.route.longName ??
                        'Linha FlixBus ${widget.route.shortName ?? ''}',
                    style: t.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.route.agencyName != null)
                    Text(
                      widget.route.agencyName!,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: t.hintColor,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Dia selecionado: '
                    '${MaterialLocalizations.of(context).formatFullDate(widget.selectedDay)}',
                    style: t.textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: t.textTheme.bodySmall?.copyWith(
                    color: Colors.redAccent,
                  ),
                ),
              ),

            Expanded(
              child: _buildStopsList(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStopsList(BuildContext context) {
    final t = Theme.of(context);

    if (_loadingDetail) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor:
              AlwaysStoppedAnimation<Color>(_flixbusGreen),
        ),
      );
    }

    final detail = _detail;
    if (detail == null || detail.stops.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Text(
            'Não foram encontradas paragens para esta linha.',
            textAlign: TextAlign.center,
            style: t.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: detail.stops.length,
      itemBuilder: (context, index) {
        final stop = detail.stops[index];
        final isOpen = _openStops.contains(stop.gtfsId);
        final rows = _boardsByStop[stop.gtfsId];

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: t.colorScheme.surfaceVariant.withOpacity(0.3),
          ),
          child: Column(
            children: [
              ListTile(
                title: Text(
                  stop.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: (stop.lat != null && stop.lon != null)
                    ? Text(
                        '(${stop.lat!.toStringAsFixed(4)}, ${stop.lon!.toStringAsFixed(4)})',
                        style: t.textTheme.bodySmall
                            ?.copyWith(color: t.hintColor),
                      )
                    : null,
                trailing: _loadingStopId == stop.gtfsId
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              _flixbusGreen),
                        ),
                      )
                    : Icon(
                        isOpen
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),
                onTap: () => _toggleStopBoard(stop),
              ),
              if (isOpen)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: (rows == null || rows.isEmpty)
                      ? Text(
                          'Sem partidas desta linha nesta paragem para o dia selecionado.',
                          style: t.textTheme.bodySmall,
                        )
                      : Column(
                          children: rows.map((row) {
                            final departure = Departure(
                              time: row.time,
                              destination: row.destination ?? '—',
                              line: row.lineShortName ??
                                  row.lineLongName ??
                                  '',
                              platform: '—',
                              operator: 'FlixBus',
                            );
                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 8),
                              child: DepartureCard(
                                departure: departure,
                                accentColor: _flixbusGreen,
                              ),
                            );
                          }).toList(),
                        ),
                ),
            ],
          ),
        );
      },
    );
  }
}
