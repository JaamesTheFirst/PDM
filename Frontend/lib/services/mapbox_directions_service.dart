import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../mapbox_config.dart';

/// Representa uma rota devolvida pela API de direções da Mapbox.
class MapboxRoute {
  final double distance; // metros
  final double duration; // segundos
  final List<List<double>> geometry; // lista de coordenadas [lon, lat]

  MapboxRoute({
    required this.distance,
    required this.duration,
    required this.geometry,
  });
}

class MapboxDirectionsService {
  MapboxDirectionsService._();
  static final MapboxDirectionsService instance = MapboxDirectionsService._();

  static const String _host = 'api.mapbox.com';
  static const String _basePath = '/directions/v5/mapbox';

  /// Calcula uma rota real entre dois pontos.
  ///
  /// [profile] aceites pela Mapbox: 'driving', 'driving-traffic', 'walking', 'cycling'
  Future<MapboxRoute?> getRoute({
    required double fromLon,
    required double fromLat,
    required double toLon,
    required double toLat,
    String profile = 'walking', // walking, cycling, driving
  }) async {
    // sanity check básico ao profile
    const allowed = {'driving', 'driving-traffic', 'walking', 'cycling'};
    final safeProfile = allowed.contains(profile) ? profile : 'walking';

    // path: /directions/v5/mapbox/{profile}/{fromLon},{fromLat};{toLon},{toLat}
    final path = '$_basePath/$safeProfile/$fromLon,$fromLat;$toLon,$toLat';

    // query params
    final qp = <String, String>{
      'alternatives': 'false',
      'geometries': 'geojson',
      'steps': 'false',
      'overview': 'full', // geometria mais completa
      'access_token': kMapboxAccessToken,
    };

    final uri = Uri.https(_host, path, qp);

    http.Response res;
    try {
      res = await http.get(uri);
    } catch (e) {
      debugPrint('Directions HTTP exception: $e');
      return null;
    }

    if (res.statusCode != 200) {
      debugPrint('Directions ERROR ${res.statusCode}: ${res.body}');
      return null;
    }

    Map<String, dynamic> data;
    try {
      data = json.decode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Directions JSON parse error: $e\nBody: ${res.body}');
      return null;
    }

    final routes = data['routes'];
    if (routes is! List || routes.isEmpty) {
      debugPrint('Directions: sem rotas na resposta: ${res.body}');
      return null;
    }

    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>?;
    final coordsRaw = geometry?['coordinates'];

    if (coordsRaw is! List) {
      debugPrint('Directions: geometry inválida: ${route['geometry']}');
      return null;
    }

    final coords = <List<double>>[];
    try {
      for (final c in coordsRaw) {
        final lon = (c[0] as num).toDouble();
        final lat = (c[1] as num).toDouble();
        coords.add([lon, lat]);
      }
    } catch (e) {
      debugPrint('Directions: erro ao mapear coordenadas: $e');
      return null;
    }

    final distance = (route['distance'] as num?)?.toDouble() ?? 0.0;
    final duration = (route['duration'] as num?)?.toDouble() ?? 0.0;

    return MapboxRoute(
      distance: distance,
      duration: duration,
      geometry: coords,
    );
  }
}
