import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  LocationService._();
  static final LocationService _instance = LocationService._();
  
  static LocationService get instance => _instance;

  // Mock location mode (for testing)
  static const bool _useMockLocation = bool.fromEnvironment('MOCK_LOCATION', defaultValue: false);
  StreamController<Position>? _mockLocationController;
  Timer? _mockLocationTimer;
  List<List<double>>? _mockRoutePoints;
  int _mockCurrentIndex = 0;
  double _mockSpeed = 1.0; // meters per update (adjust for faster/slower simulation)

  /// Check and request permissions for the location service
  Future<bool> checkPermissions() async {
    if (_useMockLocation) return true; // Skip permissions in mock mode
    
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
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

  /// Get the current location
  Future<Position?> getCurrentLocation() async {
    if (_useMockLocation && _mockRoutePoints != null && _mockRoutePoints!.isNotEmpty) {
      final point = _mockRoutePoints![_mockCurrentIndex];
      return Position(
        latitude: point[0],
        longitude: point[1],
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }

    final hasPermission = await checkPermissions();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Get location updates stream
  Stream<Position> getLocationUpdates() {
    if (_useMockLocation) {
      return _getMockLocationUpdates();
    }

    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // meters
      ),
    );
  }

  /// Mock location updates - simulates movement along a route
  Stream<Position> _getMockLocationUpdates() {
    _mockLocationController = StreamController<Position>.broadcast();
    
    // Start with current position
    if (_mockRoutePoints != null && _mockRoutePoints!.isNotEmpty) {
      final point = _mockRoutePoints![_mockCurrentIndex];
      _mockLocationController!.add(Position(
        latitude: point[0],
        longitude: point[1],
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: _mockSpeed * 10, // Convert to m/s
        speedAccuracy: 0,
      ));
    }

    // Simulate movement every second
    _mockLocationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_mockRoutePoints == null || _mockRoutePoints!.isEmpty) return;
      if (_mockLocationController == null || _mockLocationController!.isClosed) {
        timer.cancel();
        return;
      }

      // Move to next point (or interpolate if speed is slow)
      if (_mockCurrentIndex < _mockRoutePoints!.length - 1) {
        _mockCurrentIndex++;
        final point = _mockRoutePoints![_mockCurrentIndex];
        
        _mockLocationController!.add(Position(
          latitude: point[0],
          longitude: point[1],
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: _calculateHeading(_mockCurrentIndex),
          headingAccuracy: 0,
          speed: _mockSpeed * 10,
          speedAccuracy: 0,
        ));
      } else {
        // Reached end - loop back or stop
        timer.cancel();
      }
    });

    return _mockLocationController!.stream;
  }

  /// Calculate heading between two points
  double _calculateHeading(int index) {
    if (_mockRoutePoints == null || index == 0) return 0.0;
    if (index >= _mockRoutePoints!.length) return 0.0;
    
    final prev = _mockRoutePoints![index - 1];
    final curr = _mockRoutePoints![index];
    
    return Geolocator.bearingBetween(
      prev[0], prev[1],
      curr[0], curr[1],
    );
  }

  /// Set mock route for simulation (call this before starting navigation)
  void setMockRoute(List<List<double>> routePoints, {double speed = 1.0}) {
    if (!_useMockLocation) {
      print('[LocationService] Mock location not enabled. Set MOCK_LOCATION=true');
      return;
    }
    
    _mockRoutePoints = routePoints;
    _mockCurrentIndex = 0;
    _mockSpeed = speed;
    print('[LocationService] Mock route set with ${routePoints.length} points, speed: ${speed}m/update');
  }

  /// Stop mock location updates
  void stopMockLocation() {
    _mockLocationTimer?.cancel();
    _mockLocationTimer = null;
    _mockLocationController?.close();
    _mockLocationController = null;
    _mockRoutePoints = null;
    _mockCurrentIndex = 0;
  }

  /// Get address from coordinates
  Future<String?> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return "${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
      }
      return null;
    } catch (e) {
      print('Error getting address from coordinates: $e');
      return null;
    }
  }

  /// Get coordinates from address
  Future<Position?> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return Position(
          latitude: locations[0].latitude,
          longitude: locations[0].longitude,
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
      print('Error getting coordinates from address: $e');
    }
    return null;
  }
}
