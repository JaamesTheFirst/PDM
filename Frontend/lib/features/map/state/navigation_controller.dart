import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/routes_service.dart';
import '../../../services/location_service.dart';
import 'package:sustainable_transport_app/utils/polyline_decoder.dart';

class NavigationController extends ChangeNotifier {
  NavigationController(this._routesService);

  final RoutesService _routesService;

  OtpItinerary? _activeItinerary;
  Position? _currentPosition;
  int _currentLegIndex = 0;
  bool _isNavigating = false;
  StreamSubscription<Position>? _locationSubscription;
  double _distanceRemaining = 0.0;
  double _totalDistance = 0.0;
  String? _nextInstruction;
  
  // Re-routing
  double? _destinationLat;
  double? _destinationLon;
  bool _isReRouting = false;
  DateTime? _lastDeviationCheck;
  static const double _deviationThreshold = 100.0; // meters
  static const Duration _deviationCheckInterval = Duration(seconds: 5);

  OtpItinerary? get activeItinerary => _activeItinerary;
  Position? get currentPosition => _currentPosition;
  int get currentLegIndex => _currentLegIndex;
  bool get isNavigating => _isNavigating;
  double get distanceRemaining => _distanceRemaining;
  double get totalDistance => _totalDistance;
  String? get nextInstruction => _nextInstruction;
  double get progress => _totalDistance > 0 
      ? ((_totalDistance - _distanceRemaining) / _totalDistance).clamp(0.0, 1.0)
      : 0.0;
  bool get isReRouting => _isReRouting;

  /// Start navigation with the given itinerary
  Future<void> startNavigation(OtpItinerary itinerary, {double? destinationLat, double? destinationLon}) async {
    if (_isNavigating) {
      stopNavigation();
    }

    _activeItinerary = itinerary;
    _currentLegIndex = 0;
    _isNavigating = true;
    _isReRouting = false;
    _lastDeviationCheck = null;
    
    // Store destination for re-routing
    if (destinationLat != null && destinationLon != null) {
      _destinationLat = destinationLat;
      _destinationLon = destinationLon;
    } else if (itinerary.legs.isNotEmpty) {
      // Extract destination from last leg
      final lastLeg = itinerary.legs.last;
      if (lastLeg.polyline != null && lastLeg.polyline!.isNotEmpty) {
        try {
          final decoded = decodePolyline(lastLeg.polyline!);
          if (decoded.isNotEmpty) {
            _destinationLat = decoded.last[0];
            _destinationLon = decoded.last[1];
          }
        } catch (e) {
          print('[NavigationController] Error extracting destination: $e');
        }
      }
    }
    
    // Calculate total distance
    _totalDistance = itinerary.legs.fold(0.0, (sum, leg) => sum + leg.distance);
    _distanceRemaining = _totalDistance;

    // Setup mock location if enabled (for testing)
    const useMockLocation = bool.fromEnvironment('MOCK_LOCATION', defaultValue: false);
    if (useMockLocation) {
      // Extract all route points from itinerary
      final allRoutePoints = <List<double>>[];
      for (final leg in itinerary.legs) {
        if (leg.polyline != null && leg.polyline!.isNotEmpty) {
          try {
            final decoded = decodePolyline(leg.polyline!);
            for (final point in decoded) {
              allRoutePoints.add([point[0], point[1]]);
            }
          } catch (e) {
            print('[NavigationController] Error decoding polyline for mock: $e');
          }
        }
      }
      if (allRoutePoints.isNotEmpty) {
        LocationService.instance.setMockRoute(allRoutePoints, speed: 5.0); // 5 meters per second
        print('[NavigationController] Mock location enabled with ${allRoutePoints.length} points');
      }
    }

    // Get current position
    _currentPosition = await LocationService.instance.getCurrentLocation();
    
    // Start listening to location updates
    _locationSubscription = LocationService.instance.getLocationUpdates().listen(
      (position) {
        _currentPosition = position;
        _updateProgress();
        _checkForDeviation();
        notifyListeners();
      },
    );

    _updateNextInstruction();
    notifyListeners();
  }

  /// Stop navigation
  void stopNavigation() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _isNavigating = false;
    _activeItinerary = null;
    _currentLegIndex = 0;
    _currentPosition = null;
    _distanceRemaining = 0.0;
    _totalDistance = 0.0;
    _nextInstruction = null;
    _isReRouting = false;
    _destinationLat = null;
    _destinationLon = null;
    _lastDeviationCheck = null;
    
    // Stop mock location if enabled
    const useMockLocation = bool.fromEnvironment('MOCK_LOCATION', defaultValue: false);
    if (useMockLocation) {
      LocationService.instance.stopMockLocation();
    }
    
    notifyListeners();
  }

  /// Update progress based on current position
  void _updateProgress() {
    if (_activeItinerary == null || _currentPosition == null) return;

    final legs = _activeItinerary!.legs;
    if (legs.isEmpty) return;

    // Calculate distance remaining from current position to destination
    double remaining = 0.0;
    bool foundCurrentLeg = false;

    for (int i = _currentLegIndex; i < legs.length; i++) {
      final leg = legs[i];
      
      if (!foundCurrentLeg) {
        // Try to calculate distance using polyline
        if (leg.polyline != null && leg.polyline!.isNotEmpty) {
          try {
            final decoded = decodePolyline(leg.polyline!);
            if (decoded.isNotEmpty) {
              // Find closest point on polyline to current position
              double minDist = double.infinity;
              int closestIndex = 0;
              
              for (int j = 0; j < decoded.length; j++) {
                final dist = Geolocator.distanceBetween(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  decoded[j][0],
                  decoded[j][1],
                );
                if (dist < minDist) {
                  minDist = dist;
                  closestIndex = j;
                }
              }
              
              // Calculate distance from closest point to end of leg
              double legRemaining = 0.0;
              for (int j = closestIndex; j < decoded.length - 1; j++) {
                legRemaining += Geolocator.distanceBetween(
                  decoded[j][0],
                  decoded[j][1],
                  decoded[j + 1][0],
                  decoded[j + 1][1],
                );
              }
              
              // If we're very close to the end of this leg, move to next
              if (legRemaining < 50 && i + 1 < legs.length) {
                _currentLegIndex = i + 1;
                foundCurrentLeg = true;
                remaining += legs[i + 1].distance;
                continue;
              } else {
                remaining += legRemaining;
                foundCurrentLeg = true;
                continue;
              }
            }
          } catch (e) {
            print('[NavigationController] Error decoding polyline: $e');
          }
        }
        
        // Fallback: use leg distance
        remaining += leg.distance;
        foundCurrentLeg = true;
      } else {
        remaining += leg.distance;
      }
    }

    _distanceRemaining = remaining;
    _updateNextInstruction();
  }

  /// Update the next instruction based on current leg
  void _updateNextInstruction() {
    if (_activeItinerary == null) {
      _nextInstruction = null;
      return;
    }

    final legs = _activeItinerary!.legs;
    if (_currentLegIndex >= legs.length) {
      _nextInstruction = 'Chegou ao destino!';
      return;
    }

    final currentLeg = legs[_currentLegIndex];
    final mode = currentLeg.mode.toUpperCase();
    
    String instruction = '';
    
    if (mode == 'WALK' || mode == 'WALKING') {
      instruction = 'Continue a pé';
    } else if (mode == 'BICYCLE' || mode == 'BIKE') {
      if (currentLeg.rentedBike == true) {
        instruction = 'Pegue uma GIRA';
      } else {
        instruction = 'Continue de bicicleta';
      }
    } else if (mode.contains('BUS')) {
      instruction = 'Pegue o autocarro ${currentLeg.routeName ?? ''}';
    } else if (mode.contains('RAIL') || mode.contains('TRAIN')) {
      instruction = 'Pegue o comboio ${currentLeg.routeName ?? ''}';
    } else if (mode.contains('METRO')) {
      instruction = 'Pegue o metro ${currentLeg.routeName ?? ''}';
    } else if (mode.contains('TRAM')) {
      instruction = 'Pegue o eléctrico ${currentLeg.routeName ?? ''}';
    } else {
      instruction = 'Continue';
    }

    if (_currentLegIndex + 1 < legs.length) {
      final nextLeg = legs[_currentLegIndex + 1];
      if (nextLeg.mode.toUpperCase() == 'WALK' || nextLeg.mode.toUpperCase() == 'WALKING') {
        instruction += ' até ${currentLeg.toName}';
      }
    } else {
      instruction += ' até ${currentLeg.toName}';
    }

    _nextInstruction = instruction;
  }

  /// Get current leg
  OtpLeg? get currentLeg {
    if (_activeItinerary == null) return null;
    final legs = _activeItinerary!.legs;
    if (_currentLegIndex >= 0 && _currentLegIndex < legs.length) {
      return legs[_currentLegIndex];
    }
    return null;
  }

  /// Get remaining legs
  List<OtpLeg> get remainingLegs {
    if (_activeItinerary == null) return [];
    final legs = _activeItinerary!.legs;
    if (_currentLegIndex + 1 < legs.length) {
      return legs.sublist(_currentLegIndex + 1);
    }
    return [];
  }

  /// Check if user has deviated from the route
  void _checkForDeviation() {
    if (_activeItinerary == null || _currentPosition == null) return;
    if (_isReRouting) return; // Don't check while re-routing
    
    // Throttle deviation checks
    final now = DateTime.now();
    if (_lastDeviationCheck != null && 
        now.difference(_lastDeviationCheck!) < _deviationCheckInterval) {
      return;
    }
    _lastDeviationCheck = now;

    final legs = _activeItinerary!.legs;
    if (legs.isEmpty) return;

    // Check distance from current leg's polyline
    double minDistanceToRoute = double.infinity;
    
    for (int i = _currentLegIndex; i < legs.length; i++) {
      final leg = legs[i];
      if (leg.polyline == null || leg.polyline!.isEmpty) continue;
      
      try {
        final decoded = decodePolyline(leg.polyline!);
        if (decoded.isEmpty) continue;
        
        // Find minimum distance to any point on this leg's polyline
        for (final point in decoded) {
          final dist = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            point[0],
            point[1],
          );
          if (dist < minDistanceToRoute) {
            minDistanceToRoute = dist;
          }
        }
      } catch (e) {
        print('[NavigationController] Error checking deviation: $e');
      }
    }

    // If user is too far from route, trigger re-routing
    if (minDistanceToRoute > _deviationThreshold && _destinationLat != null && _destinationLon != null) {
      print('[NavigationController] Deviation detected: ${minDistanceToRoute.toStringAsFixed(1)}m from route');
      _recalculateRoute();
    }
  }

  /// Recalculate route from current position to destination
  Future<void> _recalculateRoute() async {
    if (_isReRouting || _currentPosition == null || _destinationLat == null || _destinationLon == null) {
      return;
    }

    _isReRouting = true;
    notifyListeners();

    try {
      print('[NavigationController] Recalculating route from current position...');
      
      // Get new route from current position to destination
      final result = await _routesService.plan(
        fromLat: _currentPosition!.latitude,
        fromLon: _currentPosition!.longitude,
        toLat: _destinationLat!,
        toLon: _destinationLon!,
        filters: const RouteFilters(
          modes: ['WALK', 'TRANSIT', 'BICYCLE'],
        ),
      );

      if (result.itineraries.isNotEmpty) {
        // Update with new itinerary
        final newItinerary = result.itineraries.first;
        _activeItinerary = newItinerary;
        _currentLegIndex = 0;
        
        // Recalculate distances
        _totalDistance = newItinerary.legs.fold(0.0, (sum, leg) => sum + leg.distance);
        _distanceRemaining = _totalDistance;
        
        _updateNextInstruction();
        print('[NavigationController] Route recalculated successfully');
      } else {
        print('[NavigationController] No routes found for recalculation');
      }
    } catch (e) {
      print('[NavigationController] Error recalculating route: $e');
    } finally {
      _isReRouting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopNavigation();
    super.dispose();
  }
}

