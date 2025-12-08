import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';

class GiraStationRecord {
  final String? estado;
  final int? numDocas;
  final int? numBicicletas;
  final String? desigComercial;
  final double? lat;
  final double? lon;
  final DateTime? entityTs;

  GiraStationRecord({
    this.estado,
    this.numDocas,
    this.numBicicletas,
    this.desigComercial,
    this.lat,
    this.lon,
    this.entityTs,
  });

  factory GiraStationRecord.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    int? toInt(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    double? lat;
    double? lon;

    if (json['position'] != null) {
      try {
        final pos = json['position'];
        final parsed = pos is String ? jsonDecode(pos) : pos;
        if (parsed is Map && parsed['coordinates'] is List) {
          final coords = parsed['coordinates'] as List;
          if (coords.length >= 2) {
            lon = toDouble(coords[0]);
            lat = toDouble(coords[1]);
          }
        }
      } catch (_) {
        // ignora
      }
    }

    DateTime? ts;
    if (json['entity_ts'] != null) {
      try {
        ts = DateTime.parse(json['entity_ts'] as String);
      } catch (_) {}
    }

    return GiraStationRecord(
      estado: json['estado'] as String?,
      numDocas: toInt(json['numdocas']),
      numBicicletas: toInt(json['numbicicletas']),
      desigComercial: json['desigcomercial'] as String?,
      lat: lat,
      lon: lon,
      entityTs: ts,
    );
  }
}

class GiraStationsSlice {
  final int total;
  final int limit;
  final int offset;
  final List<GiraStationRecord> records;

  GiraStationsSlice({
    required this.total,
    required this.limit,
    required this.offset,
    required this.records,
  });
}

class GiraApiClient {
  final String baseUrl;
  final http.Client _client;

  GiraApiClient({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? kBaseUrl;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  /// GET /gira/stations?limit=&offset=
  Future<GiraStationsSlice> getStations({
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = _uri('/gira/stations', {
      'limit': '$limit',
      'offset': '$offset',
    });

    debugPrint('[GIRA API] GET $uri');
    final resp = await _client.get(uri);

    if (resp.statusCode != 200) {
      throw Exception(
        'Erro ao carregar estações Gira (status ${resp.statusCode})',
      );
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;

    final total = data['total'] as int? ?? 0;
    final l = data['limit'] as int? ?? limit;
    final o = data['offset'] as int? ?? offset;

    final recordsJson = (data['records'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    final records =
        recordsJson.map((j) => GiraStationRecord.fromJson(j)).toList();

    return GiraStationsSlice(
      total: total,
      limit: l,
      offset: o,
      records: records,
    );
  }

  void dispose() {
    _client.close();
  }
}
