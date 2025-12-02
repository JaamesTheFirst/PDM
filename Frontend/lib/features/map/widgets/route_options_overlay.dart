import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:provider/provider.dart';

import '../../../../services/mapbox_directions_service.dart';
import '../../../../services/mapbox_searchbox_service.dart';
import '../../../../services/eco_score_service.dart';
import '../../../../services/routes_service.dart';
import 'package:sustainable_transport_app/utils/polyline_decoder.dart';
import '../state/otp_routes_controller.dart';

/// ============= ARGS =============
class RouteOptionsArgs {
  final mbx.MapboxMap mapboxMap;
  final SearchboxPlace from;
  final SearchboxPlace to;
  final RouteFilters? filters;
  RouteOptionsArgs({
    required this.mapboxMap,
    required this.from,
    required this.to,
    this.filters,
  });
}

class RouteOptionsOverlay extends StatefulWidget {
  final mbx.MapboxMap mapboxMap;
  final SearchboxPlace from;
  final SearchboxPlace to;
  final VoidCallback onClose;
  final RouteFilters? filters;

  const RouteOptionsOverlay({
    super.key,
    required this.mapboxMap,
    required this.from,
    required this.to,
    required this.onClose,
    this.filters,
  });

  @override
  State<RouteOptionsOverlay> createState() => _RouteOptionsOverlayState();
}

class _RouteData {
  final List<List<num>> geometry;
  final double distance; // m
  final double duration; // s
  _RouteData({required this.geometry, required this.distance, required this.duration});
}

class _RouteOptionsOverlayState extends State<RouteOptionsOverlay> {
  static const _ecoMint = Color(0xFF3CD4A0);

  // desenho no mapa
  mbx.PolylineAnnotationManager? _lineMgr;
  mbx.PolylineAnnotation? _routeLine;
  mbx.CircleAnnotationManager? _poiMgr;
  mbx.CircleAnnotation? _fromDot;
  mbx.CircleAnnotation? _toDot;

  // estado de modo
  String _selected = 'walking';
  bool _loading = false;

  // cache de rotas por modo
  final Map<String, _RouteData> _cache = {};
  late final OtpRoutesController _otpController;
  int? _lastDrawnOtpIndex;

  /// quanto o painel está "colapsado".
  /// 0 = expandido ao máximo; valor maior = painel mais baixo (mais mapa visível em cima).
  double _collapse = 0.0;

  /// Percentagem do colapso a partir da qual fazemos snap para o modo compacto
  static const double _snapThresholdRatio = 0.55;

  @override
  void initState() {
    super.initState();
    _otpController = context.read<OtpRoutesController>();
    _otpController.addListener(_handleOtpSelectionChange);
    _ensureDots();
    _selectMode('walking', draw: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchOtp());
  }
  bool _requestedOtp = false;

  Future<void> _fetchOtp() async {
    if (_requestedOtp) {
      print('[RouteOptionsOverlay] _fetchOtp: Already requested, skipping');
      return;
    }
    print('[RouteOptionsOverlay] _fetchOtp: Starting fetch');
    print('[RouteOptionsOverlay] From: ${widget.from.latitude}, ${widget.from.longitude}');
    print('[RouteOptionsOverlay] To: ${widget.to.latitude}, ${widget.to.longitude}');
    _requestedOtp = true;
    await _otpController.fetch(
      fromLat: widget.from.latitude,
      fromLon: widget.from.longitude,
      toLat: widget.to.latitude,
      toLon: widget.to.longitude,
      filters: widget.filters,
    );
    print('[RouteOptionsOverlay] _fetchOtp: Fetch complete, drawing itinerary');
    await _drawSelectedOtpItinerary();
  }

  @override
  void dispose() {
    _otpController.removeListener(_handleOtpSelectionChange);
    // Don't call clear() here - it triggers notifyListeners during dispose
    // The controller will be reused for the next route search
    super.dispose();
  }

  void _handleOtpSelectionChange() {
    final index = _otpController.selectedIndex;
    if (index == null || index == _lastDrawnOtpIndex) return;
    _drawSelectedOtpItinerary();
  }

  Future<void> _drawSelectedOtpItinerary() async {
    final index = _otpController.selectedIndex;
    if (index == null) return;
    final itineraries = _otpController.itineraries;
    if (index < 0 || index >= itineraries.length) return;

    final itinerary = itineraries[index];
    final coords = <List<num>>[];

    for (var legIdx = 0; legIdx < itinerary.legs.length; legIdx++) {
      final leg = itinerary.legs[legIdx];
      if (leg.polyline == null || leg.polyline!.isEmpty) continue;
      final decoded = decodePolyline(leg.polyline!);
      for (var pt = 0; pt < decoded.length; pt++) {
        if (pt == 0 && coords.isNotEmpty) continue;
        final lat = decoded[pt][0];
        final lon = decoded[pt][1];
        coords.add([lon, lat]);
      }
    }

    if (coords.isEmpty) return;

    final totalDistance =
        itinerary.legs.fold<double>(0, (sum, leg) => sum + leg.distance);

    await _drawRoute(
      _RouteData(
        geometry: coords,
        distance: totalDistance,
        duration: itinerary.duration.toDouble(),
      ),
    );
    await _fitRouteGeometry(coords);
    _lastDrawnOtpIndex = index;
  }

  Future<void> _ensureDots() async {
    _poiMgr ??= await widget.mapboxMap.annotations.createCircleAnnotationManager();
    try {
      await _poiMgr!.deleteAll();
    } catch (_) {}
    _fromDot = await _poiMgr!.create(
      mbx.CircleAnnotationOptions(
        geometry: mbx.Point(
          coordinates: mbx.Position(widget.from.longitude, widget.from.latitude),
        ),
        circleRadius: 7,
        circleColor: 0xFF1C1C1C,
        circleStrokeColor: 0xFFFFFFFF,
        circleStrokeWidth: 2,
      ),
    );
    _toDot = await _poiMgr!.create(
      mbx.CircleAnnotationOptions(
        geometry: mbx.Point(
          coordinates: mbx.Position(widget.to.longitude, widget.to.latitude),
        ),
        circleRadius: 7,
        circleColor: _ecoMint.value,
        circleStrokeColor: 0xFFFFFFFF,
        circleStrokeWidth: 2,
      ),
    );
  }

  /// Ajusta a câmara para encaixar a geometria da rota (mostra De + Para).
  Future<void> _fitRouteGeometry(List<List<num>> geometry) async {
    if (geometry.isEmpty) return;

    final points = geometry
        .map(
          (c) => mbx.Point(
            coordinates: mbx.Position(
              (c[0]).toDouble(),
              (c[1]).toDouble(),
            ),
          ),
        )
        .toList();

    final padding = mbx.MbxEdgeInsets(
      top: 40,
      left: 40,
      right: 40,
      bottom: 40,
    );

    try {
      final cam = await widget.mapboxMap.cameraForCoordinates(
        points,
        padding,
        0,
        0,
      );
      await widget.mapboxMap.flyTo(
        cam,
        mbx.MapAnimationOptions(duration: 900),
      );
    } catch (_) {}
  }

  Future<void> _selectMode(String mode, {bool draw = false}) async {
    setState(() {
      _selected = mode;
      _loading = true;
    });

    _RouteData data;
    if (_cache.containsKey(mode)) {
      data = _cache[mode]!;
    } else {
      final profile = (mode == 'scooter' || mode == 'bike_share' || mode == 'scooter_share')
          ? 'cycling'
          : (mode == 'taxi' ? 'driving' : mode);
      final r = await MapboxDirectionsService.instance.getRoute(
        fromLon: widget.from.longitude,
        fromLat: widget.from.latitude,
        toLon: widget.to.longitude,
        toLat: widget.to.latitude,
        profile: profile,
      );
      if (r == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }
      data = _RouteData(
        geometry: r.geometry,
        distance: r.distance.toDouble(),
        duration: r.duration.toDouble(),
      );
      _cache[mode] = data;
    }

    if (draw) {
      await _drawRoute(data);
      await _fitRouteGeometry(data.geometry);
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _drawRoute(_RouteData route) async {
    _lineMgr ??= await widget.mapboxMap.annotations.createPolylineAnnotationManager();
    try {
      if (_routeLine != null) await _lineMgr!.delete(_routeLine!);
    } catch (_) {}
    _routeLine = await _lineMgr!.create(
      mbx.PolylineAnnotationOptions(
        geometry: mbx.LineString(
          coordinates: route.geometry
              .map((c) => mbx.Position((c[0]).toDouble(), (c[1]).toDouble()))
              .toList(),
        ),
        lineColor: _ecoMint.value,
        lineWidth: 5.0,
      ),
    );
  }

  String _fmt(double meters) =>
      meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(1)} km';
  String _fmtDur(double seconds) => '${(seconds / 60).round()} min';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final media = MediaQuery.of(context);
    final bottomInset = media.padding.bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;

        // altura mínima do painel (header + 1 modo + botões)
        const double minPanelHeight = 230.0;

        // altura máxima (painel quase cheio)
        final double maxPanelHeight = maxH;

        // quanto é que o painel pode "colapsar" no máximo
        final double maxCollapse = (maxPanelHeight - minPanelHeight).clamp(0.0, maxH);

        // aplica clamp ao _collapse
        final double effectiveCollapse = _collapse.clamp(0.0, maxCollapse);

        final double panelHeight = maxPanelHeight - effectiveCollapse;

        // limiar real em px para snap + "modo compacto"
        final double snapThreshold = maxCollapse * _snapThresholdRatio;

        return Container(
          color: Colors.transparent,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: panelHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: t.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 24,
                    offset: Offset(0, -4),
                    color: Color(0x26000000),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset + 12),
                child: Column(
                  children: [
                    // handle + drag
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragUpdate: (d) {
                        setState(() {
                          _collapse += d.delta.dy;
                          if (_collapse < 0) _collapse = 0;
                          if (_collapse > maxCollapse) _collapse = maxCollapse;
                        });
                      },
                      onVerticalDragEnd: (_) {
                        // SNAP: decide se fica expandido ou compacto
                        if (maxCollapse <= 0) return;
                        setState(() {
                          if (_collapse < snapThreshold) {
                            _collapse = 0; // expandido, mostra lista inteira
                          } else {
                            _collapse = maxCollapse; // compacto, só 1 item
                          }
                        });
                      },
                      child: SizedBox(
                        height: 40,
                        child: Center(
                          child: Container(
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              color: t.colorScheme.onSurface.withOpacity(.25),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // header + fechar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: Row(
                        children: [
                          const Icon(Icons.route, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${widget.from.name} → ${widget.to.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: widget.onClose,
                            icon: const Icon(Icons.close),
                            tooltip: 'Fechar',
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const _OtpItinerariesPanel(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ações no fundo
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: widget.onClose,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: t.colorScheme.onSurface,
                                side: BorderSide(
                                  color: t.colorScheme.onSurface.withOpacity(.2),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              child: const Text('Fechar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: widget.onClose,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _ecoMint,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              child: const Text(
                                'Aplicar & fechar',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

}

class _OtpItinerariesPanel extends StatelessWidget {
  const _OtpItinerariesPanel();

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  /// Get icon for primary transport mode
  IconData _getIconForMode(OtpItinerary itinerary) {
    // Find the primary (non-walking) mode
    for (final leg in itinerary.legs) {
      final mode = leg.mode.toUpperCase();
      if (mode != 'WALK' && mode != 'WALKING') {
        if (mode == 'CAR' || mode.contains('CAR')) {
          return Icons.directions_car;
        } else if (mode == 'BICYCLE' || mode == 'BIKE' || mode.contains('BIKE')) {
          return Icons.directions_bike;
        } else if (mode.contains('RAIL') || mode.contains('TRAIN') || mode == 'R' || mode == 'IC') {
          return Icons.train;
        } else if (mode.contains('BUS') || mode == 'COACH' || mode == 'FLIXBUS') {
          return Icons.directions_bus;
        } else if (mode.contains('METRO') || mode.contains('SUBWAY')) {
          return Icons.subway;
        } else if (mode.contains('TRAM')) {
          return Icons.tram;
        } else if (mode == 'TRANSIT') {
          return Icons.directions_transit;
        }
      }
    }
    // Default to walking if all legs are walking
    return Icons.directions_walk;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Consumer<OtpRoutesController>(
      builder: (_, controller, __) {
          
          if (controller.isLoading) {
          return _TransitCardBase(
            child: Row(
              children: const [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('A calcular itinerários de transporte público...'),
              ],
            ),
          );
        }

        if (controller.error != null) {
          return _TransitCardBase(
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.redAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Erro ao obter rotas OTP: ${controller.error}',
                    style: t.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          );
        }

        // Sort itineraries by eco-score (highest to lowest)
        final itineraries = List<OtpItinerary>.from(controller.itineraries);
        itineraries.sort((a, b) {
          final scoreA = EcoScoreService.instance.calculateScore(a).score;
          final scoreB = EcoScoreService.instance.calculateScore(b).score;
          return scoreB.compareTo(scoreA); // Descending order (highest first)
        });
        
        if (itineraries.isEmpty) {
          return _TransitCardBase(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.info_outline),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Sem itinerários disponíveis para este trajeto.',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'OTP não encontrou rotas de transporte público para esta ligação. Tenta outro destino ou verifica se há cobertura de transportes nesta área.',
                  style: t.textTheme.bodySmall?.copyWith(
                    color: t.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rotas de transporte público',
              style: t.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${itineraries.length} opções disponíveis',
              style: t.textTheme.bodySmall?.copyWith(
                color: t.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: itineraries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                return _ExpandableRouteCard(
                  itinerary: itineraries[index],
                  index: index,
                  controller: controller,
                  getIconForMode: _getIconForMode,
                  formatTime: _formatTime,
                );
              },
            ),
            ),
          ],
        );
      },
    );
  }
}

class _ExpandableRouteCard extends StatefulWidget {
  final OtpItinerary itinerary;
  final int index;
  final OtpRoutesController controller;
  final IconData Function(OtpItinerary) getIconForMode;
  final String Function(DateTime) formatTime;

  const _ExpandableRouteCard({
    required this.itinerary,
    required this.index,
    required this.controller,
    required this.getIconForMode,
    required this.formatTime,
  });

  @override
  State<_ExpandableRouteCard> createState() => _ExpandableRouteCardState();
}

class _ExpandableRouteCardState extends State<_ExpandableRouteCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final itinerary = widget.itinerary;
    final selected = widget.controller.selectedIndex == widget.index;
    final durationMin = (itinerary.duration / 60).round();
    final legsSummary = itinerary.legs
        .map((leg) => leg.routeName ?? leg.mode)
        .join(' • ');
    final walkKm = itinerary.walkDistance / 1000.0;
    
    // Calculate Eco Score
    final ecoScore = EcoScoreService.instance.calculateScore(itinerary);
    final scoreColor = Color(EcoScoreService.instance.getScoreColor(ecoScore.score));

    return GestureDetector(
      onTap: () => widget.controller.selectItinerary(widget.index),
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? _RouteOptionsOverlayState._ecoMint.withOpacity(0.15)
              : t.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? _RouteOptionsOverlayState._ecoMint
                : t.colorScheme.onSurface.withOpacity(.1),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(widget.getIconForMode(itinerary), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.formatTime(itinerary.startTime)} – ${widget.formatTime(itinerary.endTime)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$durationMin min'),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              legsSummary,
              style: t.textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                // Eco Score badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scoreColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        ecoScore.hasPhysicalActivity 
                            ? Icons.fitness_center 
                            : Icons.eco,
                        size: 14,
                        color: scoreColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Eco: ${ecoScore.score}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scoreColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // CO2 badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: t.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    EcoScoreService.instance.formatCo2PerKm(ecoScore.co2PerKm),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: t.colorScheme.onSurface.withOpacity(0.9),
                    ),
                  ),
                ),
                const Spacer(),
                // Walking distance
                Text(
                  '${walkKm.toStringAsFixed(1)} km a pé',
                  style: t.textTheme.bodySmall,
                ),
              ],
            ),
            // Expanded details
            if (_isExpanded) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              ...itinerary.legs.map((leg) {
                final legDurationMin = (leg.duration / 60).round();
                final legDistanceKm = leg.distance / 1000.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _getLegIcon(leg.mode),
                        size: 16,
                        color: t.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              leg.routeName ?? leg.mode,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${leg.fromName} → ${leg.toName}',
                              style: t.textTheme.bodySmall,
                            ),
                            Text(
                              '$legDurationMin min • ${legDistanceKm.toStringAsFixed(1)} km',
                              style: t.textTheme.bodySmall?.copyWith(
                                color: t.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getLegIcon(String mode) {
    final m = mode.toUpperCase();
    if (m == 'WALK' || m == 'WALKING') return Icons.directions_walk;
    if (m == 'CAR' || m.contains('CAR')) return Icons.directions_car;
    if (m == 'BICYCLE' || m == 'BIKE' || m.contains('BIKE')) return Icons.directions_bike;
    if (m.contains('RAIL') || m.contains('TRAIN') || m == 'R' || m == 'IC') return Icons.train;
    if (m.contains('BUS') || m == 'COACH' || m == 'FLIXBUS') return Icons.directions_bus;
    if (m.contains('METRO') || m.contains('SUBWAY')) return Icons.subway;
    if (m.contains('TRAM')) return Icons.tram;
    return Icons.directions_transit;
  }
}

class _TransitCardBase extends StatelessWidget {
  final Widget child;
  const _TransitCardBase({required this.child});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: t.colorScheme.primaryContainer.withOpacity(0.35),
      ),
      child: child,
    );
  }
}
