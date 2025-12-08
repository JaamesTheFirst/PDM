import 'dart:convert';
import 'dart:math' as math;

import 'api_client.dart';

/// Modelo de estação genérica GBFS.
///
/// Representa uma estação de partilha (bicicletas, trotinetes, etc.)
/// agregando os campos relevantes para o frontend.
class GbfsStation {
  /// Identificador interno/GBFS da estação.
  final String id;

  /// Nome legível da estação.
  final String name;

  /// Latitude em graus decimais (WGS84).
  final double lat;

  /// Longitude em graus decimais (WGS84).
  final double lon;

  /// Número de veículos disponíveis nesta estação.
  final int vehiclesAvailable;

  /// Identificador do sistema GBFS a que esta estação pertence.
  final String systemId;

  const GbfsStation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.vehiclesAvailable,
    required this.systemId,
  });

  /// Cria uma instância [GbfsStation] a partir de um JSON GBFS.
  ///
  /// A estrutura varia consoante o fornecedor, por isso este método
  /// tenta mapear chaves típicas:
  /// - `station_id`
  /// - `name`
  /// - `lat` / `lon`
  /// - `num_bikes_available` ou `vehiclesAvailable`
  factory GbfsStation.fromJson(
    Map<String, dynamic> json,
    String systemId,
  ) {
    final numBikes = json['num_bikes_available'] ?? json['vehiclesAvailable'];
    final int vehicles = numBikes is int
        ? numBikes
        : (numBikes is num)
            ? numBikes.toInt()
            : 0;

    return GbfsStation(
      id: json['station_id'].toString(),
      name: json['name'] as String? ?? 'Estação partilhada',
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      vehiclesAvailable: vehicles,
      systemId: systemId,
    );
  }
}

/// Serviço para consumir os endpoints GBFS do backend.
///
/// Este serviço:
/// - Descobre os sistemas disponíveis (`/gbfs/systems`);
/// - Para cada sistema, obtém as estações (`/gbfs/{systemId}/stations`);
/// - Calcula quais estão num determinado raio de uma coordenada.
class GbfsService {
  GbfsService._();

  /// Instância singleton do [GbfsService].
  static final GbfsService instance = GbfsService._();

  /// Devolve uma lista de estações GBFS num raio de [radiusKm] em torno
  /// da posição [lat], [lon].
  ///
  /// Passos:
  /// 1. Faz `GET /gbfs/systems` e extrai os `systemId`.
  /// 2. Para cada sistema, faz `GET /gbfs/{systemId}/stations`.
  /// 3. Converte cada registo em [GbfsStation] e filtra pelo raio.
  ///
  /// Lança [Exception] se o endpoint de sistemas devolver código
  /// diferente de 200.
  Future<List<GbfsStation>> getNearbyStations(
    double lat,
    double lon, {
    double radiusKm = 3,
  }) async {
    final systemsRes = await ApiClient.instance.get('/gbfs/systems');

    if (systemsRes.statusCode != 200) {
      throw Exception('Erro a carregar sistemas GBFS');
    }

    final dynamic systemsDecoded = jsonDecode(systemsRes.body);
    final List<dynamic> systemsList =
        systemsDecoded is List ? systemsDecoded : <dynamic>[];

    final List<String> systems = systemsList
        .map((dynamic s) => (s as Map<String, dynamic>)['systemId'])
        .whereType<String>()
        .toList();

    final List<GbfsStation> all = <GbfsStation>[];

    for (final String systemId in systems) {
      final res = await ApiClient.instance.get('/gbfs/$systemId/stations');
      if (res.statusCode != 200) continue;

      final dynamic decoded = jsonDecode(res.body);

      // Pode vir como lista directa ou dentro de um campo `data`.
      final List<dynamic> stations =
          decoded is List ? decoded : (decoded['data'] as List<dynamic>? ?? []);

      for (final dynamic s in stations) {
        if (s is! Map<String, dynamic>) continue;
        final station = GbfsStation.fromJson(s, systemId);
        if (_withinRadius(station.lat, station.lon, lat, lon, radiusKm)) {
          all.add(station);
        }
      }
    }

    return all;
  }

  /// Verifica se a distância entre dois pontos A e B é menor ou igual
  /// a [radiusKm], usando a fórmula de Haversine (em km).
  bool _withinRadius(
    double aLat,
    double aLon,
    double bLat,
    double bLon,
    double radiusKm,
  ) {
    const double r = 6371.0; // raio médio da Terra em km

    final double dLat = (bLat - aLat) * math.pi / 180.0;
    final double dLon = (bLon - aLon) * math.pi / 180.0;

    final double hav = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(aLat * math.pi / 180.0) *
            math.cos(bLat * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(hav), math.sqrt(1 - hav));
    final double distanceKm = r * c;

    return distanceKm <= radiusKm;
  }
}
