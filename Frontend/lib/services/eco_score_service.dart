import 'package:flutter/foundation.dart';

import '../services/routes_service.dart';

/// Default emission factors (kg CO₂ per km) when backend data is unavailable.
///
/// Valores baseados em literatura típica para Portugal/Europa.
/// A chave do mapa é o modo de transporte em maiúsculas.
const Map<String, double> _defaultEmissionFactors = <String, double>{
  'WALK': 0.0,
  'WALKING': 0.0,
  'BICYCLE': 0.0,
  'BIKE': 0.0,
  'BIKE_SHARE': 0.0,
  'SCOOTER': 0.0,
  'SCOOTER_SHARE': 0.0,
  'BUS': 0.089, // Average bus in Portugal
  'TRAM': 0.03, // Electric tram
  'METRO': 0.03, // Electric metro
  'RAIL': 0.014, // Electric train (Portugal's trains are mostly electric)
  'TRAIN': 0.014,
  'R': 0.014, // Regular rail (same as RAIL)
  'IC': 0.014, // Intercity train (same as RAIL)
  'CAR': 0.120, // Average car
  'TAXI': 0.120,
  'EV_CAR': 0.0, // Electric car (assuming renewable energy)
  'COACH': 0.027, // Long-distance bus
  'FLIXBUS': 0.027, // FlixBus (long-distance bus)
};

/// Default occupancy rates (passengers per vehicle).
///
/// Usado para calcular emissões por passageiro:
/// `co2_per_passenger = (co2_per_km * distance_km) / occupancy`.
const Map<String, double> _defaultOccupancyRates = <String, double>{
  'BUS': 20.0, // Average bus occupancy
  'TRAM': 50.0,
  'METRO': 100.0,
  'RAIL': 150.0,
  'TRAIN': 150.0,
  'R': 150.0, // Regular rail (same as RAIL)
  'IC': 120.0, // Intercity train (lower occupancy than regional trains)
  'COACH': 30.0,
  'FLIXBUS': 30.0, // FlixBus (same as COACH)
  'CAR': 1.5, // Average car occupancy
  'TAXI': 1.0,
};

/// CO₂ baseline para cálculo do score (kg CO₂ / km de uma viagem típica de carro).
/// Rotas abaixo deste valor recebem pontuações mais altas.
const double _baselineCo2PerKm = 0.120;

/// Máximo de CO₂ por km para cálculo do score.
/// Rotas acima deste valor recebem pontuação 0.
const double _maxCo2PerKm = 0.200;

/// Resultado de cálculo de Eco Score para um itinerário.
///
/// Contém:
/// - [co2Kg]: emissões totais estimadas em kg.
/// - [co2PerKm]: emissões médias por km.
/// - [score]: valor de 0 a 100 (quanto maior, mais ecológico).
/// - [hasPhysicalActivity]: se inclui modos com actividade física.
/// - [primaryMode]: modo principal da viagem (ex.: BUS, RAIL, WALKING).
class EcoScoreResult {
  final double co2Kg;
  final double co2PerKm;
  final int score; // 0-100
  final bool hasPhysicalActivity;
  final String? primaryMode;

  const EcoScoreResult({
    required this.co2Kg,
    required this.co2PerKm,
    required this.score,
    required this.hasPhysicalActivity,
    this.primaryMode,
  });
}

/// Serviço responsável por calcular emissões de CO₂ e Eco Score
/// para itinerários provenientes do OTP.
///
/// Uso típico:
/// ```dart
/// final result = EcoScoreService.instance.calculateScore(itinerary);
/// print(result.score);      // 0–100
/// print(result.co2Kg);      // emissões totais em kg
/// print(result.co2PerKm);   // emissões por km
/// ```
class EcoScoreService {
  EcoScoreService._();

  /// Instância singleton do [EcoScoreService].
  static final EcoScoreService instance = EcoScoreService._();

  /// Calcula emissões de CO₂ e Eco Score para um [OtpItinerary].
  ///
  /// Passos principais:
  /// 1. Para cada leg:
  ///    - Determina factor de emissão por modo.
  ///    - Se for modo de transporte público, divide por *occupancy*.
  ///    - Acumula emissões totais e distância total.
  /// 2. Calcula `co2PerKm = totalCo2Kg / totalDistanceKm`.
  /// 3. Aplica regras especiais:
  ///    - Rotas 100% zero-emissão → score 100.
  ///    - Rotas apenas de carro → penalização forte.
  ///    - Bónus para actividade física (+10).
  ///
  /// Devolve um [EcoScoreResult] com valores já arredondados/prontos para UI.
  EcoScoreResult calculateScore(OtpItinerary itinerary) {
    double totalCo2Kg = 0.0;
    double totalDistanceKm = 0.0;
    bool hasPhysicalActivity = false;
    String? primaryMode;

    // Calcular CO₂ para cada leg.
    for (final OtpLeg leg in itinerary.legs) {
      final String mode = leg.mode.toUpperCase();
      final double distanceKm = leg.distance / 1000.0; // m → km
      totalDistanceKm += distanceKm;

      // Factor de emissão base para este modo.
      double emissionFactor = _defaultEmissionFactors[mode] ?? 0.0;

      // Se não encontrarmos o modo directamente, tentamos heurísticas
      // para agrupar variações do OTP.
      if (emissionFactor == 0.0 && mode != 'WALK' && mode != 'WALKING') {
        if (mode.contains('RAIL') ||
            mode.contains('TRAIN') ||
            mode == 'R' ||
            mode == 'IC') {
          emissionFactor = _defaultEmissionFactors['RAIL'] ?? 0.014;
        } else if (mode.contains('BUS') || mode == 'COACH') {
          emissionFactor = _defaultEmissionFactors['BUS'] ?? 0.089;
        } else if (mode.contains('METRO') || mode.contains('SUBWAY')) {
          emissionFactor = _defaultEmissionFactors['METRO'] ?? 0.03;
        } else if (mode.contains('TRAM')) {
          emissionFactor = _defaultEmissionFactors['TRAM'] ?? 0.03;
        }
      }

      // Ocupação média para modos de transporte público.
      double? occupancy = _defaultOccupancyRates[mode];

      if (occupancy == null && mode != 'WALK' && mode != 'WALKING') {
        if (mode.contains('RAIL') ||
            mode.contains('TRAIN') ||
            mode == 'R' ||
            mode == 'IC') {
          occupancy = mode == 'IC' ? 120.0 : 150.0;
        } else if (mode.contains('BUS') || mode == 'COACH') {
          occupancy = mode == 'FLIXBUS' || mode == 'COACH' ? 30.0 : 20.0;
        } else if (mode.contains('METRO') || mode.contains('SUBWAY')) {
          occupancy = 100.0;
        } else if (mode.contains('TRAM')) {
          occupancy = 50.0;
        }
      }

      // Cálculo de CO₂ para a leg.
      final double legCo2Kg;
      if (occupancy != null && occupancy > 0) {
        // Modo de transporte público: valor por passageiro.
        legCo2Kg = (emissionFactor * distanceKm) / occupancy;
      } else {
        // Modos directos (walk, bike, car, etc.): uso directo do factor.
        legCo2Kg = emissionFactor * distanceKm;
      }

      totalCo2Kg += legCo2Kg;

      debugPrint(
        '[EcoScore] Leg: mode=$mode, '
        'distance=${distanceKm.toStringAsFixed(2)}km, '
        'emissionFactor=$emissionFactor, '
        'occupancy=$occupancy, '
        'legCo2=${(legCo2Kg * 1000).toStringAsFixed(2)}g',
      );

      // Modos com actividade física.
      if (mode == 'WALK' ||
          mode == 'WALKING' ||
          mode == 'BICYCLE' ||
          mode == 'BIKE' ||
          mode == 'BIKE_SHARE' ||
          mode == 'SCOOTER' ||
          mode == 'SCOOTER_SHARE') {
        hasPhysicalActivity = true;
      }

      // Modo principal (primeira leg não-walking).
      if (primaryMode == null && mode != 'WALK' && mode != 'WALKING') {
        primaryMode = mode;
      }
    }

    // Se todas as legs forem walking, definimos modo principal como WALKING.
    primaryMode ??= 'WALKING';

    // CO₂ por km (evita divisão por zero).
    final double co2PerKm =
        totalDistanceKm > 0 ? totalCo2Kg / totalDistanceKm : 0.0;

    debugPrint(
      '[EcoScore] Total: distance=${totalDistanceKm.toStringAsFixed(2)}km, '
      'totalCo2=${(totalCo2Kg * 1000).toStringAsFixed(2)}g, '
      'co2PerKm=${(co2PerKm * 1000).toStringAsFixed(3)}g/km',
    );

    // Verificar se rota usa ONLY modos zero-emissão.
    bool isOnlyZeroEmission = true;
    for (final OtpLeg leg in itinerary.legs) {
      final String mode = leg.mode.toUpperCase();

      double emissionFactor = _defaultEmissionFactors[mode] ?? 0.0;

      if (emissionFactor == 0.0 && mode != 'WALK' && mode != 'WALKING') {
        if (mode.contains('RAIL') ||
            mode.contains('TRAIN') ||
            mode == 'R' ||
            mode == 'IC') {
          emissionFactor = _defaultEmissionFactors['RAIL'] ?? 0.014;
        } else if (mode.contains('BUS') || mode == 'COACH') {
          emissionFactor = _defaultEmissionFactors['BUS'] ?? 0.089;
        } else if (mode.contains('METRO') || mode.contains('SUBWAY')) {
          emissionFactor = _defaultEmissionFactors['METRO'] ?? 0.03;
        } else if (mode.contains('TRAM')) {
          emissionFactor = _defaultEmissionFactors['TRAM'] ?? 0.03;
        } else if (mode == 'CAR' || mode == 'TAXI') {
          emissionFactor = _defaultEmissionFactors['CAR'] ?? 0.120;
        }
      }

      if (emissionFactor > 0.0) {
        isOnlyZeroEmission = false;
        debugPrint(
          '[EcoScore] Route is NOT zero-emission: '
          'found mode=$mode with emissions=$emissionFactor',
        );
        break;
      }
    }

    debugPrint(
      '[EcoScore] isOnlyZeroEmission=$isOnlyZeroEmission, '
      'co2PerKm=${(co2PerKm * 1000).toStringAsFixed(3)}g/km',
    );

    // Verificar se rota é apenas de carro (descontando walking).
    bool isCarOnly = true;
    for (final OtpLeg leg in itinerary.legs) {
      final String mode = leg.mode.toUpperCase();
      if (mode != 'WALK' &&
          mode != 'WALKING' &&
          mode != 'CAR' &&
          !mode.contains('CAR')) {
        isCarOnly = false;
        break;
      }
    }

    if (isCarOnly &&
        itinerary.legs.any((OtpLeg leg) =>
            leg.mode.toUpperCase() == 'CAR' ||
            leg.mode.toUpperCase().contains('CAR'))) {
      isCarOnly = true;
    } else {
      isCarOnly = false;
    }

    // Verificar se usa autocarros a combustíveis fósseis (diesel).
    bool hasFossilBus = false;
    for (final OtpLeg leg in itinerary.legs) {
      final String mode = leg.mode.toUpperCase();
      if (mode.contains('BUS') &&
          !mode.contains('ELECTRIC') &&
          !mode.contains('HYBRID')) {
        hasFossilBus = true;
        break;
      }
    }

    // Cálculo da pontuação base (0–100).
    double baseScore = 0.0;

    if (isOnlyZeroEmission && co2PerKm <= 0.0001) {
      // Apenas modos zero-emissão → score máximo.
      baseScore = 100.0;
    } else if (isCarOnly) {
      // Rotas só de carro: penalização forte.
      final double co2PerKmGram = co2PerKm * 1000; // kg/km → g/km
      if (co2PerKmGram >= 120) {
        baseScore = 0.0;
      } else if (co2PerKmGram >= 80) {
        baseScore =
            20 - ((co2PerKmGram - 80) / 40) * 20; // 80g/km = 20, 120g/km = 0
      } else {
        baseScore = 20.0;
      }
    } else if (co2PerKm >= _maxCo2PerKm) {
      // Emissões muito altas.
      baseScore = 0.0;
    } else {
      // Função por partes, mais detalhada por faixa de emissões.
      final double co2PerKmGram = co2PerKm * 1000; // kg/km → g/km

      if (co2PerKmGram <= 0.1) {
        // 0–0.1 g/km: comboios muito eficientes (90–95).
        baseScore = 95 - (co2PerKmGram / 0.1) * 5;
      } else if (co2PerKmGram <= 1) {
        // 0.1–1 g/km: transit eléctrico eficiente (80–90).
        baseScore = 90 - ((co2PerKmGram - 0.1) / 0.9) * 10;
      } else if (co2PerKmGram <= 5) {
        // 1–5 g/km: transit misto, alguns fósseis (60–80).
        baseScore = 80 - ((co2PerKmGram - 1) / 4) * 20;
      } else if (co2PerKmGram <= 20) {
        // 5–20 g/km: emissões médias (40–60).
        baseScore = 60 - ((co2PerKmGram - 5) / 15) * 20;
      } else if (co2PerKmGram <= 50) {
        // 20–50 g/km: emissões altas (20–40).
        baseScore = 40 - ((co2PerKmGram - 20) / 30) * 20;
      } else {
        // 50–200 g/km: emissões muito altas (0–20).
        baseScore = 20 - ((co2PerKmGram - 50) / 150) * 20;
      }

      // Penalização extra para autocarros fósseis.
      if (hasFossilBus) {
        baseScore = (baseScore - 18).clamp(0.0, 100.0);
        debugPrint(
          '[EcoScore] Applied fossil bus penalty: '
          'score reduced by 18 points',
        );
      }
    }

    // Bónus de actividade física (se ainda não estiver em 100).
    if (hasPhysicalActivity && baseScore < 100.0) {
      baseScore = (baseScore + 10.0).clamp(0.0, 100.0);
    }

    return EcoScoreResult(
      co2Kg: totalCo2Kg,
      co2PerKm: co2PerKm,
      score: baseScore.round(),
      hasPhysicalActivity: hasPhysicalActivity,
      primaryMode: primaryMode,
    );
  }

  /// Formata valores de CO₂ totais para apresentação.
  ///
  /// - < 0.001 kg → `"0 g"`
  /// - < 1 kg     → `"XYZ g"`
  /// - >= 1 kg    → `"X.YZ kg"`
  String formatCo2(double co2Kg) {
    if (co2Kg < 0.001) {
      return '0 g';
    } else if (co2Kg < 1.0) {
      return '${(co2Kg * 1000).toStringAsFixed(0)} g';
    } else {
      return '${co2Kg.toStringAsFixed(2)} kg';
    }
  }

  /// Formata emissões por km para apresentação.
  ///
  /// Ajusta a unidade automaticamente:
  /// - Valores muito pequenos → mg/km
  /// - Intermédios → g/km
  /// - Grandes → kg/km
  String formatCo2PerKm(double co2PerKm) {
    // Threshold mais baixo para mostrar valores muito pequenos (0.01 g/km).
    if (co2PerKm < 0.00001) {
      return '0 g/km';
    } else if (co2PerKm < 0.001) {
      // 0.01–1 g/km → mg/km.
      final double mgPerKm = co2PerKm * 1000000;
      if (mgPerKm < 10) {
        return '${mgPerKm.toStringAsFixed(1)} mg/km';
      } else {
        return '${mgPerKm.toStringAsFixed(0)} mg/km';
      }
    } else if (co2PerKm < 1.0) {
      return '${(co2PerKm * 1000).toStringAsFixed(1)} g/km';
    } else {
      return '${co2PerKm.toStringAsFixed(2)} kg/km';
    }
  }

  /// Devolve a cor (ARGB) recomendada para desenhar o Eco Score.
  ///
  /// Os intervalos são:
  /// - 80–100 → verde "eco mint" (`0xFF3CD4A0`)
  /// - 60–79  → verde (`0xFF4CAF50`)
  /// - 40–59  → âmbar (`0xFFFFC107`)
  /// - 0–39   → laranja/vermelho (`0xFFFF5722`)
  int getScoreColor(int score) {
    if (score >= 80) {
      return 0xFF3CD4A0; // Eco mint (green)
    } else if (score >= 60) {
      return 0xFF4CAF50; // Green
    } else if (score >= 40) {
      return 0xFFFFC107; // Amber
    } else {
      return 0xFFFF5722; // Deep orange/red
    }
  }
}
