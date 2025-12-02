import '../services/routes_service.dart';

/// Default emission factors (kg CO2 per km) when backend data is unavailable
/// Sources: Typical values for Portugal/Europe
const Map<String, double> _defaultEmissionFactors = {
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

/// Default occupancy rates (passengers per vehicle)
/// Used to calculate per-passenger CO2: co2_per_passenger = co2_per_km / occupancy
const Map<String, double> _defaultOccupancyRates = {
  'BUS': 20.0, // Average bus occupancy
  'TRAM': 50.0,
  'METRO': 100.0,
  'RAIL': 150.0,
  'TRAIN': 150.0,
  'R': 150.0, // Regular rail (same as RAIL)
  'IC': 150.0, // Intercity train (same as RAIL)
  'COACH': 30.0,
  'FLIXBUS': 30.0, // FlixBus (same as COACH)
  'CAR': 1.5, // Average car occupancy
  'TAXI': 1.0,
};

/// CO2 baseline for score calculation (kg CO2 per km for a typical car trip)
/// Routes below this get higher scores
const double _baselineCo2PerKm = 0.120;

/// Maximum CO2 per km for score calculation (routes above this get score 0)
const double _maxCo2PerKm = 0.200;

class EcoScoreResult {
  final double co2Kg;
  final double co2PerKm;
  final int score; // 0-100
  final bool hasPhysicalActivity;
  final String? primaryMode;

  EcoScoreResult({
    required this.co2Kg,
    required this.co2PerKm,
    required this.score,
    required this.hasPhysicalActivity,
    this.primaryMode,
  });
}

class EcoScoreService {
  EcoScoreService._();
  static final EcoScoreService instance = EcoScoreService._();

  /// Calculate CO2 emissions and Eco Score for an itinerary
  EcoScoreResult calculateScore(OtpItinerary itinerary) {
    double totalCo2Kg = 0.0;
    double totalDistanceKm = 0.0;
    bool hasPhysicalActivity = false;
    String? primaryMode;

    // Calculate CO2 for each leg
    for (final leg in itinerary.legs) {
      final mode = leg.mode.toUpperCase();
      final distanceKm = leg.distance / 1000.0; // Convert meters to km
      totalDistanceKm += distanceKm;

      // Get emission factor for this mode
      // Handle OTP mode variations (R, IC might come as RAIL, TRANSIT, etc.)
      double emissionFactor = _defaultEmissionFactors[mode] ?? 0.0;
      
      // If mode not found, try to match common OTP variations
      if (emissionFactor == 0.0 && mode != 'WALK' && mode != 'WALKING') {
        if (mode.contains('RAIL') || mode.contains('TRAIN') || mode == 'R' || mode == 'IC') {
          emissionFactor = _defaultEmissionFactors['RAIL'] ?? 0.014;
        } else if (mode.contains('BUS') || mode == 'COACH') {
          emissionFactor = _defaultEmissionFactors['BUS'] ?? 0.089;
        } else if (mode.contains('METRO') || mode.contains('SUBWAY')) {
          emissionFactor = _defaultEmissionFactors['METRO'] ?? 0.03;
        } else if (mode.contains('TRAM')) {
          emissionFactor = _defaultEmissionFactors['TRAM'] ?? 0.03;
        }
      }
      
      // For transit modes, divide by occupancy to get per-passenger CO2
      double? occupancy = _defaultOccupancyRates[mode];
      
      // If occupancy not found, try to match common OTP variations
      if (occupancy == null && mode != 'WALK' && mode != 'WALKING') {
        if (mode.contains('RAIL') || mode.contains('TRAIN') || mode == 'R' || mode == 'IC') {
          occupancy = mode == 'IC' ? 120.0 : 150.0; // IC has lower occupancy
        } else if (mode.contains('BUS') || mode == 'COACH') {
          occupancy = mode == 'FLIXBUS' || mode == 'COACH' ? 30.0 : 20.0;
        } else if (mode.contains('METRO') || mode.contains('SUBWAY')) {
          occupancy = 100.0;
        } else if (mode.contains('TRAM')) {
          occupancy = 50.0;
        }
      }
      
      double legCo2Kg;
      
      if (occupancy != null && occupancy > 0) {
        // Transit mode: per-passenger CO2 = (emission_factor * distance) / occupancy
        legCo2Kg = (emissionFactor * distanceKm) / occupancy;
      } else {
        // Non-transit mode (walking, bike, car, etc.): direct calculation
        legCo2Kg = emissionFactor * distanceKm;
      }

      totalCo2Kg += legCo2Kg;
      
      // Debug logging
      print('[EcoScore] Leg: mode=$mode, distance=${distanceKm.toStringAsFixed(2)}km, emissionFactor=$emissionFactor, occupancy=$occupancy, legCo2=${(legCo2Kg * 1000).toStringAsFixed(2)}g');

      // Check for physical activity modes
      if (mode == 'WALK' || mode == 'WALKING' || 
          mode == 'BICYCLE' || mode == 'BIKE' || 
          mode == 'BIKE_SHARE' || mode == 'SCOOTER' || 
          mode == 'SCOOTER_SHARE') {
        hasPhysicalActivity = true;
      }

      // Determine primary mode (first non-walking leg, or walking if all walking)
      if (primaryMode == null && mode != 'WALK' && mode != 'WALKING') {
        primaryMode = mode;
      }
    }

    // If all legs are walking, set primary mode to WALKING
    if (primaryMode == null) {
      primaryMode = 'WALKING';
    }

    // Calculate CO2 per km
    final co2PerKm = totalDistanceKm > 0 ? totalCo2Kg / totalDistanceKm : 0.0;
    
    // Debug logging
    print('[EcoScore] Total: distance=${totalDistanceKm.toStringAsFixed(2)}km, totalCo2=${(totalCo2Kg * 1000).toStringAsFixed(2)}g, co2PerKm=${(co2PerKm * 1000).toStringAsFixed(3)}g/km');

    // Check if route uses ONLY zero-emission modes (walking, biking, scooter)
    // This is stricter - only pure active transport gets 100
    bool isOnlyZeroEmission = true;
    for (final leg in itinerary.legs) {
      final mode = leg.mode.toUpperCase();
      
      // Use the same mode matching logic as in the calculation
      double emissionFactor = _defaultEmissionFactors[mode] ?? 0.0;
      
      // If mode not found, try to match common OTP variations
      if (emissionFactor == 0.0 && mode != 'WALK' && mode != 'WALKING') {
        if (mode.contains('RAIL') || mode.contains('TRAIN') || mode == 'R' || mode == 'IC') {
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
      
      // If any leg has emissions, it's not pure zero-emission
      if (emissionFactor > 0.0) {
        isOnlyZeroEmission = false;
        print('[EcoScore] Route is NOT zero-emission: found mode=$mode with emissions=$emissionFactor');
        break;
      }
    }
    
    print('[EcoScore] isOnlyZeroEmission=$isOnlyZeroEmission, co2PerKm=${(co2PerKm * 1000).toStringAsFixed(3)}g/km');

    // Check if route is car-only (least efficient)
    bool isCarOnly = true;
    for (final leg in itinerary.legs) {
      final mode = leg.mode.toUpperCase();
      if (mode != 'WALK' && mode != 'WALKING' && mode != 'CAR' && !mode.contains('CAR')) {
        isCarOnly = false;
        break;
      }
    }
    // If all non-walking legs are car, it's car-only
    if (isCarOnly && itinerary.legs.any((leg) => leg.mode.toUpperCase() == 'CAR' || leg.mode.toUpperCase().contains('CAR'))) {
      isCarOnly = true;
    } else {
      isCarOnly = false;
    }

    // Calculate score (0-100)
    // Lower CO2 per km = higher score
    // Use a more granular scale that differentiates low-emission routes
    double baseScore = 0.0;
    
    if (isOnlyZeroEmission && co2PerKm <= 0.0001) {
      // ONLY zero-emission modes (walking, cycling, scooter) - strict requirement
      baseScore = 100.0;
    } else if (isCarOnly) {
      // Car-only routes get the lowest scores (strict penalty)
      // Car emits ~120 g/km, so it should score very low
      final co2PerKmGram = co2PerKm * 1000; // Convert to g/km
      // For car-only: 80-120 g/km -> 0-20 score (very strict)
      if (co2PerKmGram >= 120) {
        baseScore = 0.0;
      } else if (co2PerKmGram >= 80) {
        baseScore = 20 - ((co2PerKmGram - 80) / 40) * 20; // 80g/km = 20, 120g/km = 0
      } else {
        baseScore = 20.0; // Cap at 20 for car-only
      }
    } else if (co2PerKm >= _maxCo2PerKm) {
      // Very high emissions
      baseScore = 0.0;
    } else {
      // Use a piecewise function for better differentiation
      // 0-10 g/km -> 80-95
      // 10-50 g/km -> 60-80
      // 50-200 g/km -> 0-60
      final co2PerKmGram = co2PerKm * 1000; // Convert to g/km

      if (co2PerKmGram <= 1) {
        // From 0.1 to 1 g/km, score goes from 95 to 85
        // Very low emissions (electric trains) still get high scores but not 100
        baseScore = 95 - (co2PerKmGram / 1) * 10;
      } else if (co2PerKmGram <= 10) {
        // From 1 to 10 g/km, score goes from 85 to 70
        baseScore = 85 - ((co2PerKmGram - 1) / 9) * 15;
      } else if (co2PerKmGram <= 50) {
        // From 10 to 50 g/km, score goes from 70 to 50
        baseScore = 70 - ((co2PerKmGram - 10) / 40) * 20;
      } else {
        // From 50 to 200 g/km, score goes from 50 to 0
        baseScore = 50 - ((co2PerKmGram - 50) / 150) * 50;
      }
    }

    // Physical activity bonus (only if not already at 100)
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

  /// Format CO2 for display
  String formatCo2(double co2Kg) {
    if (co2Kg < 0.001) {
      return '0 g';
    } else if (co2Kg < 1.0) {
      return '${(co2Kg * 1000).toStringAsFixed(0)} g';
    } else {
      return '${co2Kg.toStringAsFixed(2)} kg';
    }
  }

  /// Format CO2 per km for display
  String formatCo2PerKm(double co2PerKm) {
    // Lower threshold to show very small values (0.01 g/km instead of 0.1 g/km)
    if (co2PerKm < 0.00001) { // 0.01 g/km threshold
      return '0 g/km';
    } else if (co2PerKm < 0.001) {
      // Show in mg/km for very small values (0.01-1 g/km)
      final mgPerKm = co2PerKm * 1000000;
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

  /// Get color for score display
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

