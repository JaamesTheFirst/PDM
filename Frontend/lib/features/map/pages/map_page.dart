import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;

import '../../../services/location_service.dart';
import '../../../services/mapbox_searchbox_service.dart';

// screens + bottom-sheet route + tipos
import '../nav/bottom_sheet_route.dart';
import '../screens/route_search_screen.dart'; // RouteSearchScreen + RouteSearchScreenArgs
// import '../screens/route_options_screen.dart';  // <- DEIXA DE SER USADO
import '../widgets/route_options_overlay.dart'; // RouteOptionsArgs (tipo)

class MapPage extends StatefulWidget {
  static final ValueNotifier<bool> fullscreenNotifier = ValueNotifier(false);
  static final ValueNotifier<Map<String, dynamic>?> pendingRouteSearch =
      ValueNotifier<Map<String, dynamic>?>(null);

  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  mbx.MapboxMap? mapboxMap;
  mbx.Point? _currentLocation;
  bool _isLoading = true;

  mbx.CircleAnnotationManager? _userCircleManager;
  mbx.CircleAnnotation? _userCircle;
  mbx.CircleAnnotation? _userHalo;
  StreamSubscription<Position>? _posSub;

  static const _ecoMint = Color(0xFF3CD4A0);
  bool _isMapAlive = false;

  // novos: para mostrar a RouteOptionsOverlay dentro do MapPage
  RouteOptionsArgs? _routeOptionsArgs;

  @override
  void initState() {
    super.initState();
    _init();
    // listen for pending route search from HistoryPage
    MapPage.pendingRouteSearch.addListener(_handlePendingRouteSearch);
  }

  void _handlePendingRouteSearch() async {
    final data = MapPage.pendingRouteSearch.value;
    if (data != null && mapboxMap != null && _isMapAlive) {
      // Clear the pending search
      MapPage.pendingRouteSearch.value = null;

      // Get origin - use provided from or current location
      SearchboxPlace fromPlace;
      if (data.containsKey('fromId') && data.containsKey('fromLat') && data.containsKey('fromLon')) {
        fromPlace = SearchboxPlace(
          id: data['fromId'] as String,
          name: data['fromName'] as String? ?? 'Origem',
          placeName: data['fromName'] as String? ?? 'Origem',
          longitude: data['fromLon'] as double,
          latitude: data['fromLat'] as double,
        );
      } else {
        // Use current location as origin
        if (_currentLocation == null) {
          // Try to get current location
          final pos = await LocationService.instance.getCurrentLocation();
          if (!mounted) return; // Check mounted after async call
          if (pos == null) {
            print('[MapPage] Cannot handle pending route search: no current location');
            return;
          }
          setState(() {
            _currentLocation = mbx.Point(
              coordinates: mbx.Position(pos.longitude, pos.latitude),
            );
          });
        }
        if (!mounted) return; // Check mounted before using _currentLocation
        fromPlace = SearchboxPlace(
          id: 'current_location',
          name: 'Localização atual',
          placeName: 'Localização atual',
          longitude: _currentLocation!.coordinates.lng.toDouble(),
          latitude: _currentLocation!.coordinates.lat.toDouble(),
        );
      }

      if (!mounted) return; // Check mounted before creating RouteOptionsArgs

      final toPlace = SearchboxPlace(
        id: data['toId'] as String,
        name: data['toName'] as String,
        placeName: data['toAddress'] as String? ?? data['toName'] as String, // Use address if available
        longitude: data['toLon'] as double,
        latitude: data['toLat'] as double,
      );

      // Create RouteOptionsArgs and set it
      final args = RouteOptionsArgs(
        mapboxMap: mapboxMap!,
        from: fromPlace,
        to: toPlace,
      );

      setState(() {
        _routeOptionsArgs = args;
      });
      MapPage.fullscreenNotifier.value = true;
    }
  }

  Future<void> _init() async {
    final ok = await LocationService.instance.checkPermissions();
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _currentLocation = null;
        _isLoading = false;
      });
      return;
    }

    final p = await LocationService.instance.getCurrentLocation();
    if (!mounted) return;

    setState(() {
      _currentLocation = (p != null)
          ? mbx.Point(coordinates: mbx.Position(p.longitude, p.latitude))
          : null;
      _isLoading = false;
    });
  }

  Future<void> _onMapCreated(mbx.MapboxMap map) async {
    mapboxMap = map;
    _isMapAlive = true;

    try {
      await mapboxMap!.location
          .updateSettings(mbx.LocationComponentSettings(enabled: false));
    } catch (_) {
      return;
    }

    await _ensureUserIndicator();

    if (_currentLocation != null) {
      await _moveCameraTo(_currentLocation!, animated: false);
    }

    _posSub ??=
        LocationService.instance.getLocationUpdates().listen((pos) async {
      if (!_isMapAlive) return;
      final pt =
          mbx.Point(coordinates: mbx.Position(pos.longitude, pos.latitude));
      _currentLocation = pt;
      await _updateUserIndicator(pt);
    });
  }

  Future<void> _ensureUserIndicator() async {
    if (!_isMapAlive || mapboxMap == null || _currentLocation == null) return;

    try {
      _userCircleManager ??=
          await mapboxMap!.annotations.createCircleAnnotationManager();

      _userHalo ??= await _userCircleManager!.create(
        mbx.CircleAnnotationOptions(
          geometry: _currentLocation!,
          circleRadius: 22.0,
          circleColor: _ecoMint.withOpacity(0.25).value,
        ),
      );

      _userCircle ??= await _userCircleManager!.create(
        mbx.CircleAnnotationOptions(
          geometry: _currentLocation!,
          circleRadius: 8.0,
          circleColor: _ecoMint.value,
          circleStrokeColor: 0xFFFFFFFF,
          circleStrokeWidth: 2.5,
        ),
      );
    } catch (_) {}
  }

  Future<void> _updateUserIndicator(mbx.Point pt) async {
    if (!_isMapAlive) return;

    try {
      if (_userCircleManager == null) {
        await _ensureUserIndicator();
        return;
      }
      if (_userHalo == null || _userCircle == null) {
        await _ensureUserIndicator();
        return;
      }

      _userHalo!.geometry = pt;
      _userCircle!.geometry = pt;
      await _userCircleManager!.update(_userHalo!);
      await _userCircleManager!.update(_userCircle!);
    } catch (_) {}
  }

  Future<void> _moveCameraTo(
    mbx.Point target, {
    bool animated = true,
  }) async {
    if (!_isMapAlive || mapboxMap == null) return;

    final camera = mbx.CameraOptions(
      center: target,
      zoom: 15,
      bearing: 0,
      pitch: 0,
      padding: mbx.MbxEdgeInsets(top: 0, left: 0, right: 0, bottom: 0),
    );

    try {
      if (animated) {
        await mapboxMap!
            .easeTo(camera, mbx.MapAnimationOptions(duration: 900));
      } else {
        await mapboxMap!.setCamera(camera);
      }
    } catch (_) {}
  }

  Future<void> _goToUser() async {
    final ok = await LocationService.instance.checkPermissions();
    if (!ok) return;

    final pos = await LocationService.instance.getCurrentLocation();
    if (pos == null) return;

    final target =
        mbx.Point(coordinates: mbx.Position(pos.longitude, pos.latitude));
    _currentLocation = target;

    await _ensureUserIndicator();
    await _moveCameraTo(target, animated: true);
  }

  // === flow: Search (FULL) -> Options (overlay 50%) ===
  Future<void> _openSearchAsScreens() async {
    if (!_isMapAlive || mapboxMap == null) {
      print('[MapPage] Cannot open search: map not ready');
      return;
    }
    
    if (_currentLocation == null) {
      print('[MapPage] Cannot open search: current location is null');
      // Try to get location again
      final pos = await LocationService.instance.getCurrentLocation();
      if (pos == null) {
        print('[MapPage] Failed to get current location');
        // Show error to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível obter a tua localização. Verifica as permissões de GPS.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      setState(() {
        _currentLocation = mbx.Point(
          coordinates: mbx.Position(pos.longitude, pos.latitude),
        );
      });
    }

    final coords = _currentLocation!.coordinates;
    print('[MapPage] Opening search screen with location: lat=${coords.lat}, lng=${coords.lng}');
    
    if (coords.lat == 0.0 && coords.lng == 0.0) {
      print('[MapPage] WARNING: Location appears to be invalid (0,0)');
    }

    // enquanto o fluxo de rotas está ativo, escondemos o botão "Para onde?"
    MapPage.fullscreenNotifier.value = true;

    try {
      // 1) SEARCH (full-screen bottom sheet) — devolve RouteOptionsArgs
      final args = await Navigator.of(context).push<RouteOptionsArgs>(
        BottomSheetPageRoute(
          heightFactor: 1.0,
          child: RouteSearchScreen(
            args: RouteSearchScreenArgs(
              mapboxMap: mapboxMap!,
              userLocation: _currentLocation!,
            ),
          ),
        ),
      );

      if (!mounted || args == null) {
        // user cancelou
        MapPage.fullscreenNotifier.value = false;
        return;
      }

      // 2) OPTIONS como overlay dentro do MapPage (meia altura)
      setState(() {
        _routeOptionsArgs = args;
      });
    } finally {
      // NÃO voltamos a pôr fullscreenNotifier a false aqui,
      // só quando fecharmos o overlay de opções.
    }
  }

  void _closeOptionsOverlay() {
    setState(() {
      _routeOptionsArgs = null;
    });
    // volta a mostrar o botão "Para onde?"
    MapPage.fullscreenNotifier.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final padding = MediaQuery.of(context).padding;
    final safeTop = padding.top;
    final safeBottom = padding.bottom;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        // MAPA
        Positioned.fill(
          child: mbx.MapWidget(
            onMapCreated: _onMapCreated,
            cameraOptions: mbx.CameraOptions(
              center: _currentLocation,
              zoom: 14.0,
            ),
          ),
        ),

        // Botão "Para onde?" (esconde quando fullscreenNotifier = true)
        Positioned(
          left: 16,
          right: 16,
          top: safeTop + 10,
          child: ValueListenableBuilder<bool>(
            valueListenable: MapPage.fullscreenNotifier,
            builder: (context, isFullscreen, _) {
              if (isFullscreen) {
                // Quando o fluxo de rotas está aberto (search OU options),
                // não mostra este botão
                return const SizedBox.shrink();
              }

              return GestureDetector(
                onTap: _openSearchAsScreens,
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: t.cardColor.withOpacity(.92),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search),
                      SizedBox(width: 10),
                      Text(
                        'Para onde?',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // FAB "minha localização"
        Positioned(
          right: 16,
          bottom: 16 + safeBottom,
          child: FloatingActionButton(
            heroTag: 'my-location',
            onPressed: _goToUser,
            backgroundColor: t.cardColor,
            foregroundColor: _ecoMint,
            elevation: 3,
            child: const Icon(Icons.my_location),
          ),
        ),

        // OVERLAY DE OPÇÕES (meia altura)
        if (_routeOptionsArgs != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.5,
              widthFactor: 1,
              child: RouteOptionsOverlay(
                mapboxMap: _routeOptionsArgs!.mapboxMap,
                from: _routeOptionsArgs!.from,
                to: _routeOptionsArgs!.to,
                onClose: _closeOptionsOverlay,
                filters: _routeOptionsArgs!.filters,
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    // remover listener do ValueNotifier
    MapPage.pendingRouteSearch.removeListener(_handlePendingRouteSearch);

    // limpar mapa / streams
    _isMapAlive = false;
    _posSub?.cancel();
    _posSub = null;
    _userCircleManager?.deleteAll().catchError((_) {});
    _userCircleManager = null;
    _userCircle = null;
    _userHalo = null;
    mapboxMap = null;

    super.dispose();
  }
}
