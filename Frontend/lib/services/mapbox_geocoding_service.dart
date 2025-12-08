import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../mapbox_config.dart';

/// Representa um lugar devolvido pelas APIs de Geocoding da Mapbox.
class MapboxPlace {
  final String id;
  final String name;
  final String placeName;
  final double longitude;
  final double latitude;
  final List<String> placeTypes;
  final String? category;

  /// Distância aproximada em metros a um ponto de referência (opcional).
  final double? distanceMeters;

  const MapboxPlace({
    required this.id,
    required this.name,
    required this.placeName,
    required this.longitude,
    required this.latitude,
    this.placeTypes = const <String>[],
    this.category,
    this.distanceMeters,
  });

  /// Cria um [MapboxPlace] a partir de um feature JSON da Mapbox.
  factory MapboxPlace.fromJson(Map<String, dynamic> json) {
    final List<num> coords =
        (json['geometry']?['coordinates'] as List?)?.cast<num>() ??
            <num>[0, 0];

    return MapboxPlace(
      id: json['id'] as String? ?? '',
      name: (json['text'] as String?) ??
          (json['place_name'] as String? ?? ''),
      placeName: (json['place_name'] as String?) ?? '',
      longitude: coords.isNotEmpty ? coords[0].toDouble() : 0.0,
      latitude: coords.length > 1 ? coords[1].toDouble() : 0.0,
      placeTypes:
          (json['place_type'] as List?)?.whereType<String>().toList() ??
              const <String>[],
      category: (json['properties'] is Map<String, dynamic>)
          ? (json['properties']['category'] as String?)
          : null,
    );
  }

  /// Copia o [MapboxPlace] com um novo valor de [distanceMeters].
  MapboxPlace copyWith({double? distanceMeters}) => MapboxPlace(
        id: id,
        name: name,
        placeName: placeName,
        longitude: longitude,
        latitude: latitude,
        placeTypes: placeTypes,
        category: category,
        distanceMeters: distanceMeters ?? this.distanceMeters,
      );
}

/// Serviço fino sobre a API de Geocoding da Mapbox
/// (forward search + reverse + nearby POIs).
class MapboxGeocodingService {
  MapboxGeocodingService._();

  /// Instância singleton do [MapboxGeocodingService].
  static final MapboxGeocodingService instance = MapboxGeocodingService._();

  static const String _host = 'api.mapbox.com';
  static const String _basePath = '/geocoding/v5/mapbox.places';

  /// Lista completa de types usada para `searchPlaces`.
  static const String _allTypes =
      'address,place,poi,poi.landmark,neighborhood,locality,district,postcode,region,country';

  // -------- HTTP util com timeout + retry ----------

  /// Pequeno helper para GET com timeout e número de [retries].
  static Future<http.Response?> _get(
    Uri uri, {
    int retries = 1,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    for (int i = 0; i <= retries; i++) {
      try {
        return await http.get(uri).timeout(timeout);
      } catch (e) {
        if (i == retries) {
          debugPrint('HTTP GET failed ($uri): $e');
          return null;
        }
        await Future<Duration>.delayed(const Duration(milliseconds: 200));
      }
    }
    return null;
  }

  // --------- bbox helper (raio em km) ----------

  /// Calcula uma bounding box aproximada em torno de [lon], [lat] com raio
  /// [radiusKm] em km.
  static Map<String, double> _bboxAround({
    required double lon,
    required double lat,
    double radiusKm = 30,
  }) {
    final double dLat = radiusKm / 111.0;
    final double dLon = radiusKm /
        (111.0 *
            (math.cos(lat * math.pi / 180.0))
                .abs()
                .clamp(0.0001, double.infinity));

    return <String, double>{
      'minLon': lon - dLon,
      'minLat': lat - dLat,
      'maxLon': lon + dLon,
      'maxLat': lat + dLat,
    };
  }

  /// Forward geocoding tipo “search as you type”.
  ///
  /// Usa:
  /// - `autocomplete=true`
  /// - `types` variados (endereços, POIs, etc.) em [_allTypes]
  /// - `proximity` + `bbox` para privilegiar resultados perto
  ///
  /// Se [proximityLon]/[proximityLat] forem fornecidos, a lista devolvida
  /// é ordenada por proximidade e o campo [MapboxPlace.distanceMeters] é
  /// preenchido.
  Future<List<MapboxPlace>> searchPlaces(
    String query, {
    int limit = 12,
    String language = 'pt',
    String? countryIso2,
    double? proximityLon,
    double? proximityLat,
    double? bboxRadiusKm,
  }) async {
    final String q = query.trim();
    if (q.length < 3) return <MapboxPlace>[];

    final String path = '$_basePath/${Uri.encodeComponent(q)}.json';
    final Map<String, String> params = <String, String>{
      'access_token': kMapboxAccessToken,
      'limit': '$limit',
      'language': language,
      'autocomplete': 'true',
      'types': _allTypes,
    };

    final bool hasProximity =
        proximityLon != null && proximityLat != null;

    if (hasProximity) {
      params['proximity'] = '$proximityLon,$proximityLat';
      if (bboxRadiusKm != null && bboxRadiusKm > 0) {
        final Map<String, double> b = _bboxAround(
          lon: proximityLon!,
          lat: proximityLat!,
          radiusKm: bboxRadiusKm,
        );
        params['bbox'] =
            '${b['minLon']},${b['minLat']},${b['maxLon']},${b['maxLat']}';
      }
    }

    if (countryIso2 != null && countryIso2.isNotEmpty) {
      params['country'] = countryIso2;
    }

    final Uri uri = Uri.https(_host, path, params);
    final http.Response? res = await _get(uri, retries: 1);
    if (res == null) return <MapboxPlace>[];
    if (res.statusCode != 200) {
      debugPrint('Geocoding ERROR ${res.statusCode}: ${res.body}');
      return <MapboxPlace>[];
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Geocoding JSON parse error: $e\nBody: ${res.body}');
      return <MapboxPlace>[];
    }

    List<MapboxPlace> list = (data['features'] as List? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map<MapboxPlace>(MapboxPlace.fromJson)
        .toList();

    // Remover duplicados por id.
    final Set<String> seen = <String>{};
    list = list.where((MapboxPlace f) => seen.add(f.id)).toList();

    if (hasProximity) {
      final double pLon = proximityLon!;
      final double pLat = proximityLat!;

      list = list
          .map(
            (MapboxPlace f) => f.copyWith(
              distanceMeters: _haversineMeters(
                pLat,
                pLon,
                f.latitude,
                f.longitude,
              ),
            ),
          )
          .toList()
        ..sort((MapboxPlace a, MapboxPlace b) {
          final bool aIsPoi =
              a.placeTypes.contains('poi') ||
                  a.placeTypes.contains('poi.landmark');
          final bool bIsPoi =
              b.placeTypes.contains('poi') ||
                  b.placeTypes.contains('poi.landmark');
          final int typeScore =
              (aIsPoi == bIsPoi) ? 0 : (aIsPoi ? -1 : 1);
          if (typeScore != 0) return typeScore;
          return (a.distanceMeters ?? double.infinity)
              .compareTo(b.distanceMeters ?? double.infinity);
        });
    }

    return list;
  }

  /// Reverse geocoding para encontrar POIs perto de [lon], [lat].
  ///
  /// Faz **uma** chamada `reverse` com:
  /// - `types=poi,poi.landmark`
  /// - `categories` passadas em [categories] (ou um conjunto default)
  Future<List<MapboxPlace>> nearbyPOIs({
    required double lon,
    required double lat,
    String language = 'pt',
    String? countryIso2,
    int limit = 24,
    List<String>? categories,
  }) async {
    final List<String> cats = categories ??
        <String>[
          // cultura/turismo
          'theatre',
          'theater',
          'teatro',
          'museum',
          'museu',
          'cinema',
          'gallery',
          'galeria',
          'art',
          // comida & bebida
          'restaurant',
          'restaurante',
          'cafe',
          'coffee',
          'bakery',
          'bar',
          // serviços
          'supermarket',
          'mercado',
          'convenience',
          'pharmacy',
          'hospital',
          'clinic',
          'bank',
          'atm',
          'post office',
          // lazer / outdoors
          'park',
          'gym',
          'hotel',
          'shopping mall',
          'stadium',
        ];

    final String path = '$_basePath/$lon,$lat.json'; // reverse geocoding
    final Map<String, String> params = <String, String>{
      'access_token': kMapboxAccessToken,
      'language': language,
      'types': 'poi,poi.landmark',
      'limit': '$limit',
      'categories': cats.join(','),
    };
    if (countryIso2 != null && countryIso2.isNotEmpty) {
      params['country'] = countryIso2;
    }

    final Uri uri = Uri.https(_host, path, params);
    final http.Response? res = await _get(uri, retries: 1);
    if (res == null) return <MapboxPlace>[];
    if (res.statusCode != 200) {
      debugPrint('NearbyPOIs ERROR ${res.statusCode}: ${res.body}');
      return <MapboxPlace>[];
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('NearbyPOIs JSON parse error: $e\nBody: ${res.body}');
      return <MapboxPlace>[];
    }

    List<MapboxPlace> list = (data['features'] as List? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map<MapboxPlace>(MapboxPlace.fromJson)
        .toList();

    // dedup + ordenar por distância real
    final Set<String> seen = <String>{};
    list = list.where((MapboxPlace f) => seen.add(f.id)).toList();
    list = list
        .map(
          (MapboxPlace f) => f.copyWith(
            distanceMeters: _haversineMeters(
              lat,
              lon,
              f.latitude,
              f.longitude,
            ),
          ),
        )
        .toList()
      ..sort(
        (MapboxPlace a, MapboxPlace b) =>
            (a.distanceMeters ?? double.infinity)
                .compareTo(b.distanceMeters ?? double.infinity),
      );

    return list;
  }

  /// Reverse geocoding básico – devolve a melhor correspondência para
  /// `[longitude], [latitude]` (morada ou place).
  Future<MapboxPlace?> reverseGeocode(
    double longitude,
    double latitude, {
    String language = 'pt',
  }) async {
    final String path = '$_basePath/$longitude,$latitude.json';
    final Map<String, String> params = <String, String>{
      'access_token': kMapboxAccessToken,
      'limit': '1',
      'language': language,
      'types': 'address,place',
    };
    final Uri uri = Uri.https(_host, path, params);
    final http.Response? res = await _get(uri, retries: 1);
    if (res == null) return null;
    if (res.statusCode != 200) {
      debugPrint('ReverseGeocoding ERROR ${res.statusCode}: ${res.body}');
      return null;
    }
    try {
      final Map<String, dynamic> data =
          jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> features = data['features'] as List? ?? const [];
      if (features.isEmpty) return null;
      return MapboxPlace.fromJson(
        features.first as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('ReverseGeocoding JSON parse error: $e\nBody: ${res.body}');
      return null;
    }
  }

  // -------- utils --------

  /// Distância Haversine em metros entre dois pontos.
  static double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double r = 6371000.0;
    final double dLat = _deg2rad(lat2 - lat1);
    final double dLon = _deg2rad(lon2 - lon1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _deg2rad(double d) => d * (math.pi / 180.0);
}
