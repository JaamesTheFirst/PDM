// lib/services/gira_service.dart
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Modelo de estação GIRA (espelha o GiraStation do backend)
class GiraStation {
  final int id;
  final String? externalId;
  final String? name;
  final String? address;
  final String? parish;
  final double? latitude;
  final double? longitude;
  final int? capacity;

  const GiraStation({
    required this.id,
    this.externalId,
    this.name,
    this.address,
    this.parish,
    this.latitude,
    this.longitude,
    this.capacity,
  });

  factory GiraStation.fromJson(Map<String, dynamic> json) {
    return GiraStation(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      externalId: json['externalId'] as String?,
      name: json['name'] as String?,
      address: json['address'] as String?,
      parish: json['parish'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      capacity: (json['capacity'] as num?)?.toInt(),
    );
  }
}

class GiraService {
  GiraService._();
  static final GiraService instance = GiraService._();

  /// Vai ao backend (`GET /gira/stations`) e devolve todas as estações GIRA.
  Future<List<GiraStation>> getStations() async {
    final res = await ApiClient.instance.get('/gira/stations');

    if (res.statusCode != 200) {
      throw Exception('Erro ao obter estações GIRA (HTTP ${res.statusCode})');
    }

    final body = res.body;
    List<dynamic>? decodedList;

    try {
      final decoded = jsonDecode(body);

      if (decoded is List) {
        decodedList = decoded;
      } else if (decoded is Map<String, dynamic>) {
        decodedList = (decoded['records'] as List?) ??
            (decoded['data'] as List?) ??
            (decoded['stations'] as List?);
      }
    } catch (e) {
      debugPrint('[GiraService] JSON parse error: $e');
      rethrow;
    }

    final rawList = decodedList ?? const [];
    return rawList
        .whereType<Map<String, dynamic>>()
        .map(GiraStation.fromJson)
        .toList();
  }

  /// Devolve apenas estações num raio [radiusKm] da posição [lon, lat].
  Future<List<GiraStation>> getStationsNear({
    required double lon,
    required double lat,
    double radiusKm = 1.5,
  }) async {
    final all = await getStations();
    final maxMeters = radiusKm * 1000.0;

    return all.where((s) {
      final slat = s.latitude;
      final slon = s.longitude;
      if (slat == null || slon == null) return false;
      final d = _haversineMeters(lat, lon, slat, slon);
      return d <= maxMeters;
    }).toList();
  }

  /// Haversine simples em metros.
  double _haversineMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double d) => d * (math.pi / 180.0);

  /// Helper para bbox (se quiseres no futuro mandar limites para o backend).
  Map<String, double> bboxAround(double lon, double lat, double radiusKm) {
    final dLat = radiusKm / 111.0;
    final cosLat = math.cos(lat * math.pi / 180.0).abs().clamp(0.0001, 1.0);
    final dLon = radiusKm / (111.0 * cosLat);

    return {
      'minLon': lon - dLon,
      'minLat': lat - dLat,
      'maxLon': lon + dLon,
      'maxLat': lat + dLat,
    };
  }
}
