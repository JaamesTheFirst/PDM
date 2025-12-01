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
      final emissionFactor = _defaultEmissionFactors[mode] ?? 0.0;
      
      // For transit modes, divide by occupancy to get per-passenger CO2
      final occupancy = _defaultOccupancyRates[mode];
      double legCo2Kg;
      
      if (occupancy != null && occupancy > 0) {
        // Transit mode: per-passenger CO2 = (emission_factor * distance) / occupancy
        legCo2Kg = (emissionFactor * distanceKm) / occupancy;
      } else {
        // Non-transit mode (walking, bike, car, etc.): direct calculation
        legCo2Kg = emissionFactor * distanceKm;
      }

      totalCo2Kg += legCo2Kg;

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

    // Calculate score (0-100)
    // Lower CO2 per km = higher score
    // Use a more granular scale that differentiates low-emission routes
    // Score formula: 100 * (1 - (co2PerKm / maxCo2PerKm))^1.5
    // The exponent makes the scale more sensitive to differences in low-emission routes
    double baseScore = 0.0;
    if (co2PerKm <= 0.0) {
      // Zero emissions (walking, cycling)
      baseScore = 100.0;
    } else if (co2PerKm >= _maxCo2PerKm) {
      // Very high emissions
      baseScore = 0.0;
    } else {
      // Use a power curve to make low-emission routes more differentiated
      // This ensures routes with 0.001 vs 0.01 kg/km get different scores
      final ratio = co2PerKm / _maxCo2PerKm;
      baseScore = 100.0 * (1.0 - (ratio * ratio)); // Square the ratio for better granularity
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
    if (co2PerKm < 0.0001) {
      return '0 g/km';
    } else if (co2PerKm < 0.001) {
      return '${(co2PerKm * 1000000).toStringAsFixed(0)} mg/km';
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

