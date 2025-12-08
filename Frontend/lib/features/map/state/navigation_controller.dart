import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../services/location_service.dart';
import '../../../services/routes_service.dart'; // OtpItinerary, OtpLeg
import 'package:sustainable_transport_app/utils/polyline_decoder.dart';

class NavigationController extends ChangeNotifier {
  NavigationController(this._routesService);

  final RoutesService _routesService; // futuro re-routing

  OtpItinerary? _activeItinerary;
  int _currentLegIndex = 0;

  Position? _currentPosition;
  bool _isNavigating = false;
  bool _isReRouting = false;

  double _totalDistance = 0.0; // metros
  double _distanceRemaining = 0.0; // metros
  double _currentLegDistanceRemaining = 0.0; // metros

  String? _nextInstruction;

  /// Geometrias por leg: lista de [lat, lon]
  final List<List<List<double>>> _legGeometries = [];
  /// Geometria completa da rota
  final List<List<double>> _fullGeometry = [];

  StreamSubscription<Position>? _locationSubscription;

  // ===== GETTERS PÚBLICOS =====

  bool get isNavigating => _isNavigating;
  bool get isReRouting => _isReRouting;

  OtpItinerary? get activeItinerary => _activeItinerary;

  int get currentLegIndex => _currentLegIndex;

  OtpLeg? get currentLeg {
    final itin = _activeItinerary;
    if (itin == null) return null;
    if (_currentLegIndex < 0 || _currentLegIndex >= itin.legs.length) {
      return null;
    }
    return itin.legs[_currentLegIndex];
  }

  Position? get currentPosition => _currentPosition;

  double get totalDistance => _totalDistance;
  double get distanceRemaining => _distanceRemaining;
  double get currentLegDistanceRemaining => _currentLegDistanceRemaining;

  /// Progresso total da rota [0,1]
  double get progress {
    if (_totalDistance <= 0) return 0.0;
    return (1.0 - (_distanceRemaining / _totalDistance))
        .clamp(0.0, 1.0);
  }

  /// Progresso da etapa atual [0,1]
  double get currentLegProgress {
    final leg = currentLeg;
    if (leg == null || leg.distance <= 0) return 0.0;
    return (1.0 - (_currentLegDistanceRemaining / leg.distance))
        .clamp(0.0, 1.0);
  }

  String? get nextInstruction => _nextInstruction;

  /// Geometria da etapa atual, como lista de [lat, lon]
  List<List<double>>? get currentLegGeometry {
    if (_currentLegIndex < 0 || _currentLegIndex >= _legGeometries.length) {
      return null;
    }
    return _legGeometries[_currentLegIndex];
  }

  /// Geometria da etapa atual a partir da posição do user:
  /// cortamos a polyline desde o ponto mais próximo do utilizador até ao fim.
  List<List<double>>? get currentLegGeometryFromCurrentPosition {
    final geom = currentLegGeometry;
    final pos = _currentPosition;

    if (geom == null || geom.isEmpty || pos == null) {
      return geom;
    }

    int closestIndex = 0;
    double closestDist = double.infinity;

    for (int i = 0; i < geom.length; i++) {
      final pt = geom[i];
      final d = _haversineMeters(
        pos.latitude,
        pos.longitude,
        pt[0],
        pt[1],
      );
      if (d < closestDist) {
        closestDist = d;
        closestIndex = i;
      }
    }

    // sublista desde o ponto mais próximo até ao fim da leg
    return geom.sublist(closestIndex);
  }

  /// Geometria completa da rota
  List<List<double>> get fullGeometry => _fullGeometry;

  // ===== CONTROLO DE NAVEGAÇÃO =====

  Future<void> startNavigation(
    OtpItinerary itinerary, {
    required double destinationLat,
    required double destinationLon,
  }) async {
    // limpar estado anterior
    await _locationSubscription?.cancel();
    _locationSubscription = null;

    _activeItinerary = itinerary;
    _currentLegIndex = 0;
    _isNavigating = true;
    _isReRouting = false;

    _legGeometries.clear();
    _fullGeometry.clear();

    // Decodificar polylines de cada leg (se existirem)
    for (final leg in itinerary.legs) {
      List<List<double>> geom = [];
      if (leg.polyline != null && leg.polyline!.isNotEmpty) {
        try {
          geom = decodePolyline(leg.polyline!); // [lat, lon]
        } catch (e) {
          debugPrint(
            '[NavigationController] Error decoding polyline: $e',
          );
        }
      }
      _legGeometries.add(geom);
      _fullGeometry.addAll(geom);
    }

    _totalDistance = itinerary.legs.fold<double>(
      0.0,
      (sum, l) => sum + l.distance,
    );
    _distanceRemaining = _totalDistance;
    _currentLegDistanceRemaining =
        itinerary.legs.isNotEmpty ? itinerary.legs.first.distance : 0.0;

    _nextInstruction = _buildInstructionForLeg(_currentLegIndex);

    // posição inicial
    _currentPosition =
        await LocationService.instance.getCurrentLocation();

    // ouvir atualizações de localização
    _locationSubscription =
        LocationService.instance.getLocationUpdates().listen((pos) {
      _currentPosition = pos;
      _updateProgress();
      _maybeAdvanceLeg();
      notifyListeners(); // avisa mapa/overlay
    });

    notifyListeners();
  }

  Future<void> stopNavigation() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;

    _isNavigating = false;
    _isReRouting = false;
    _activeItinerary = null;
    _currentLegIndex = 0;
    _currentPosition = null;
    _totalDistance = 0.0;
    _distanceRemaining = 0.0;
    _currentLegDistanceRemaining = 0.0;
    _nextInstruction = null;
    _legGeometries.clear();
    _fullGeometry.clear();

    notifyListeners();
  }

  // ===== LÓGICA INTERNA =====

  void _updateProgress() {
    final itin = _activeItinerary;
    final pos = _currentPosition;
    if (itin == null || pos == null || itin.legs.isEmpty) return;

    final leg = itin.legs[_currentLegIndex];
    double legRemaining = leg.distance;

    final endCoord = _getLegEndCoord(_currentLegIndex);
    if (endCoord != null) {
      final d = _haversineMeters(
        pos.latitude,
        pos.longitude,
        endCoord[0],
        endCoord[1],
      );
      legRemaining = d.clamp(0.0, leg.distance);
    }

    _currentLegDistanceRemaining = legRemaining;

    double rem = legRemaining;
    for (int i = _currentLegIndex + 1; i < itin.legs.length; i++) {
      rem += itin.legs[i].distance;
    }
    _distanceRemaining = rem;
  }

  /// Se estivermos suficientemente perto do fim da etapa atual, avançar
  void _maybeAdvanceLeg() {
    final itin = _activeItinerary;
    if (itin == null) return;

    const double thresholdMeters = 40.0;

    if (_currentLegDistanceRemaining > thresholdMeters) return;

    if (_currentLegIndex >= itin.legs.length - 1) {
      // última leg, deixa o UI tratar do "fim"
      return;
    }

    _currentLegIndex++;
    _currentLegDistanceRemaining = itin.legs[_currentLegIndex].distance;
    _nextInstruction = _buildInstructionForLeg(_currentLegIndex);
  }

  /// Retorna [lat, lon] aproximado do fim da leg (último ponto da polyline)
  List<double>? _getLegEndCoord(int legIndex) {
    if (legIndex < 0 || legIndex >= _legGeometries.length) return null;
    final geom = _legGeometries[legIndex];
    if (geom.isEmpty) return null;
    return geom.last; // [lat, lon]
  }

  String _buildInstructionForLeg(int index) {
    final itin = _activeItinerary;
    if (itin == null || index < 0 || index >= itin.legs.length) {
      return '';
    }
    final leg = itin.legs[index];
    final mode = leg.mode.toUpperCase();

    if (mode == 'WALK' || mode == 'WALKING') {
      return 'Caminha até ${leg.toName}';
    } else if (mode.contains('BUS')) {
      final route = leg.routeName ?? 'autocarro';
      return 'Apanha o $route em ${leg.fromName} até ${leg.toName}';
    } else if (mode.contains('RAIL') ||
        mode.contains('TRAIN') ||
        mode == 'R' ||
        mode == 'IC') {
      final route = leg.routeName ?? 'comboio';
      return 'Apanha o $route em ${leg.fromName} até ${leg.toName}';
    } else if (mode.contains('METRO') || mode.contains('SUBWAY')) {
      return 'Apanha o metro em ${leg.fromName} até ${leg.toName}';
    } else if (mode.contains('TRAM')) {
      return 'Apanha o elétrico em ${leg.fromName} até ${leg.toName}';
    } else if (mode.contains('BICYCLE') || mode.contains('BIKE')) {
      return 'Pedala até ${leg.toName}';
    }

    return '${leg.fromName} → ${leg.toName}';
  }

  double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double r = 6371000.0; // raio da Terra em metros
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180.0);
}
