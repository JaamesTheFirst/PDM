import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../services/location_service.dart';
import '../../../services/routes_service.dart'; // OtpItinerary, OtpLeg
import 'package:sustainable_transport_app/utils/polyline_decoder.dart';

/// Controlador responsável por gerir o estado da navegação passo-a-passo.
///
/// Funções principais:
/// - Guardar o itinerário ativo (`OtpItinerary`) e a leg atual.
/// - Seguir a localização em tempo real (stream do `LocationService`).
/// - Calcular progresso por leg e pela rota completa (distância restante).
/// - Gerar instruções textuais simples para a UI.
/// - Notificar listeners (widgets) sempre que houver alterações de estado.
///
/// Este controlador **não** lida com UI ou Mapbox diretamente – apenas expõe
/// informação pronta a consumir pelos widgets (ex.: `NavigationOverlay`).
class NavigationController extends ChangeNotifier {
  /// Cria uma instância do controlador de navegação.
  ///
  /// [routesService] é recebido por injeção de dependência e poderá ser
  /// usado futuramente para lógicas de re-route dinâmico.
  NavigationController(this._routesService);

  /// Serviço de rotas (OTP/backend) – reservado para lógica futura de re-routing.
  final RoutesService _routesService; // futuro re-routing

  /// Itinerário atualmente em navegação (pode ser `null` se não houver navegação).
  OtpItinerary? _activeItinerary;

  /// Índice da leg atual dentro do itinerário ativo.
  ///
  /// Ex.: `0` = primeira leg, `1` = segunda, etc.
  int _currentLegIndex = 0;

  /// Última posição conhecida do utilizador (via GPS).
  Position? _currentPosition;

  /// Indica se existe navegação ativa (true após `startNavigation`).
  bool _isNavigating = false;

  /// Flag reservada para estados de re-route (por agora sempre false).
  bool _isReRouting = false;

  /// Distância total da rota (soma de todas as legs), em metros.
  double _totalDistance = 0.0; // metros

  /// Distância restante até ao destino, em metros.
  double _distanceRemaining = 0.0; // metros

  /// Distância restante apenas na leg atual, em metros.
  double _currentLegDistanceRemaining = 0.0; // metros

  /// Próxima instrução textual a apresentar ao utilizador
  /// (ex.: "Caminha até Porto São Bento").
  String? _nextInstruction;

  /// Lista de geometrias por leg.
  ///
  /// Cada entrada é uma lista de coordenadas `[lat, lon]` obtidas da polyline
  /// da respectiva leg.
  final List<List<List<double>>> _legGeometries = [];

  /// Geometria completa da rota (todas as legs concatenadas).
  ///
  /// Também representada como lista de `[lat, lon]`.
  final List<List<double>> _fullGeometry = [];

  /// Subscrição à stream de localização do `LocationService`.
  ///
  /// É criada em `startNavigation` e cancelada em `stopNavigation`.
  StreamSubscription<Position>? _locationSubscription;

  // ===== GETTERS PÚBLICOS =====

  /// Indica se há navegação ativa.
  bool get isNavigating => _isNavigating;

  /// Indica se o controlador está em modo de re-routing.
  bool get isReRouting => _isReRouting;

  /// Itinerário ativo (ou `null` se não houver navegação).
  OtpItinerary? get activeItinerary => _activeItinerary;

  /// Índice da leg atual (0-based) do itinerário.
  int get currentLegIndex => _currentLegIndex;

  /// Devolve a leg atual do itinerário, ou `null` se não existir.
  OtpLeg? get currentLeg {
    final itin = _activeItinerary;
    if (itin == null) return null;
    if (_currentLegIndex < 0 || _currentLegIndex >= itin.legs.length) {
      return null;
    }
    return itin.legs[_currentLegIndex];
  }

  /// Última posição conhecida do utilizador (ou `null` se ainda não houver).
  Position? get currentPosition => _currentPosition;

  /// Distância total da rota, em metros.
  double get totalDistance => _totalDistance;

  /// Distância total ainda por percorrer, em metros.
  double get distanceRemaining => _distanceRemaining;

  /// Distância restante na leg atual, em metros.
  double get currentLegDistanceRemaining => _currentLegDistanceRemaining;

  /// Progresso total da rota no intervalo `[0, 1]`.
  ///
  /// - `0.0` → início da rota
  /// - `1.0` → fim da rota
  ///
  /// Calculado como `1 - (distanceRemaining / totalDistance)`.
  double get progress {
    if (_totalDistance <= 0) return 0.0;
    return (1.0 - (_distanceRemaining / _totalDistance))
        .clamp(0.0, 1.0);
  }

  /// Progresso da leg atual no intervalo `[0, 1]`.
  ///
  /// - `0.0` → início da leg
  /// - `1.0` → fim da leg
  double get currentLegProgress {
    final leg = currentLeg;
    if (leg == null || leg.distance <= 0) return 0.0;
    return (1.0 - (_currentLegDistanceRemaining / leg.distance))
        .clamp(0.0, 1.0);
  }

  /// Próxima instrução textual a exibir ao utilizador, se existir.
  String? get nextInstruction => _nextInstruction;

  /// Geometria completa da leg atual, como lista de `[lat, lon]`.
  ///
  /// Pode ser usada para desenhar no mapa a leg em curso.
  List<List<double>>? get currentLegGeometry {
    if (_currentLegIndex < 0 || _currentLegIndex >= _legGeometries.length) {
      return null;
    }
    return _legGeometries[_currentLegIndex];
  }

  /// Geometria da leg atual a partir da posição do utilizador.
  ///
  /// A polyline é cortada a partir do ponto mais próximo da posição atual
  /// até ao fim da leg. Isto permite, por exemplo, desenhar apenas o segmento
  /// que falta percorrer.
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

  /// Geometria completa da rota (todas as legs concatenadas).
  List<List<double>> get fullGeometry => _fullGeometry;

  // ===== CONTROLO DE NAVEGAÇÃO =====

  /// Inicia a navegação para o [itinerary] indicado.
  ///
  /// Passos principais:
  /// 1. Cancela qualquer subscrição de localização anterior.
  /// 2. Limpa estado interno (geometrias, distâncias, índices).
  /// 3. Decodifica polylines de cada leg.
  /// 4. Calcula distâncias totais / restantes.
  /// 5. Obtém posição inicial do `LocationService`.
  /// 6. Ativa stream de localização contínua e atualiza progresso.
  ///
  /// [destinationLat] e [destinationLon] são reservados para futura lógica
  /// de verificação de “chegada ao destino” mais precisa.
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

  /// Termina a navegação atual e limpa todo o estado associado.
  ///
  /// Cancela a subscrição de localização, repõe distâncias, geometrias
  /// e flags de navegação, e notifica listeners.
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

  /// Atualiza distâncias restantes (na leg atual e na rota completa)
  /// com base na posição atual do utilizador.
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

  /// Verifica se o utilizador está suficientemente perto do fim da leg atual.
  ///
  /// Se a distância restante na leg for inferior a [thresholdMeters], avança
  /// para a próxima leg (se existir). A última leg não é terminada aqui;
  /// cabe à UI decidir como reagir ao fim da rota.
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

  /// Retorna a coordenada `[lat, lon]` aproximada do fim da leg,
  /// usando o último ponto da polyline correspondente.
  List<double>? _getLegEndCoord(int legIndex) {
    if (legIndex < 0 || legIndex >= _legGeometries.length) return null;
    final geom = _legGeometries[legIndex];
    if (geom.isEmpty) return null;
    return geom.last; // [lat, lon]
  }

  /// Constrói uma instrução textual simples para a leg com índice [index].
  ///
  /// A lógica é baseada no `mode` da leg e em nomes de origem/destino.
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

  /// Calcula a distância em metros entre dois pontos geográficos
  /// usando a fórmula de Haversine.
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

  /// Converte graus em radianos.
  double _deg2rad(double deg) => deg * (math.pi / 180.0);
}
