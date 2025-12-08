// lib/services/location_service.dart

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Serviço de localização responsável por:
/// - Gerir permissões de localização;
/// - Obter a localização actual;
/// - Expor um stream de updates;
/// - Fazer geocoding (endereço ↔ coordenadas);
/// - Simular movimento ao longo de uma rota (modo mock).
class LocationService {
  LocationService._();

  /// Instância singleton do [LocationService].
  static final LocationService _instance = LocationService._();

  /// Acesso público ao singleton.
  static LocationService get instance => _instance;

  /// Verifica se o modo mock está ativado (via --dart-define).
  static bool get isMockModeEnabled =>
      const String.fromEnvironment('MOCK_LOCATION', defaultValue: 'false')
          .toLowerCase() ==
      'true';

  // ================== MOCK LOCATION ==================

  /// Stream controller para mock location (quando ativo).
  StreamController<Position>? _mockStreamController;

  /// Timer para atualizar mock location.
  Timer? _mockTimer;

  /// Índice atual no array de pontos da rota.
  int _mockRouteIndex = 0;

  /// Distância já percorrida no segmento atual (em metros).
  /// Usado para interpolação entre pontos consecutivos.
  double _mockDistanceInSegment = 0.0;

  /// Array de pontos da rota para simulação [[lat, lon], ...].
  List<List<double>> _mockRoutePoints = [];

  /// Velocidade de simulação em metros por segundo.
  double _mockSpeed = 5.0; // ~18 km/h (velocidade de caminhada)

  /// Última posição mock emitida.
  Position? _lastMockPosition;

  // ================== PERMISSÕES ==================

  /// Verifica e solicita permissões de localização ao utilizador.
  ///
  /// Devolve `true` se:
  /// - o serviço de localização estiver activo; e
  /// - a permissão não for `denied` nem `deniedForever`.
  ///
  /// Caso contrário, devolve `false`.
  Future<bool> checkPermissions() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // ================== LOCALIZAÇÃO ÚNICA ==================

  /// Obtém a localização actual com a maior precisão possível.
  ///
  /// Se o modo mock estiver ativo e houver uma posição mock, devolve essa.
  /// Caso contrário, usa GPS real.
  ///
  /// Se as permissões não estiverem concedidas, devolve `null`.
  /// Em caso de erro (timeout, etc.), devolve igualmente `null`.
  Future<Position?> getCurrentLocation() async {
    // Se mock está ativo e há uma posição mock, devolve essa
    if (isMockModeEnabled && _lastMockPosition != null) {
      return _lastMockPosition;
    }

    final bool hasPermission = await checkPermissions();
    if (!hasPermission) return null;

    try {
      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      return pos;
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
    }
  }

  // ================== STREAM DE LOCALIZAÇÃO ==================

  /// Devolve um stream de updates de localização com boa precisão.
  ///
  /// Se o modo mock estiver ativado e uma rota mock estiver configurada,
  /// devolve um stream simulado. Caso contrário, usa o GPS real.
  ///
  /// Configuração:
  /// - [LocationAccuracy.bestForNavigation]
  /// - `distanceFilter = 3` metros (aprox.), para evitar spam de updates.
  Stream<Position> getLocationUpdates() {
    // Se mock está ativo e há uma rota configurada, usa mock stream
    if (isMockModeEnabled && _mockStreamController != null) {
      return _mockStreamController!.stream;
    }

    // Caso contrário, usa GPS real
    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3,
    );

    return Geolocator.getPositionStream(
      locationSettings: settings,
    );
  }

  /// Configura uma rota mock para simulação de movimento.
  ///
  /// [routePoints] deve ser uma lista de coordenadas [[lat, lon], ...].
  /// [speed] é a velocidade de simulação em metros por segundo (padrão: 5.0 m/s).
  ///
  /// **Nota:** Só funciona se `MOCK_LOCATION=true` estiver definido via `--dart-define`.
  void setMockRoute(List<List<double>> routePoints, {double speed = 5.0}) {
    if (!isMockModeEnabled) {
      debugPrint(
        '[LocationService] Mock location not enabled. Set MOCK_LOCATION=true via --dart-define.',
      );
      return;
    }

    if (routePoints.isEmpty) {
      debugPrint('[LocationService] Cannot set empty mock route.');
      return;
    }

    _mockRoutePoints = routePoints;
    _mockSpeed = speed;
    _mockRouteIndex = 0;
    _mockDistanceInSegment = 0.0;

    // Cria stream controller se não existir
    _mockStreamController ??= StreamController<Position>.broadcast();

    // Inicia a primeira posição
    final firstPoint = routePoints.first;
    _lastMockPosition = Position(
      latitude: firstPoint[0],
      longitude: firstPoint[1],
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: speed,
      speedAccuracy: 0,
    );

    if (!_mockStreamController!.isClosed) {
      _mockStreamController!.add(_lastMockPosition!);
      debugPrint(
        '[LocationService] Initial mock position emitted: ${_lastMockPosition!.latitude}, ${_lastMockPosition!.longitude}',
      );
    }

    // Calcula intervalo de atualização para movimento suave
    // Atualiza a cada 100ms (10 vezes por segundo) para movimento fluido
    final updateInterval = Duration(milliseconds: 100);

    // Cancela timer anterior se existir
    _mockTimer?.cancel();

    // Inicia timer para atualizar posição
    _mockTimer = Timer.periodic(updateInterval, (_) {
      _updateMockPosition();
    });

    debugPrint(
      '[LocationService] Mock route enabled with ${routePoints.length} points at ${speed}m/s',
    );
  }

  /// Para a simulação mock e limpa recursos.
  void stopMockRoute() {
    _mockTimer?.cancel();
    _mockTimer = null;
    _mockRoutePoints.clear();
    _mockRouteIndex = 0;
    _mockDistanceInSegment = 0.0;
    _lastMockPosition = null;

    // Não fecha o stream controller aqui, apenas para o timer
    // O controller pode ser reutilizado se setMockRoute for chamado novamente
    debugPrint('[LocationService] Mock route stopped.');
  }

  /// Atualiza a posição mock movendo-se ao longo da rota.
  void _updateMockPosition() {
    if (_mockRoutePoints.isEmpty || _lastMockPosition == null) {
      debugPrint(
        '[LocationService] Cannot update mock position: route empty or no last position',
      );
      return;
    }

    // Se chegou ao fim da rota, para
    if (_mockRouteIndex >= _mockRoutePoints.length - 1) {
      _mockTimer?.cancel();
      debugPrint('[LocationService] Mock route completed.');
      return;
    }

    final currentPoint = _mockRoutePoints[_mockRouteIndex];
    final nextPoint = _mockRoutePoints[_mockRouteIndex + 1];

    // Calcula distância total do segmento atual
    final segmentDistance = _haversineDistance(
      currentPoint[0],
      currentPoint[1],
      nextPoint[0],
      nextPoint[1],
    );

    // Calcula quanto mover baseado na velocidade (m/s) e intervalo de atualização
    // Se atualizamos a cada 100ms, movemos 0.1 * velocidade por update
    final updateIntervalSeconds = 0.1; // 100ms = 0.1s
    final distanceToMove = _mockSpeed * updateIntervalSeconds; // metros por update

    // Adiciona a distância percorrida neste update
    _mockDistanceInSegment += distanceToMove;

    // Se já percorremos todo o segmento, avança para o próximo ponto
    while (_mockDistanceInSegment >= segmentDistance &&
        _mockRouteIndex < _mockRoutePoints.length - 1) {
      _mockDistanceInSegment -= segmentDistance;
      _mockRouteIndex++;

      // Se ainda há pontos, atualiza o segmento
      if (_mockRouteIndex < _mockRoutePoints.length - 1) {
        final newCurrent = _mockRoutePoints[_mockRouteIndex];
        final newNext = _mockRoutePoints[_mockRouteIndex + 1];
        final newSegmentDistance = _haversineDistance(
          newCurrent[0],
          newCurrent[1],
          newNext[0],
          newNext[1],
        );

        // Se ainda há distância restante, continua no novo segmento
        if (_mockDistanceInSegment < newSegmentDistance) {
          break; // Fica neste segmento
        }
        // Caso contrário, continua o loop para avançar mais
      } else {
        // Chegou ao fim
        _lastMockPosition = Position(
          latitude: nextPoint[0],
          longitude: nextPoint[1],
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: _calculateHeading(currentPoint, nextPoint),
          headingAccuracy: 0,
          speed: _mockSpeed,
          speedAccuracy: 0,
        );
        _mockTimer?.cancel();
        debugPrint('[LocationService] Mock route completed.');
        return;
      }
    }

    // Interpola entre os pontos do segmento atual
    final current = _mockRoutePoints[_mockRouteIndex];
    final next = _mockRoutePoints[_mockRouteIndex + 1];
    final currentSegmentDistance = _haversineDistance(
      current[0],
      current[1],
      next[0],
      next[1],
    );

    final ratio = currentSegmentDistance > 0
        ? (_mockDistanceInSegment / currentSegmentDistance).clamp(0.0, 1.0)
        : 0.0;

    final newLat = current[0] + (next[0] - current[0]) * ratio;
    final newLon = current[1] + (next[1] - current[1]) * ratio;

    _lastMockPosition = Position(
      latitude: newLat,
      longitude: newLon,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: _calculateHeading(current, next),
      headingAccuracy: 0,
      speed: _mockSpeed,
      speedAccuracy: 0,
    );

    if (_mockStreamController != null && !_mockStreamController!.isClosed) {
      _mockStreamController!.add(_lastMockPosition!);
      // Only log every 10th update to avoid spam (once per second at 10Hz)
      if (_mockRouteIndex % 10 == 0 || _mockRouteIndex == 0) {
        debugPrint(
          '[LocationService] Mock position: ${_lastMockPosition!.latitude.toStringAsFixed(6)}, ${_lastMockPosition!.longitude.toStringAsFixed(6)} (index $_mockRouteIndex/${_mockRoutePoints.length - 1})',
        );
      }
    } else {
      debugPrint('[LocationService] Mock stream controller is null or closed!');
    }
  }

  /// Calcula distância Haversine entre dois pontos (em metros).
  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // metros
    final double dLat = (lat2 - lat1) * math.pi / 180;
    final double dLon = (lon2 - lon1) * math.pi / 180;

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Calcula o heading (direção) entre dois pontos em graus.
  double _calculateHeading(List<double> from, List<double> to) {
    final lat1 = from[0] * math.pi / 180;
    final lat2 = to[0] * math.pi / 180;
    final dLon = (to[1] - from[1]) * math.pi / 180;

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final heading = math.atan2(y, x) * 180 / math.pi;
    return (heading + 360) % 360; // Normaliza para 0-360
  }

  // ================== GEOCODING ==================

  /// Obtém um endereço legível a partir de coordenadas.
  ///
  /// Devolve uma string no formato:
  /// `"rua, localidade, distrito, país"`, ou `null` se não conseguir resolver.
  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        return '${place.street}, ${place.locality}, '
            '${place.administrativeArea}, ${place.country}';
      }
      return null;
    } catch (e) {
      debugPrint('Error getting address from coordinates: $e');
      return null;
    }
  }

  /// Obtém coordenadas aproximadas a partir de um endereço textual.
  ///
  /// Devolve um [Position] sintético (com apenas latitude/longitude
  /// relevantes) ou `null` se não encontrar resultados.
  Future<Position?> getCoordinatesFromAddress(String address) async {
    try {
      final List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final Location loc = locations.first;
        return Position(
          latitude: loc.latitude,
          longitude: loc.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
    } catch (e) {
      debugPrint('Error getting coordinates from address: $e');
    }
    return null;
  }
}
