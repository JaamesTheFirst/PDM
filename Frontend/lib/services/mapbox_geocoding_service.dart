import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../mapbox_config.dart';

class MapboxPlace {
  final String id;
  final String name;
  final String placeName;
  final double longitude;
  final double latitude;
  final List<String> placeTypes;
  final String? category;
  final double? distanceMeters;

  MapboxPlace({
    required this.id,
    required this.name,
    required this.placeName,
    required this.longitude,
    required this.latitude,
    this.placeTypes = const [],
    this.category,
    this.distanceMeters,
  });

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

  factory MapboxPlace.fromJson(Map<String, dynamic> json) {
    final coords = (json['geometry']?['coordinates'] as List?)?.cast<num>() ?? const [0, 0];
    return MapboxPlace(
      id: json['id'] as String? ?? '',
      name: (json['text'] as String?) ?? (json['place_name'] as String? ?? ''),
      placeName: (json['place_name'] as String?) ?? '',
      longitude: coords.isNotEmpty ? coords[0].toDouble() : 0.0,
      latitude: coords.length > 1 ? coords[1].toDouble() : 0.0,
      placeTypes: (json['place_type'] as List?)?.whereType<String>().toList() ?? const [],
      category: (json['properties'] is Map<String, dynamic>)
          ? (json['properties']['category'] as String?)
          : null,
    );
  }
}

class MapboxGeocodingService {
  MapboxGeocodingService._();
  static final MapboxGeocodingService instance = MapboxGeocodingService._();

  static const _host = 'api.mapbox.com';
  static const _basePath = '/geocoding/v5/mapbox.places';
  static const _allTypes =
      'address,place,poi,poi.landmark,neighborhood,locality,district,postcode,region,country';

  // -------- HTTP util com timeout + retry ----------
  static Future<http.Response?> _get(Uri uri,
      {int retries = 1, Duration timeout = const Duration(seconds: 8)}) async {
    for (int i = 0; i <= retries; i++) {
      try {
        return await http.get(uri).timeout(timeout);
      } catch (e) {
        if (i == retries) {
          debugPrint('HTTP GET failed ($uri): $e');
          return null;
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    return null;
  }

  // --------- bbox helper (raio em km) ----------
  static Map<String, double> _bboxAround(
      {required double lon, required double lat, double radiusKm = 30}) {
    final dLat = radiusKm / 111.0;
    final dLon = radiusKm / (111.0 * (math.cos(lat * math.pi / 180.0)).abs().clamp(0.0001, double.infinity));
    return {
      'minLon': lon - dLon,
      'minLat': lat - dLat,
      'maxLon': lon + dLon,
      'maxLat': lat + dLat,
    };
  }

  /// SEARCH-AS-YOU-TYPE (forward): prioriza o que está perto usando proximity + bbox + country.
  Future<List<MapboxPlace>> searchPlaces(
    String query, {
    int limit = 12,
    String language = 'pt',
    String? countryIso2,
    double? proximityLon,
    double? proximityLat,
    double? bboxRadiusKm,
  }) async {
    final q = query.trim();
    if (q.length < 3) return [];

    final path = '$_basePath/${Uri.encodeComponent(q)}.json';
    final params = <String, String>{
      'access_token': kMapboxAccessToken,
      'limit': '$limit',
      'language': language,
      'autocomplete': 'true',
      'types': _allTypes,
    };

    final hasProximity = (proximityLon != null && proximityLat != null);
    if (hasProximity) {
      params['proximity'] = '${proximityLon},${proximityLat!}';
      if (bboxRadiusKm != null && bboxRadiusKm > 0) {
        final b = _bboxAround(lon: proximityLon, lat: proximityLat, radiusKm: bboxRadiusKm);
        params['bbox'] = '${b['minLon']},${b['minLat']},${b['maxLon']},${b['maxLat']}';
      }
    }
    if (countryIso2 != null && countryIso2.isNotEmpty) {
      params['country'] = countryIso2;
    }

    final uri = Uri.https(_host, path, params);
    final res = await _get(uri, retries: 1);
    if (res == null) return [];
    if (res.statusCode != 200) {
      debugPrint('Geocoding ERROR ${res.statusCode}: ${res.body}');
      return [];
    }

    Map<String, dynamic> data;
    try {
      data = json.decode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Geocoding JSON parse error: $e\nBody: ${res.body}');
      return [];
    }

    var list = (data['features'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map<MapboxPlace>(MapboxPlace.fromJson)
        .toList();

    // dedup
    final seen = <String>{};
    list = list.where((f) => seen.add(f.id)).toList();

    if (hasProximity) {
      final pLon = proximityLon!;
      final pLat = proximityLat!;
      list = list
          .map((f) => f.copyWith(
                distanceMeters: _haversineMeters(pLat, pLon, f.latitude, f.longitude),
              ))
          .toList()
        ..sort((a, b) {
          final aIsPoi = a.placeTypes.contains('poi') || a.placeTypes.contains('poi.landmark');
          final bIsPoi = b.placeTypes.contains('poi') || b.placeTypes.contains('poi.landmark');
          final typeScore = (aIsPoi == bIsPoi) ? 0 : (aIsPoi ? -1 : 1);
          if (typeScore != 0) return typeScore;
          return (a.distanceMeters ?? double.infinity)
              .compareTo(b.distanceMeters ?? double.infinity);
        });
    }

    return list;
  }

  /// SUGESTÕES PERTO (rápido): **UMA** chamada de REVERSE com `types=poi`
  /// e `categories=...` (sem spam por categoria).
  Future<List<MapboxPlace>> nearbyPOIs({
    required double lon,
    required double lat,
    String language = 'pt',
    String? countryIso2, // opcional
    int limit = 24,
    List<String>? categories,
  }) async {
    final cats = categories ??
        [
          // cultura/turismo
          'theatre','theater','teatro','museum','museu','cinema','gallery','galeria','art',
          // comida & bebida
          'restaurant','restaurante','cafe','coffee','bakery','bar',
          // serviços
          'supermarket','mercado','convenience','pharmacy','hospital','clinic','bank','atm','post office',
          // lazer / outdoors
          'park','gym','hotel','shopping mall','stadium',
        ];

    final path = '$_basePath/$lon,$lat.json'; // reverse geocoding
    final params = <String, String>{
      'access_token': kMapboxAccessToken,
      'language': language,
      'types': 'poi,poi.landmark',
      'limit': '$limit',
      'categories': cats.join(','), // <- UMA chamada com categorias
    };
    if (countryIso2 != null && countryIso2.isNotEmpty) {
      params['country'] = countryIso2;
    }

    final uri = Uri.https(_host, path, params);
    final res = await _get(uri, retries: 1);
    if (res == null) return [];
    if (res.statusCode != 200) {
      debugPrint('NearbyPOIs ERROR ${res.statusCode}: ${res.body}');
      return [];
    }

    Map<String, dynamic> data;
    try {
      data = json.decode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('NearbyPOIs JSON parse error: $e\nBody: ${res.body}');
      return [];
    }

    var list = (data['features'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map<MapboxPlace>(MapboxPlace.fromJson)
        .toList();

    // dedup + ordenar por distância real
    final seen = <String>{};
    list = list.where((f) => seen.add(f.id)).toList();
    list = list
        .map((f) => f.copyWith(distanceMeters: _haversineMeters(lat, lon, f.latitude, f.longitude)))
        .toList()
      ..sort((a, b) =>
          (a.distanceMeters ?? double.infinity).compareTo(b.distanceMeters ?? double.infinity));

    return list;
  }

  /// Reverse geocoding – rua/local atual.
  Future<MapboxPlace?> reverseGeocode(
    double longitude,
    double latitude, {
    String language = 'pt',
  }) async {
    final path = '$_basePath/$longitude,$latitude.json';
    final params = <String, String>{
      'access_token': kMapboxAccessToken,
      'limit': '1',
      'language': language,
      'types': 'address,place',
    };
    final uri = Uri.https(_host, path, params);
    final res = await _get(uri, retries: 1);
    if (res == null) return null;
    if (res.statusCode != 200) {
      debugPrint('ReverseGeocoding ERROR ${res.statusCode}: ${res.body}');
      return null;
    }
    try {
      final data = json.decode(res.body) as Map<String, dynamic>;
      final features = data['features'] as List? ?? const [];
      if (features.isEmpty) return null;
      return MapboxPlace.fromJson(features.first as Map<String, dynamic>);
    } catch (e) {
      debugPrint('ReverseGeocoding JSON parse error: $e\nBody: ${res.body}');
      return null;
    }
  }

  // -------- utils --------
  static double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat/2)*math.sin(dLat/2) +
        math.cos(_deg2rad(lat1))*math.cos(_deg2rad(lat2)) *
        math.sin(dLon/2)*math.sin(dLon/2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
    return r * c;
  }
  static double _deg2rad(double d) => d * (math.pi / 180.0);
}
