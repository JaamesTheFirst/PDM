// lib/features/map/pages/map_page.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:provider/provider.dart';

import '../../../services/location_service.dart';
import '../../../services/mapbox_searchbox_service.dart';
import '../nav/bottom_sheet_route.dart';
import '../screens/route_search_screen.dart'; // RouteSearchScreen + RouteSearchScreenArgs
import '../widgets/route_options_overlay.dart'; // RouteOptionsArgs (tipo)
import '../state/otp_routes_controller.dart';

/// Página principal do mapa.
///
/// - Mostra o mapa Mapbox.
/// - Desenha a posição atual do utilizador.
/// - Abre o fluxo de pesquisa de rotas (bottom sheet full-screen).
/// - Mostra as opções de rota num overlay em meia-altura.
class MapPage extends StatefulWidget {
  /// Controla se o mapa está em “modo fullscreen” (sem botão "Para onde?").
  static final ValueNotifier<bool> fullscreenNotifier = ValueNotifier(false);

  /// Pedidos pendentes de pesquisa vindos de outros ecrãs (ex.: HistoryPage).
  ///
  /// Quando recebe um valor, o [MapPage] tenta abrir diretamente o fluxo
  /// de rotas com base nesse destino.
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

  /// Args para o overlay de opções de rota (meia altura).
  RouteOptionsArgs? _routeOptionsArgs;

  @override
  void initState() {
    super.initState();
    _init();
    // Ouve pedidos de pesquisa vindos de páginas externas (ex.: HistoryPage).
    MapPage.pendingRouteSearch.addListener(_handlePendingRouteSearch);
  }

  /// Trata pedidos em [pendingRouteSearch] para abrir pesquisa diretamente.
  Future<void> _handlePendingRouteSearch() async {
    final data = MapPage.pendingRouteSearch.value;
    if (data == null) {
      debugPrint('[MapPage] _handlePendingRouteSearch: data is null');
      return;
    }

    debugPrint(
      '[MapPage] _handlePendingRouteSearch: data=$data, mapboxMap=${mapboxMap != null}, _isMapAlive=$_isMapAlive',
    );

    // Se o mapa não está pronto, aguarda até estar
    if (mapboxMap == null || !_isMapAlive) {
      debugPrint(
        '[MapPage] Map not ready yet, waiting... (mapboxMap=${mapboxMap != null}, _isMapAlive=$_isMapAlive)',
      );
      // Aguarda até o mapa estar pronto (máximo 5 segundos)
      int attempts = 0;
      while ((mapboxMap == null || !_isMapAlive) && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      if (mapboxMap == null || !_isMapAlive) {
        debugPrint('[MapPage] Map still not ready after waiting');
        return;
      }
    }

    // Limpa o pedido para não repetir.
    MapPage.pendingRouteSearch.value = null;

    // ==== ORIGEM ====
    SearchboxPlace fromPlace;

    if (data.containsKey('fromId') &&
        data.containsKey('fromLat') &&
        data.containsKey('fromLon')) {
      // Origem explícita no payload.
      fromPlace = SearchboxPlace(
        id: data['fromId'] as String,
        name: (data['fromName'] as String?) ?? 'Origem',
        placeName: (data['fromName'] as String?) ?? 'Origem',
        longitude: data['fromLon'] as double,
        latitude: data['fromLat'] as double,
      );
    } else {
      // Usa localização atual como origem.
      if (_currentLocation == null) {
        final pos = await LocationService.instance.getCurrentLocation();
        if (!mounted) return;
        if (pos == null) return;

        setState(() {
          _currentLocation = mbx.Point(
            coordinates: mbx.Position(pos.longitude, pos.latitude),
          );
        });
      }

      if (!mounted || _currentLocation == null) return;

      fromPlace = SearchboxPlace(
        id: 'current_location',
        name: 'Localização atual',
        placeName: 'Localização atual',
        longitude: _currentLocation!.coordinates.lng.toDouble(),
        latitude: _currentLocation!.coordinates.lat.toDouble(),
      );
    }

    if (!mounted) return;

    // ==== DESTINO ====
    final toPlace = SearchboxPlace(
      id: data['toId'] as String,
      name: data['toName'] as String,
      placeName:
          (data['toAddress'] as String?) ?? (data['toName'] as String),
      longitude: data['toLon'] as double,
      latitude: data['toLat'] as double,
    );

    // Cria RouteOptionsArgs e ativa o overlay.
    final args = RouteOptionsArgs(
      mapboxMap: mapboxMap!,
      from: fromPlace,
      to: toPlace,
    );

    debugPrint(
      '[MapPage] Setting route options: from=${fromPlace.name}, to=${toPlace.name}',
    );

    if (!mounted) return;

    setState(() {
      _routeOptionsArgs = args;
    });
    MapPage.fullscreenNotifier.value = true;

    debugPrint('[MapPage] Route options overlay should now be visible');
    
    // Force a rebuild to ensure the overlay is shown
    if (mounted) {
      setState(() {});
    }
  }

  /// Inicializa permissões e obtém a localização atual (uma vez).
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

  /// Callback de criação do [MapWidget].
  Future<void> _onMapCreated(mbx.MapboxMap map) async {
    mapboxMap = map;
    _isMapAlive = true;

    // Se há um pedido pendente de pesquisa de rota, processa agora que o mapa está pronto
    if (MapPage.pendingRouteSearch.value != null) {
      debugPrint('[MapPage] Map created, processing pending route search');
      // Pequeno delay para garantir que tudo está inicializado
      await Future.delayed(const Duration(milliseconds: 100));
      _handlePendingRouteSearch();
    }

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

  /// Garante que o marcador de posição do utilizador está criado.
  Future<void> _ensureUserIndicator() async {
    if (!_isMapAlive || mapboxMap == null || _currentLocation == null) return;

    try {
      _userCircleManager ??=
          await mapboxMap!.annotations.createCircleAnnotationManager();

      _userHalo ??= await _userCircleManager!.create(
        mbx.CircleAnnotationOptions(
          geometry: _currentLocation!,
          circleRadius: 22.0,
          circleColor: _ecoMint.withValues(alpha: 0.25).value,
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

  /// Atualiza a posição do marcador do utilizador.
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

  /// Move a câmara para um [target] específico.
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

  /// Recentra a câmara na posição atual do utilizador.
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

  // === fluxo: Search (full-screen) → Options (overlay 50%) ===

  /// Abre o fluxo de pesquisa de rotas como bottom sheet full-screen.
  Future<void> _openSearchAsScreens() async {
    if (!_isMapAlive || mapboxMap == null) {
      debugPrint('[MapPage] Cannot open search: map not ready');
      return;
    }

    if (_currentLocation == null) {
      debugPrint('[MapPage] Cannot open search: current location is null');

      // Tenta obter localização novamente.
      final pos = await LocationService.instance.getCurrentLocation();
      if (!mounted) return;

      if (pos == null) {
        debugPrint('[MapPage] Failed to get current location');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível obter a tua localização. '
                'Verifica as permissões de GPS.',
              ),
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
    debugPrint(
      '[MapPage] Opening search screen with location: '
      'lat=${coords.lat}, lng=${coords.lng}',
    );

    if (coords.lat == 0.0 && coords.lng == 0.0) {
      debugPrint(
        '[MapPage] WARNING: Location appears to be invalid (0,0)',
      );
    }

    // Enquanto o fluxo de rotas está ativo, escondemos o botão "Para onde?".
    MapPage.fullscreenNotifier.value = true;

    try {
      // 1) SEARCH (full-screen bottom sheet) — devolve RouteOptionsArgs.
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
        // Utilizador cancelou ou widget desmontado.
        MapPage.fullscreenNotifier.value = false;
        return;
      }

      // 2) OPTIONS como overlay dentro do MapPage (meia altura).
      final otpController = context.read<OtpRoutesController>();
      otpController.clear();

      setState(() {
        _routeOptionsArgs = args;
      });
    } finally {
      // fullscreenNotifier volta a false quando fecharmos o overlay.
    }
  }

  /// Fecha o overlay de opções de rota.
  void _closeOptionsOverlay() {
    setState(() {
      _routeOptionsArgs = null;
    });
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
        // ===== MAPA =====
        Positioned.fill(
          child: mbx.MapWidget(
            onMapCreated: _onMapCreated,
            cameraOptions: mbx.CameraOptions(
              center: _currentLocation,
              zoom: 14.0,
            ),
          ),
        ),

        // ===== Botão "Para onde?" (esconde em fullscreen) =====
        Positioned(
          left: 16,
          right: 16,
          top: safeTop + 10,
          child: ValueListenableBuilder<bool>(
            valueListenable: MapPage.fullscreenNotifier,
            builder: (context, isFullscreen, _) {
              if (isFullscreen) {
                return const SizedBox.shrink();
              }

              return GestureDetector(
                onTap: _openSearchAsScreens,
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: t.cardColor.withValues(alpha: .92),
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

        // ===== FAB "minha localização" =====
        Positioned(
          right: 16,
          bottom: 16 + safeBottom,
          child: FloatingActionButton(
            heroTag: 'map-my-location',
            onPressed: _goToUser,
            backgroundColor: t.cardColor,
            foregroundColor: _ecoMint,
            elevation: 3,
            child: const Icon(Icons.my_location),
          ),
        ),

        // ===== OVERLAY DE OPÇÕES (meia altura) =====
        if (_routeOptionsArgs != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: RouteOptionsOverlay(
              mapboxMap: _routeOptionsArgs!.mapboxMap,
              from: _routeOptionsArgs!.from,
              to: _routeOptionsArgs!.to,
              onClose: _closeOptionsOverlay,
              filters: _routeOptionsArgs!.filters,
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
