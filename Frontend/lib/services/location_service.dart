// lib/services/location_service.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Serviço de localização responsável por:
/// - Gerir permissões de localização;
/// - Obter a localização actual;
/// - Expor um stream de updates;
/// - Fazer geocoding (endereço ↔ coordenadas).
class LocationService {
  LocationService._();

  /// Instância singleton do [LocationService].
  static final LocationService _instance = LocationService._();

  /// Acesso público ao singleton.
  static LocationService get instance => _instance;

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
  /// Se as permissões não estiverem concedidas, devolve `null`.
  /// Em caso de erro (timeout, etc.), devolve igualmente `null`.
  Future<Position?> getCurrentLocation() async {
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
  /// Configuração:
  /// - [LocationAccuracy.bestForNavigation]
  /// - `distanceFilter = 3` metros (aprox.), para evitar spam de updates.
  Stream<Position> getLocationUpdates() {
    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3,
    );

    return Geolocator.getPositionStream(
      locationSettings: settings,
    );
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
