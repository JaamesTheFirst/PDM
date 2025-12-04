import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class GbfsStation {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final int vehiclesAvailable;
  final String systemId;

  GbfsStation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.vehiclesAvailable,
    required this.systemId,
  });

  factory GbfsStation.fromJson(Map<String, dynamic> json, String systemId) {
    return GbfsStation(
      id: json['station_id'].toString(),
      name: json['name'] ?? 'Estação partilhada',
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      vehiclesAvailable: (json['num_bikes_available'] ?? json['vehiclesAvailable'] ?? 0) as int,
      systemId: systemId,
    );
  }
}

class GbfsService {
  GbfsService._();
  static final GbfsService instance = GbfsService._();

  Future<List<GbfsStation>> getNearbyStations(double lat, double lon, {double radiusKm = 3}) async {
    final systemsRes = await ApiClient.instance.get('/gbfs/systems');
    if (systemsRes.statusCode != 200) throw Exception('Erro a carregar sistemas GBFS');
    final systems = (jsonDecode(systemsRes.body) as List).map((s) => s['systemId'] as String).toList();

    final all = <GbfsStation>[];
    for (final systemId in systems) {
      final res = await ApiClient.instance.get('/gbfs/$systemId/stations');
      if (res.statusCode != 200) continue;
      final decoded = jsonDecode(res.body);
      final stations = (decoded is List ? decoded : decoded['data'] ?? []) as List;
      for (final s in stations) {
        final station = GbfsStation.fromJson(s, systemId);
        if (_withinRadius(station.lat, station.lon, lat, lon, radiusKm)) {
          all.add(station);
        }
      }
    }
    return all;
  }

  bool _withinRadius(double aLat, double aLon, double bLat, double bLon, double radiusKm) {
    const R = 6371.0;
    final dLat = (bLat - aLat) * pi / 180.0;
    final dLon = (bLon - aLon) * pi / 180.0;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(aLat * pi / 180.0) * cos(bLat * pi / 180.0) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return (R * c) <= radiusKm;
  }
}
