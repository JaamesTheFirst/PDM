// lib/services/location_service.dart

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  LocationService._();
  static final LocationService _instance = LocationService._();

  static LocationService get instance => _instance;

  // ================== PERMISSÕES ==================

  /// Check and request permissions for the location service
  Future<bool> checkPermissions() async {
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

  // ================== LOCALIZAÇÃO ÚNICA ==================

  /// Get the current location (com maior precisão possível)
  Future<Position?> getCurrentLocation() async {
    final hasPermission = await checkPermissions();
    if (!hasPermission) return null;

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      return pos;
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  // ================== STREAM DE LOCALIZAÇÃO ==================

  /// Get location updates stream (sem smoothing, mas com boa accuracy)
  Stream<Position> getLocationUpdates() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      // emite quando se mover ~3m; ajusta se quiseres mais/menos
      distanceFilter: 3,
    );

    return Geolocator.getPositionStream(
      locationSettings: settings,
    );
  }

  // ================== GEOCODING ==================

  /// Get address from coordinates
  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return "${place.street}, ${place.locality}, "
            "${place.administrativeArea}, ${place.country}";
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
