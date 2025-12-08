// lib/features/map/widgets/route_options_overlay.dart

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:provider/provider.dart';

import '../../../../services/mapbox_directions_service.dart';
import '../../../../services/mapbox_searchbox_service.dart';
import '../../../../services/eco_score_service.dart';
import '../../../../services/history_service.dart';
import '../../../../services/routes_service.dart'; // OtpItinerary + RouteFilters
import 'package:sustainable_transport_app/utils/polyline_decoder.dart';
import '../state/otp_routes_controller.dart';
import '../state/navigation_controller.dart';
import '../pages/navigation_map_page.dart';

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
  _RouteData({
    required this.geometry,
    required this.distance,
    required this.duration,
  });
}

class _RouteOptionsOverlayState extends State<RouteOptionsOverlay> {
  static const _ecoMint = Color(0xFF3CD4A0);

  // desenho no mapa
  mbx.PolylineAnnotationManager? _lineMgr;
  mbx.PolylineAnnotation? _routeLine; // Selected route
  final List<mbx.PolylineAnnotation> _allRouteLines = [];
  mbx.CircleAnnotationManager? _poiMgr;
  mbx.CircleAnnotation? _fromDot;
  mbx.CircleAnnotation? _toDot;

  // estado de modo (Mapbox directions)
  String _selected = 'walking';
  bool _loading = false;

  // guardar rota no backend / histórico
  bool _saving = false;

  // cache de rotas por modo (Mapbox Directions)
  final Map<String, _RouteData> _cache = {};
  late final OtpRoutesController _otpController;
  int? _lastDrawnOtpIndex;

  // ==== PANEL SNAPPING STATE ====
  double _panelHeight = 0;
  late double _snapFull;
  late double _snapExpanded;
  late double _snapDocked;
  static const double _minPanelHeight = 285.0; // ALTURA MÍNIMA -> evita overflow

  bool _requestedOtp = false;

  @override
  void initState() {
    super.initState();
    _otpController = context.read<OtpRoutesController>();
    _otpController.addListener(_handleOtpSelectionChange);
    _ensureDots();
    _selectMode('walking', draw: true);
    _clearPreviousRoutes();

    // calcular alturas do painel depois do layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final media = MediaQuery.of(context);
      final screenHeight = media.size.height;

      _snapFull = screenHeight; // 100% ecrã
      _snapExpanded = screenHeight * 0.60;
      _snapDocked = screenHeight * 0.25;

      // garantir que o docked nunca é menor que a altura mínima
      if (_snapDocked < _minPanelHeight) {
        _snapDocked = _minPanelHeight;
      }

      setState(() {
        // começar no estado "expanded", mas nunca abaixo da altura mínima
        _panelHeight = _snapExpanded.clamp(_snapDocked, _snapFull);
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchOtp());
  }

  @override
  void dispose() {
    _otpController.removeListener(_handleOtpSelectionChange);
    _clearPreviousRoutes();
    super.dispose();
  }

  Future<void> _clearPreviousRoutes() async {
    if (_lineMgr != null) {
      try {
        if (_routeLine != null) {
          await _lineMgr!.delete(_routeLine!);
          _routeLine = null;
        }
        for (final line in _allRouteLines) {
          try {
            await _lineMgr!.delete(line);
          } catch (e) {
            debugPrint('[RouteOptionsOverlay] Error deleting route line: $e');
          }
        }
        _allRouteLines.clear();
      } catch (e) {
        debugPrint('[RouteOptionsOverlay] Error clearing previous routes: $e');
      }
    }
    _lastDrawnOtpIndex = null;
    _requestedOtp = false;
  }

  Future<void> _fetchOtp() async {
    if (_requestedOtp) {
      debugPrint('[RouteOptionsOverlay] _fetchOtp: Already requested, skipping');
      return;
    }
    debugPrint('[RouteOptionsOverlay] _fetchOtp: Starting fetch');
    debugPrint(
      '[RouteOptionsOverlay] From: ${widget.from.latitude}, ${widget.from.longitude}',
    );
    debugPrint(
      '[RouteOptionsOverlay] To: ${widget.to.latitude}, ${widget.to.longitude}',
    );
    _requestedOtp = true;
    await _otpController.fetch(
      fromLat: widget.from.latitude,
      fromLon: widget.from.longitude,
      toLat: widget.to.latitude,
      toLon: widget.to.longitude,
      filters: widget.filters,
    );
    debugPrint(
      '[RouteOptionsOverlay] _fetchOtp: Fetch complete, drawing all routes',
    );
    await _drawAllOtpItineraries();
    await _drawSelectedOtpItinerary();
  }

  void _handleOtpSelectionChange() {
    final index = _otpController.selectedIndex;
    if (index == null || index == _lastDrawnOtpIndex) return;
    _drawSelectedOtpItinerary();
  }

  /// Desenhar todas as rotas OTP com cores diferentes
  Future<void> _drawAllOtpItineraries() async {
    final itineraries = _otpController.itineraries;
    if (itineraries.isEmpty) return;

    _lineMgr ??=
        await widget.mapboxMap.annotations.createPolylineAnnotationManager();

    for (final line in _allRouteLines) {
      try {
        await _lineMgr!.delete(line);
      } catch (e) {
        debugPrint('[RouteOptionsOverlay] Error deleting route line: $e');
      }
    }
    _allRouteLines.clear();

    final routeColors = [
      0xFF00D4FF,
      0xFF0066FF,
      0xFF8B00FF,
      0xFFFF6600,
      0xFFFF0066,
    ];

    for (var i = 0; i < itineraries.length; i++) {
      final itinerary = itineraries[i];
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

      if (coords.isEmpty) continue;

      final color = routeColors[i % routeColors.length];

      try {
        final routeLine = await _lineMgr!.create(
          mbx.PolylineAnnotationOptions(
            geometry: mbx.LineString(
              coordinates: coords
                  .map(
                    (c) =>
                        mbx.Position((c[0]).toDouble(), (c[1]).toDouble()),
                  )
                  .toList(),
            ),
            lineColor: color,
            lineWidth: 4.0,
            lineOpacity: 0.7,
          ),
        );
        _allRouteLines.add(routeLine);
      } catch (e) {
        debugPrint('[RouteOptionsOverlay] Error drawing route $i: $e');
      }
    }

    if (_allRouteLines.isNotEmpty) {
      final allCoords = <List<num>>[];
      for (final itinerary in itineraries) {
        for (final leg in itinerary.legs) {
          if (leg.polyline == null || leg.polyline!.isEmpty) continue;
          final decoded = decodePolyline(leg.polyline!);
          for (var pt = 0; pt < decoded.length; pt++) {
            final lat = decoded[pt][0];
            final lon = decoded[pt][1];
            allCoords.add([lon, lat]);
          }
        }
      }
      if (allCoords.isNotEmpty) {
        await _fitRouteGeometry(allCoords);
      }
    }
  }

  /// Desenhar rota selecionada com linha mais grossa
  Future<void> _drawSelectedOtpItinerary() async {
    final index = _otpController.selectedIndex;
    if (index == null) return;
    final itineraries = _otpController.itineraries;
    if (index < 0 || index >= itineraries.length) return;

    if (_routeLine != null) {
      try {
        await _lineMgr!.delete(_routeLine!);
      } catch (e) {
        debugPrint('[RouteOptionsOverlay] Error deleting selected route: $e');
      }
      _routeLine = null;
    }

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

    _lineMgr ??=
        await widget.mapboxMap.annotations.createPolylineAnnotationManager();

    try {
      _routeLine = await _lineMgr!.create(
        mbx.PolylineAnnotationOptions(
          geometry: mbx.LineString(
            coordinates: coords
                .map((c) => mbx.Position((c[0]).toDouble(), (c[1]).toDouble()))
                .toList(),
          ),
          lineColor: 0xFFFFFFFF,
          lineWidth: 7.0,
          lineOpacity: 1.0,
        ),
      );
    } catch (e) {
      debugPrint('[RouteOptionsOverlay] Error drawing selected route: $e');
    }

    _lastDrawnOtpIndex = index;
  }

  Future<void> _ensureDots() async {
    _poiMgr ??=
        await widget.mapboxMap.annotations.createCircleAnnotationManager();
    try {
      await _poiMgr!.deleteAll();
    } catch (_) {}

    _fromDot = await _poiMgr!.create(
      mbx.CircleAnnotationOptions(
        geometry: mbx.Point(
          coordinates: mbx.Position(
            widget.from.longitude,
            widget.from.latitude,
          ),
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

  Future<void> _fitRouteGeometry(List<List<num>> geometry) async {
    if (geometry.isEmpty) return;

    final points = geometry
        .map(
          (c) => mbx.Point(
            coordinates: mbx.Position((c[0]).toDouble(), (c[1]).toDouble()),
          ),
        )
        .toList();

    final padding =
        mbx.MbxEdgeInsets(top: 40, left: 40, right: 40, bottom: 40);

    try {
      final cam = await widget.mapboxMap.cameraForCoordinates(
        points,
        padding,
        0,
        0,
      );
      await widget.mapboxMap
          .flyTo(cam, mbx.MapAnimationOptions(duration: 900));
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
      final profile =
          (mode == 'scooter' || mode == 'bike_share' || mode == 'scooter_share')
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
    _lineMgr ??=
        await widget.mapboxMap.annotations.createPolylineAnnotationManager();

    try {
      if (_routeLine != null) {
        await _lineMgr!.delete(_routeLine!);
        _routeLine = null;
      }
      for (final line in _allRouteLines) {
        try {
          await _lineMgr!.delete(line);
        } catch (e) {
          debugPrint(
              '[RouteOptionsOverlay] Error deleting OTP route line: $e');
        }
      }
      _allRouteLines.clear();
    } catch (e) {
      debugPrint('[RouteOptionsOverlay] Error clearing OTP routes: $e');
    }

    try {
      _routeLine = await _lineMgr!.create(
        mbx.PolylineAnnotationOptions(
          geometry: mbx.LineString(
            coordinates: route.geometry
                .map((c) => mbx.Position((c[0]).toDouble(), (c[1]).toDouble()))
                .toList(),
          ),
          lineColor: 0xFF00D4FF,
          lineWidth: 5.0,
        ),
      );
    } catch (e) {
      debugPrint('[RouteOptionsOverlay] Error drawing Mapbox route: $e');
    }
  }

  String _fmt(double meters) =>
      meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(1)} km';
  String _fmtDur(double seconds) => '${(seconds / 60).round()} min';

  /// ====== BOTÃO "INICIAR NAVEGAÇÃO" ======
  Future<void> _onStartNavigation(BuildContext context) async {
    final controller = context.read<OtpRoutesController>();
    final navController = context.read<NavigationController>();
    final itineraries = controller.itineraries;

    if (itineraries.isEmpty) return;

    var index = controller.selectedIndex ?? 0;
    if (index < 0 || index >= itineraries.length) index = 0;

    final itinerary = itineraries[index];

    await navController.startNavigation(
      itinerary,
      destinationLat: widget.to.latitude,
      destinationLon: widget.to.longitude,
    );

    widget.onClose();

    if (context.mounted) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const NavigationMapPage()));
    }
  }

  /// ====== BOTÃO "APLICAR & FECHAR" ======
  Future<void> _onApplyAndSave(BuildContext context) async {
    final controller = context.read<OtpRoutesController>();
    final itineraries = controller.itineraries;

    if (itineraries.isEmpty) {
      widget.onClose();
      return;
    }

    var index = controller.selectedIndex ?? 0;
    if (index < 0 || index >= itineraries.length) index = 0;

    final itinerary = itineraries[index];

    final legsJson = itinerary.legs.map((leg) {
      double? fromLat;
      double? fromLon;
      double? toLat;
      double? toLon;

      if (leg.polyline != null && leg.polyline!.isNotEmpty) {
        final decoded = decodePolyline(leg.polyline!);
        if (decoded.isNotEmpty) {
          fromLat = (decoded.first[0]).toDouble();
          fromLon = (decoded.first[1]).toDouble();
          toLat = (decoded.last[0]).toDouble();
          toLon = (decoded.last[1]).toDouble();
        }
      }

      return {
        'mode': leg.mode,
        'duration': leg.duration,
        'distance': leg.distance,
        'startTime': leg.startTime.toIso8601String(),
        'endTime': leg.endTime.toIso8601String(),
        'from': {'name': leg.fromName, 'lat': fromLat, 'lon': fromLon},
        'to': {'name': leg.toName, 'lat': toLat, 'lon': toLon},
        'route': null,
        'legGeometry': {'points': leg.polyline},
      };
    }).toList();

    final itineraryJson = {
      'duration': itinerary.duration,
      'startTime': itinerary.startTime.toIso8601String(),
      'endTime': itinerary.endTime.toIso8601String(),
      'walkDistance': itinerary.walkDistance,
      'legs': legsJson,
    };

    final originLabel =
        widget.from.name.isNotEmpty ? widget.from.name : widget.from.placeName;
    final destinationLabel =
        widget.to.name.isNotEmpty ? widget.to.name : widget.to.placeName;

    final payload = {
      'itinerary': itineraryJson,
      'originName': originLabel,
      'originLatitude': widget.from.latitude,
      'originLongitude': widget.from.longitude,
      'destinationName': destinationLabel,
      'destinationLatitude': widget.to.latitude,
      'destinationLongitude': widget.to.longitude,
    };

    setState(() => _saving = true);
    try {
      await HistoryService.instance.saveRouteFromItinerary(payload);
    } catch (e) {
      debugPrint('[RouteOptionsOverlay] Error saving itinerary: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível guardar esta rota.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final media = MediaQuery.of(context);
    final bottomInset = media.padding.bottom;
    final screenHeight = media.size.height;

    return SizedBox(
      height: _panelHeight == 0 ? 1 : _panelHeight.clamp(0.0, screenHeight),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: _panelHeight == 0 ? 1 : _panelHeight.clamp(0.0, screenHeight),
          width: double.infinity,
          decoration: BoxDecoration(
            color: t.colorScheme.surface,
            borderRadius: _panelHeight >= _snapFull * 0.95
                ? BorderRadius.zero
                : const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: _panelHeight >= _snapFull * 0.95
                ? []
                : const [
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
                  onVerticalDragUpdate: (details) {
                    setState(() {
                      _panelHeight -= details.delta.dy;
                      _panelHeight = _panelHeight.clamp(_snapDocked, _snapFull);
                    });
                  },
                  onVerticalDragEnd: (_) {
                    final targets = [_snapDocked, _snapExpanded, _snapFull];
                    final nearest = targets.reduce(
                      (a, b) => (_panelHeight - a).abs() <
                              (_panelHeight - b).abs()
                          ? a
                          : b,
                    );
                    setState(() => _panelHeight = nearest);
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
                        onPressed: _saving ? null : widget.onClose,
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

                // Start Navigation button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _saving ? null : () => _onStartNavigation(context),
                      icon: const Icon(Icons.navigation, size: 20),
                      label: const Text(
                        'Iniciar Navegação',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.colorScheme.primary,
                        foregroundColor: t.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                    ),
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
                          onPressed: _saving ? null : widget.onClose,
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
                          onPressed:
                              _saving ? null : () => _onApplyAndSave(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _ecoMint,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Text(
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
  }
}

// ======================= LISTA DE ITINERÁRIOS =======================

class _OtpItinerariesPanel extends StatelessWidget {
  const _OtpItinerariesPanel();

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  IconData _getIconForMode(OtpItinerary itinerary) {
    for (final leg in itinerary.legs) {
      final mode = leg.mode.toUpperCase();
      if (mode != 'WALK' && mode != 'WALKING') {
        if (mode == 'CAR' || mode.contains('CAR')) {
          return Icons.directions_car;
        } else if (mode == 'BICYCLE' ||
            mode == 'BIKE' ||
            mode.contains('BIKE')) {
          return Icons.directions_bike;
        } else if (mode.contains('RAIL') ||
            mode.contains('TRAIN') ||
            mode == 'R' ||
            mode == 'IC') {
          return Icons.train;
        } else if (mode.contains('BUS') ||
            mode == 'COACH' ||
            mode == 'FLIXBUS') {
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

        final itineraries = List<OtpItinerary>.from(controller.itineraries);
        itineraries.sort((OtpItinerary a, OtpItinerary b) {
          final scoreA = EcoScoreService.instance.calculateScore(a).score;
          final scoreB = EcoScoreService.instance.calculateScore(b).score;
          return scoreB.compareTo(scoreA);
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
                  'OTP não encontrou rotas de transporte público para esta ligação. '
                  'Tenta outro destino ou verifica se há cobertura de transportes nesta área.',
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
        .map(
          (leg) =>
              leg.rentedBike == true ? 'GIRA' : (leg.routeName ?? leg.mode),
        )
        .join(' • ');
    final walkKm = itinerary.walkDistance / 1000.0;

    final ecoScore = EcoScoreService.instance.calculateScore(itinerary);
    final scoreColor = Color(
      EcoScoreService.instance.getScoreColor(ecoScore.score),
    );

    return GestureDetector(
      onTap: () => widget.controller.selectItinerary(widget.index),
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? _RouteOptionsOverlayState._ecoMint.withValues(alpha: 0.15)
              : t.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? _RouteOptionsOverlayState._ecoMint
                : t.colorScheme.onSurface.withValues(alpha: .1),
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
            Text(legsSummary, style: t.textTheme.bodyMedium),
            const SizedBox(height: 6),
            Row(
              children: [
                // Eco Score badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: t.colorScheme.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    EcoScoreService.instance.formatCo2PerKm(ecoScore.co2PerKm),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: t.colorScheme.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${walkKm.toStringAsFixed(1)} km a pé',
                  style: t.textTheme.bodySmall,
                ),
              ],
            ),
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
                        color: t.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              leg.rentedBike == true
                                  ? 'GIRA'
                                  : (leg.routeName ?? leg.mode),
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
                                color: t.colorScheme.onSurface.withValues(alpha: 0.6),
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
    if (m == 'BICYCLE' || m == 'BIKE' || m.contains('BIKE')) {
      return Icons.directions_bike;
    }
    if (m.contains('RAIL') || m.contains('TRAIN') || m == 'R' || m == 'IC') {
      return Icons.train;
    }
    if (m.contains('BUS') || m == 'COACH' || m == 'FLIXBUS') {
      return Icons.directions_bus;
    }
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
        color: t.colorScheme.primaryContainer.withValues(alpha: 0.35),
      ),
      child: child,
    );
  }
}
