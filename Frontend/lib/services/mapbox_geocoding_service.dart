import 'dart:convert';
import 'package:http/http.dart' as http;
import '../mapbox_config.dart';

/// Representa um lugar devolvido pela API de geocoding da Mapbox.
class MapboxPlace {
  final String id;
  final String name;       // ex: "Rua de X"
  final String placeName;  // ex: "Rua de X, Cidade, País"
  final double longitude;
  final double latitude;

  MapboxPlace({
    required this.id,
    required this.name,
    required this.placeName,
    required this.longitude,
    required this.latitude,
  });

  factory MapboxPlace.fromJson(Map<String, dynamic> json) {
    final coords = (json['geometry']['coordinates'] as List).cast<num>();
    return MapboxPlace(
      id: json['id'] as String,
      name: json['text'] as String,
      placeName: json['place_name'] as String,
      longitude: coords[0].toDouble(),
      latitude: coords[1].toDouble(),
    );
  }
}

class MapboxGeocodingService {
  MapboxGeocodingService._();
  static final MapboxGeocodingService instance = MapboxGeocodingService._();
  static const String _accessToken = kMapboxAccessToken;
  static const String _baseUrl =
      'https://api.mapbox.com/geocoding/v5/mapbox.places';

  /// Pesquisa lugares (forward geocoding) – usado no campo "Para".
  Future<List<MapboxPlace>> searchPlaces(
    String query, {
    int limit = 6,
    String language = 'pt',
    double? proximityLon,
    double? proximityLat,
  }) async {
    if (query.trim().isEmpty) return [];

    final buf = StringBuffer(
      '$_baseUrl/${Uri.encodeComponent(query)}.json'
      '?access_token=$_accessToken'
      '&limit=$limit'
      '&language=$language'
      '&autocomplete=true'
      '&types=address,street,place,poi',
    );

    if (proximityLon != null && proximityLat != null) {
      buf.write('&proximity=$proximityLon,$proximityLat');
    }

    final uri = Uri.parse(buf.toString());
    final res = await http.get(uri);
    if (res.statusCode != 200) return [];

    final data = json.decode(res.body) as Map<String, dynamic>;
    final features = (data['features'] as List).cast<Map<String, dynamic>>();
    return features.map(MapboxPlace.fromJson).toList();
  }

  /// Reverse geocoding – usado para descobrir a rua atual do user.
  Future<MapboxPlace?> reverseGeocode(
    double longitude,
    double latitude, {
    String language = 'pt',
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/$longitude,$latitude.json'
      '?access_token=$_accessToken'
      '&limit=1'
      '&language=$language'
      '&types=address,street,place',
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) return null;

    final data = json.decode(res.body) as Map<String, dynamic>;
    final features = data['features'] as List?;
    if (features == null || features.isEmpty) return null;

    return MapboxPlace.fromJson(
      (features.first as Map<String, dynamic>),
    );
  }
}
