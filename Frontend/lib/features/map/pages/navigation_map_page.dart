// lib/features/map/pages/navigation_map_page.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:provider/provider.dart';

import '../../../services/location_service.dart';
import '../state/navigation_controller.dart';
import '../widgets/navigation_overlay.dart';

/// Ecrã de navegação em tempo real.
///
/// - Segue a posição atual do utilizador.
/// - Desenha a linha da perna de rota ativa.
/// - Mantém a câmara centrada no utilizador (quando `_isFollowingUser` está ativo).
class NavigationMapPage extends StatefulWidget {
  const NavigationMapPage({super.key});

  @override
  State<NavigationMapPage> createState() => _NavigationMapPageState();
}

class _NavigationMapPageState extends State<NavigationMapPage> {
  mbx.MapboxMap? _mapboxMap;
  bool _isMapReady = false;

  mbx.CircleAnnotationManager? _userCircleManager;
  mbx.CircleAnnotation? _userCircle;
  mbx.CircleAnnotation? _userHalo;

  mbx.PolylineAnnotationManager? _routeLineManager;
  mbx.PolylineAnnotation? _routeLine;

  StreamSubscription<Position>? _locSubForTracking;

  mbx.Point? _currentPoint;
  bool _isFollowingUser = true;
  int? _lastLegIndexDrawn;

  static const _ecoMint = Color(0xFF3CD4A0);

  @override
  void initState() {
    super.initState();

    // Só depois do primeiro frame é que o context está 100% pronto para o Provider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = context.read<NavigationController>();
      nav.addListener(_onNavChanged);

      _locSubForTracking ??=
          LocationService.instance.getLocationUpdates().listen((pos) {
        _updateUserFromPosition(pos);
      });
    });
  }

  @override
  void dispose() {
    context.read<NavigationController>().removeListener(_onNavChanged);

    _locSubForTracking?.cancel();
    _locSubForTracking = null;

    _routeLineManager?.deleteAll().catchError((_) {});
    _userCircleManager?.deleteAll().catchError((_) {});

    _routeLineManager = null;
    _userCircleManager = null;
    _routeLine = null;
    _userCircle = null;
    _userHalo = null;
    _mapboxMap = null;

    super.dispose();
  }

  /// Callback de criação do mapa na navegação.
  Future<void> _onMapCreated(mbx.MapboxMap map) async {
    _mapboxMap = map;
    _isMapReady = true;

    try {
      await _mapboxMap!.location.updateSettings(
        mbx.LocationComponentSettings(enabled: false),
      );
    } catch (_) {}

    _onNavChanged();
  }

  /// Listener do [NavigationController] para atualizar mapa + rota.
  void _onNavChanged() {
    if (!_isMapReady) return;

    final nav = context.read<NavigationController>();

    // Atualiza a posição do utilizador no mapa.
    final pos = nav.currentPosition;
    if (pos != null) {
      _updateUserFromPosition(pos);
    }

    // Regista leg atual (caso tenha mudado).
    _lastLegIndexDrawn = nav.currentLegIndex;

    // Redesenha sempre a linha da perna atual.
    _drawCurrentLegRoute();
  }

  /// Atualiza posição do utilizador e recenter se `_isFollowingUser` for true.
  Future<void> _updateUserFromPosition(Position pos) async {
    if (!_isMapReady || _mapboxMap == null) return;

    final pt = mbx.Point(
      coordinates: mbx.Position(pos.longitude, pos.latitude),
    );
    _currentPoint = pt;

    await _ensureUserIndicator();

    if (_isFollowingUser) {
      await _moveCameraToUser(animated: true);
    }
  }

  /// Garante que o círculo do utilizador está criado/atualizado.
  Future<void> _ensureUserIndicator() async {
    if (!_isMapReady || _mapboxMap == null || _currentPoint == null) return;

    _userCircleManager ??=
        await _mapboxMap!.annotations.createCircleAnnotationManager();

    if (_userHalo == null) {
      _userHalo = await _userCircleManager!.create(
        mbx.CircleAnnotationOptions(
          geometry: _currentPoint!,
          circleRadius: 24.0,
          circleColor: _ecoMint.withValues(alpha: 0.25).value,
        ),
      );
    } else {
      _userHalo!.geometry = _currentPoint!;
      await _userCircleManager!.update(_userHalo!);
    }

    if (_userCircle == null) {
      _userCircle = await _userCircleManager!.create(
        mbx.CircleAnnotationOptions(
          geometry: _currentPoint!,
          circleRadius: 9.0,
          circleColor: _ecoMint.value,
          circleStrokeColor: 0xFFFFFFFF,
          circleStrokeWidth: 3.0,
        ),
      );
    } else {
      _userCircle!.geometry = _currentPoint!;
      await _userCircleManager!.update(_userCircle!);
    }
  }

  /// Recentra a câmara no utilizador, com zoom/pitch de navegação.
  Future<void> _moveCameraToUser({bool animated = true}) async {
    if (!_isMapReady || _mapboxMap == null || _currentPoint == null) return;

    final camera = mbx.CameraOptions(
      center: _currentPoint,
      zoom: 18.5,
      pitch: 45.0,
      bearing: 0.0,
      padding: mbx.MbxEdgeInsets(
        top: 0.0,
        bottom: 0.0,
        left: 0.0,
        right: 0.0,
      ),
    );

    try {
      if (animated) {
        await _mapboxMap!.easeTo(
          camera,
          mbx.MapAnimationOptions(duration: 600),
        );
      } else {
        await _mapboxMap!.setCamera(camera);
      }
    } catch (_) {}
  }

  /// Desenha a linha da perna de rota atual a partir da posição corrente.
  Future<void> _drawCurrentLegRoute() async {
    if (!_isMapReady || _mapboxMap == null) return;

    final nav = context.read<NavigationController>();
    final geom = nav.currentLegGeometryFromCurrentPosition;
    if (geom == null || geom.isEmpty) return;

    _routeLineManager ??=
        await _mapboxMap!.annotations.createPolylineAnnotationManager();

    try {
      if (_routeLine != null) {
        await _routeLineManager!.delete(_routeLine!);
        _routeLine = null;
      }
    } catch (_) {}

    final coords = geom
        .map(
          (p) => mbx.Position(
            p[1], // lon
            p[0], // lat
          ),
        )
        .toList();

    try {
      _routeLine = await _routeLineManager!.create(
        mbx.PolylineAnnotationOptions(
          geometry: mbx.LineString(coordinates: coords),
          lineColor: 0xFF00FF99,
          lineWidth: 6.0,
          lineOpacity: 0.95,
        ),
      );
    } catch (_) {}
  }

  /// Handler do botão de recentrar.
  Future<void> _onRecentrePressed() async {
    setState(() {
      _isFollowingUser = true;
    });

    final nav = context.read<NavigationController>();
    final pos = nav.currentPosition;
    if (pos != null) {
      await _updateUserFromPosition(pos);
      await _moveCameraToUser(animated: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final safeBottom = media.padding.bottom;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // Mapa base de navegação.
          Positioned.fill(
            child: mbx.MapWidget(
              onMapCreated: _onMapCreated,
              cameraOptions: mbx.CameraOptions(
                center: _currentPoint,
                zoom: 18.5,
                pitch: 45.0,
                bearing: 0.0,
                padding: mbx.MbxEdgeInsets(
                  top: 0.0,
                  bottom: 0.0,
                  left: 0.0,
                  right: 0.0,
                ),
              ),
            ),
          ),

          // Overlay com info de navegação (próxima instrução, etc.).
          const NavigationOverlay(),

          // Botão de recentrar.
          Positioned(
            right: 16,
            bottom: safeBottom + 18,
            child: FloatingActionButton(
              heroTag: 'nav-recenter',
              onPressed: _onRecentrePressed,
              backgroundColor: colorScheme.surface,
              foregroundColor: colorScheme.primary,
              elevation: 4,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
