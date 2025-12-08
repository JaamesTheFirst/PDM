import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Modelo de estação GIRA (espelha o `GiraStation` do backend).
class GiraStation {
  /// Identificador interno da estação no backend.
  final int id;

  /// Identificador externo (por ex. ID do sistema original).
  final String? externalId;

  /// Nome da estação.
  final String? name;

  /// Morada da estação.
  final String? address;

  /// Freguesia / zona administrativa.
  final String? parish;

  /// Latitude da estação (graus decimais).
  final double? latitude;

  /// Longitude da estação (graus decimais).
  final double? longitude;

  /// Capacidade total da estação (n.º de docks).
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

  /// Cria [GiraStation] a partir de um JSON.
  ///
  /// É tolerante a diferentes tipos de `id` (string ou int).
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

/// Serviço para consumo dos endpoints GIRA do backend.
///
/// Responsável por:
/// - Obter todas as estações (`GET /gira/stations`);
/// - Filtrar estações próximas de uma localização;
/// - Calcular bounding boxes simples para pesquisa.
class GiraService {
  GiraService._();

  /// Instância singleton do [GiraService].
  static final GiraService instance = GiraService._();

  /// Vai ao backend (`GET /gira/stations`) e devolve todas as estações GIRA.
  ///
  /// Em caso de erro HTTP (status != 200), lança [Exception].
  Future<List<GiraStation>> getStations() async {
    final res = await ApiClient.instance.get('/gira/stations');

    if (res.statusCode != 200) {
      throw Exception('Erro ao obter estações GIRA (HTTP ${res.statusCode})');
    }

    final String body = res.body;
    List<dynamic>? decodedList;

    try {
      final dynamic decoded = jsonDecode(body);

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

    final List<dynamic> rawList = decodedList ?? const <dynamic>[];

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(GiraStation.fromJson)
        .toList();
  }

  /// Devolve apenas estações num raio [radiusKm] da posição [lon, lat].
  ///
  /// Internamente:
  /// 1. Obtém todas as estações via [getStations].
  /// 2. Calcula a distância em metros via [_haversineMeters].
  /// 3. Filtra as estações cuja distância <= `radiusKm * 1000`.
  Future<List<GiraStation>> getStationsNear({
    required double lon,
    required double lat,
    double radiusKm = 1.5,
  }) async {
    final all = await getStations();
    final double maxMeters = radiusKm * 1000.0;

    return all.where((GiraStation s) {
      final double? slat = s.latitude;
      final double? slon = s.longitude;
      if (slat == null || slon == null) return false;
      final double d = _haversineMeters(lat, lon, slat, slon);
      return d <= maxMeters;
    }).toList();
  }

  /// Calcula a distância em metros entre dois pontos usando Haversine.
  double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double r = 6371000.0; // raio médio da Terra em metros

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

  double _deg2rad(double d) => d * (math.pi / 180.0);

  /// Calcula uma bounding box simples em torno de [lon], [lat] com raio
  /// [radiusKm], retornando:
  /// - `minLon`, `minLat`, `maxLon`, `maxLat`
  ///
  /// Útil se no futuro quiseres delegar o filtro de proximidade ao backend.
  Map<String, double> bboxAround(
    double lon,
    double lat,
    double radiusKm,
  ) {
    final double dLat = radiusKm / 111.0;
    final double cosLat =
        math.cos(lat * math.pi / 180.0).abs().clamp(0.0001, 1.0);
    final double dLon = radiusKm / (111.0 * cosLat);

    return <String, double>{
      'minLon': lon - dLon,
      'minLat': lat - dLat,
      'maxLon': lon + dLon,
      'maxLat': lat + dLat,
    };
  }
}
