// lib/features/schedules/data/metro_porto_api.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../services/api_client.dart';

/// Modelo de uma paragem do Metro do Porto (vinda do backend).
class MetroPortoStop {
  final String id;
  final String name;
  final String? code;
  final double? lat;
  final double? lon;

  MetroPortoStop({
    required this.id,
    required this.name,
    this.code,
    this.lat,
    this.lon,
  });

  factory MetroPortoStop.fromJson(Map<String, dynamic> json) {
    return MetroPortoStop(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
    );
  }
}

/// Linha da lista de partidas (já pronta para o UI).
class MetroPortoDepartureRow {
  /// Hora `"HH:MM"`.
  final String time;

  /// Destino (headsign).
  final String destination;

  /// Nome da linha (shortName ou longName).
  final String line;

  /// Atraso em minutos (pode ser 0).
  final int delayMinutes;

  MetroPortoDepartureRow({
    required this.time,
    required this.destination,
    required this.line,
    required this.delayMinutes,
  });
}

/// Cliente para endpoints Metro do Porto.
class MetroPortoApiClient {
  final String baseUrl;
  final http.Client _client;

  MetroPortoApiClient({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? kBaseUrl,
        _client = client ?? http.Client();

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    if (query == null) return uri;
    return uri.replace(queryParameters: query);
  }

  // ============ SEARCH STOPS (autocomplete) ============

  /// Pesquisa estações do Metro do Porto via backend.
  Future<List<MetroPortoStop>> searchStops(
    String query, {
    int limit = 10,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final uri = _uri('/metro/porto/stops/search', {
      'q': q,
      'limit': '$limit',
    });

    debugPrint('[METRO API] searchStops -> GET $uri');

    try {
      final res = await _client
          .get(uri)
          .timeout(const Duration(seconds: 7));

      debugPrint(
        '[METRO API] searchStops status=${res.statusCode} '
        'len=${res.bodyBytes.length}',
      );

      if (res.statusCode != 200) {
        throw Exception(
          'Erro ao pesquisar estações do Metro do Porto '
          '(HTTP ${res.statusCode}).',
        );
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! List) {
        throw Exception(
          'Resposta inválida do servidor na pesquisa de estações.',
        );
      }

      return decoded
          .cast<Map<String, dynamic>>()
          .map(MetroPortoStop.fromJson)
          .toList();
    } on TimeoutException {
      throw Exception(
        'Timeout ao contactar o servidor Metro do Porto (searchStops).',
      );
    } catch (e) {
      debugPrint('[METRO API] searchStops ERROR: $e');
      rethrow;
    }
  }

  // ============ UPCOMING DEPARTURES ============

  /// Lista partidas futuras de uma estação do Metro do Porto.
  Future<List<MetroPortoDepartureRow>> getUpcomingDepartures({
    required String stopId,
    int limit = 20,
  }) async {
    final uri = _uri(
      '/metro/porto/stops/$stopId/departures',
      {
        'limit': '$limit',
      },
    );

    debugPrint('[METRO API] getUpcomingDepartures -> GET $uri');

    try {
      final res = await _client
          .get(uri)
          .timeout(const Duration(seconds: 7));

      debugPrint(
        '[METRO API] getUpcomingDepartures status=${res.statusCode} '
        'len=${res.bodyBytes.length}',
      );

      if (res.statusCode != 200) {
        throw Exception(
          'Erro ao carregar partidas do Metro do Porto '
          '(HTTP ${res.statusCode}).',
        );
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! List) {
        throw Exception(
          'Resposta inválida do servidor nas partidas do Metro do Porto.',
        );
      }

      final rows = <MetroPortoDepartureRow>[];

      for (final raw in decoded.cast<Map<String, dynamic>>()) {
        final route = raw['route'] as Map<String, dynamic>?;
        final stopTime = raw['stopTime'] as Map<String, dynamic>?;

        if (route == null || stopTime == null) continue;

        final serviceDay =
            (stopTime['serviceDay'] as num?)?.toInt() ?? 0;
        final realtimeDeparture =
            (stopTime['realtimeDeparture'] as num?)?.toInt() ??
                (stopTime['scheduledDeparture'] as num?)?.toInt() ??
                0;
        final scheduledDeparture =
            (stopTime['scheduledDeparture'] as num?)?.toInt() ?? 0;
        final delaySeconds =
            (stopTime['departureDelay'] as num?)?.toInt() ?? 0;

        final epochSeconds = serviceDay + realtimeDeparture;
        final date = DateTime.fromMillisecondsSinceEpoch(
          epochSeconds * 1000,
        );
        final hh = date.hour.toString().padLeft(2, '0');
        final mm = date.minute.toString().padLeft(2, '0');
        final timeStr = '$hh:$mm';

        final headsignRaw =
            stopTime['stopHeadsign'] ?? stopTime['tripHeadsign'] ?? '';
        final headsign = headsignRaw as String;

        final shortNameRaw = route['shortName'] ?? '';
        final longNameRaw = route['longName'] ?? '';
        final shortName = shortNameRaw as String;
        final longName = longNameRaw as String;

        final lineName =
            shortName.isNotEmpty ? shortName : longName;

        final delayMinutes = (delaySeconds / 60).round();

        rows.add(
          MetroPortoDepartureRow(
            time: timeStr,
            destination: headsign,
            line: lineName,
            delayMinutes: delayMinutes,
          ),
        );
      }

      return rows;
    } on TimeoutException {
      throw Exception(
        'Timeout ao contactar o servidor Metro do Porto '
        '(getUpcomingDepartures).',
      );
    } catch (e) {
      debugPrint('[METRO API] getUpcomingDepartures ERROR: $e');
      rethrow;
    }
  }
}
