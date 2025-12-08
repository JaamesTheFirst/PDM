import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../mapbox_config.dart';

/// Representa uma rota devolvida pela API de direções da Mapbox.
class MapboxRoute {
  /// Distância total da rota em metros.
  final double distance;

  /// Duração estimada da rota em segundos.
  final double duration;

  /// Geometria da rota como lista de coordenadas `[lon, lat]`.
  final List<List<double>> geometry;

  const MapboxRoute({
    required this.distance,
    required this.duration,
    required this.geometry,
  });
}

/// Serviço fino sobre a API de Directions da Mapbox.
///
/// Faz apenas uma chamada simples:
/// - `/directions/v5/mapbox/{profile}/{fromLon},{fromLat};{toLon},{toLat}`
///
/// e devolve um [MapboxRoute] com distância, duração e geometria.
class MapboxDirectionsService {
  MapboxDirectionsService._();

  /// Instância singleton do serviço.
  static final MapboxDirectionsService instance = MapboxDirectionsService._();

  static const String _host = 'api.mapbox.com';
  static const String _basePath = '/directions/v5/mapbox';

  /// Calcula uma rota real entre dois pontos.
  ///
  /// - [fromLon], [fromLat]: origem em graus decimais (lon/lat).
  /// - [toLon], [toLat]: destino em graus decimais (lon/lat).
  /// - [profile]: um dos perfis aceites pela Mapbox:
  ///   `'driving'`, `'driving-traffic'`, `'walking'`, `'cycling'`.
  ///
  /// Devolve:
  /// - Um [MapboxRoute] em caso de sucesso.
  /// - `null` se houver erro de rede, HTTP != 200 ou JSON inesperado.
  Future<MapboxRoute?> getRoute({
    required double fromLon,
    required double fromLat,
    required double toLon,
    required double toLat,
    String profile = 'walking',
  }) async {
    // Sanity check básico ao profile.
    const Set<String> allowed = <String>{
      'driving',
      'driving-traffic',
      'walking',
      'cycling',
    };
    final String safeProfile = allowed.contains(profile) ? profile : 'walking';

    // path: /directions/v5/mapbox/{profile}/{fromLon},{fromLat};{toLon},{toLat}
    final String path =
        '$_basePath/$safeProfile/$fromLon,$fromLat;$toLon,$toLat';

    // query params
    final Map<String, String> qp = <String, String>{
      'alternatives': 'false',
      'geometries': 'geojson',
      'steps': 'false',
      'overview': 'full', // geometria mais completa
      'access_token': kMapboxAccessToken,
    };

    final Uri uri = Uri.https(_host, path, qp);

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
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Directions JSON parse error: $e\nBody: ${res.body}');
      return null;
    }

    final dynamic routes = data['routes'];
    if (routes is! List || routes.isEmpty) {
      debugPrint('Directions: sem rotas na resposta: ${res.body}');
      return null;
    }

    final Map<String, dynamic> route =
        routes.first as Map<String, dynamic>; // rota principal
    final Map<String, dynamic>? geometry =
        route['geometry'] as Map<String, dynamic>?;
    final dynamic coordsRaw = geometry?['coordinates'];

    if (coordsRaw is! List) {
      debugPrint('Directions: geometry inválida: ${route['geometry']}');
      return null;
    }

    final List<List<double>> coords = <List<double>>[];
    try {
      for (final dynamic c in coordsRaw) {
        final double lon = (c[0] as num).toDouble();
        final double lat = (c[1] as num).toDouble();
        coords.add(<double>[lon, lat]);
      }
    } catch (e) {
      debugPrint('Directions: erro ao mapear coordenadas: $e');
      return null;
    }

    final double distance = (route['distance'] as num?)?.toDouble() ?? 0.0;
    final double duration = (route['duration'] as num?)?.toDouble() ?? 0.0;

    return MapboxRoute(
      distance: distance,
      duration: duration,
      geometry: coords,
    );
  }
}
