// lib/features/schedules/data/carris_api.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../services/api_client.dart';

/// Resultado de pesquisa de paragens Carris (GET `/carris/stops/search`).
class CarrisStopSearchResult {
  /// ID GTFS (nodeId) usado pelo OTP/GTFS.
  final String gtfsId;

  /// Nome da paragem (human-readable).
  final String name;

  /// Latitude aproximada da paragem (se existir).
  final double? lat;

  /// Longitude aproximada da paragem (se existir).
  final double? lon;

  CarrisStopSearchResult({
    required this.gtfsId,
    required this.name,
    this.lat,
    this.lon,
  });

  factory CarrisStopSearchResult.fromJson(Map<String, dynamic> json) {
    return CarrisStopSearchResult(
      gtfsId: json['id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
    );
  }
}

/// Representa uma linha/rota Carris (parte da resposta de partidas).
class CarrisRoute {
  final String id;
  final String? shortName;
  final String? longName;
  final String? mode;

  CarrisRoute({
    required this.id,
    this.shortName,
    this.longName,
    this.mode,
  });

  factory CarrisRoute.fromJson(Map<String, dynamic> json) {
    return CarrisRoute(
      id: json['id'] as String,
      shortName: json['shortName'] as String?,
      longName: json['longName'] as String?,
      mode: json['mode'] as String?,
    );
  }
}

/// Informação básica de uma paragem Carris (usada nas partidas).
class CarrisStop {
  final String id;
  final String name;
  final double? lat;
  final double? lon;

  CarrisStop({
    required this.id,
    required this.name,
    this.lat,
    this.lon,
  });

  factory CarrisStop.fromJson(Map<String, dynamic> json) {
    return CarrisStop(
      id: json['id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
    );
  }
}

/// Dados brutos de um stopTime OTP (serviceDay + departure, etc.).
class CarrisStopTime {
  /// Dia de serviço em epoch seconds (UTC).
  final int serviceDay;

  /// Partida programada (segundos desde [serviceDay]).
  final int scheduledDeparture;

  /// Partida em tempo real (segundos desde [serviceDay]).
  final int realtimeDeparture;

  /// Atraso em segundos (pode ser negativo).
  final int departureDelay;

  final String? stopHeadsign;
  final String? tripHeadsign;
  final String? routeId;
  final String? tripId;
  final String? directionId;

  CarrisStopTime({
    required this.serviceDay,
    required this.scheduledDeparture,
    required this.realtimeDeparture,
    required this.departureDelay,
    this.stopHeadsign,
    this.tripHeadsign,
    this.routeId,
    this.tripId,
    this.directionId,
  });

  factory CarrisStopTime.fromJson(Map<String, dynamic> json) {
    return CarrisStopTime(
      serviceDay: (json['serviceDay'] as num).toInt(),
      scheduledDeparture: (json['scheduledDeparture'] as num).toInt(),
      realtimeDeparture: (json['realtimeDeparture'] as num).toInt(),
      departureDelay: (json['departureDelay'] as num).toInt(),
      stopHeadsign: json['stopHeadsign'] as String?,
      tripHeadsign: json['tripHeadsign'] as String?,
      routeId: json['routeId'] as String?,
      tripId: json['tripId'] as String?,
      directionId: json['directionId'] as String?,
    );
  }
}

/// Partida futura Carris (GET `/carris/stops/:id/departures`).
class CarrisUpcomingDeparture {
  final CarrisStop stop;
  final CarrisRoute route;
  final CarrisStopTime stopTime;

  CarrisUpcomingDeparture({
    required this.stop,
    required this.route,
    required this.stopTime,
  });

  factory CarrisUpcomingDeparture.fromJson(Map<String, dynamic> json) {
    return CarrisUpcomingDeparture(
      stop: CarrisStop.fromJson(json['stop'] as Map<String, dynamic>),
      route: CarrisRoute.fromJson(json['route'] as Map<String, dynamic>),
      stopTime:
          CarrisStopTime.fromJson(json['stopTime'] as Map<String, dynamic>),
    );
  }

  /// Hora “bonita” em formato `HH:MM` em hora local.
  String get timeLabel {
    final seconds = stopTime.serviceDay + stopTime.realtimeDeparture;
    final dt = DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    ).toLocal();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// Destino preferido para mostrar no UI.
  String get destinationLabel {
    return stopTime.tripHeadsign ??
        stopTime.stopHeadsign ??
        route.longName ??
        stop.name;
  }

  /// Nome de linha (shortName se existir).
  String get lineLabel {
    return route.shortName ?? route.longName ?? '';
  }

  /// Atraso em minutos (pode ser negativo).
  int get delayMinutes {
    return (stopTime.departureDelay / 60).round();
  }

  /// Indica se existe dado em tempo real (vs apenas horário programado).
  bool get isRealtime {
    // Se há diferença entre scheduled e realtime, assumimos realtime.
    return stopTime.departureDelay != 0;
  }
}

/// Cliente HTTP para endpoints Carris expostos pelo teu backend.
class CarrisApiClient {
  CarrisApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? kBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 8);

  Uri _buildUri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse('$_baseUrl$path').replace(
      queryParameters: query?.map(
        (k, v) => MapEntry(k, v.toString()),
      ),
    );
  }

  // ===== Normalização sem acentos + lowercase (igual CP) =====

  String _normalizeForSearch(String input) {
    const mapping = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'Á': 'a',
      'À': 'a',
      'Â': 'a',
      'Ã': 'a',
      'Ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'É': 'e',
      'È': 'e',
      'Ê': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'Í': 'i',
      'Ì': 'i',
      'Î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'Ó': 'o',
      'Ò': 'o',
      'Ô': 'o',
      'Õ': 'o',
      'Ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'Ú': 'u',
      'Ù': 'u',
      'Û': 'u',
      'Ü': 'u',
      'ç': 'c',
      'Ç': 'c',
    };

    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      buffer.write(mapping[ch] ?? ch);
    }
    return buffer.toString().toLowerCase();
  }

  // ================== SEARCH STOPS ==================

  /// Pesquisa paragens Carris (autocomplete).
  ///
  /// Faz duas tentativas:
  /// 1. Texto original
  /// 2. Versão normalizada sem acentos (se for diferente)
  Future<List<CarrisStopSearchResult>> searchStops(
    String query, {
    int limit = 5,
  }) async {
    final trimmed = query.trim();
    debugPrint('[CARRIS API] searchStops raw="$trimmed"');

    if (trimmed.length < 2) return [];

    final normalized = _normalizeForSearch(trimmed);
    final seenIds = <String>{};
    final allResults = <CarrisStopSearchResult>[];

    Future<void> fetch(String q, {String tag = 'orig'}) async {
      if (allResults.length >= limit) return;

      final uri = _buildUri('/carris/stops/search', {
        'q': q,
        'limit': limit.toString(),
      });

      debugPrint('[CARRIS API] searchStops($tag) -> GET $uri');

      try {
        final resp = await _client.get(uri).timeout(_timeout);
        debugPrint(
          '[CARRIS API] searchStops($tag) status=${resp.statusCode} '
          'bodyLen=${resp.body.length}',
        );

        if (resp.statusCode != 200) {
          debugPrint(
            '[CARRIS API] searchStops($tag) HTTP error ${resp.statusCode}',
          );
          return;
        }

        final decoded = jsonDecode(resp.body);
        if (decoded is! List) {
          debugPrint(
            '[CARRIS API] searchStops($tag) resposta inesperada (não é array)',
          );
          return;
        }

        for (final item in decoded) {
          if (allResults.length >= limit) break;
          final stop = CarrisStopSearchResult.fromJson(
            item as Map<String, dynamic>,
          );
          if (seenIds.add(stop.gtfsId)) {
            allResults.add(stop);
          }
        }
      } on TimeoutException {
        debugPrint('[CARRIS API] searchStops($tag) TIMEOUT');
      } catch (e) {
        debugPrint('[CARRIS API] searchStops($tag) ERROR: $e');
      }
    }

    await fetch(trimmed, tag: 'orig');

    if (allResults.length < limit && normalized != trimmed.toLowerCase()) {
      await fetch(normalized, tag: 'norm');
    }

    debugPrint(
      '[CARRIS API] searchStops -> ${allResults.length} resultados finais.',
    );
    return allResults;
  }

  // =========== PARTIDAS PRÓXIMAS (hoje / próximos minutos) ===========

  /// Lista partidas futuras para uma paragem Carris.
  ///
  /// Backend: `GET /carris/stops/:id/departures?limit=`.
  Future<List<CarrisUpcomingDeparture>> getUpcomingDepartures({
    required String stopGtfsId,
    int limit = 20,
  }) async {
    final uri = _buildUri(
      '/carris/stops/$stopGtfsId/departures',
      {'limit': limit.toString()},
    );

    debugPrint('[CARRIS API] getUpcomingDepartures -> GET $uri');

    try {
      final resp = await _client.get(uri).timeout(_timeout);
      debugPrint(
        '[CARRIS API] getUpcomingDepartures status=${resp.statusCode} '
        'bodyLen=${resp.body.length}',
      );

      if (resp.statusCode != 200) {
        throw Exception(
          'Erro ${resp.statusCode} ao carregar partidas Carris.',
        );
      }

      final decoded = jsonDecode(resp.body);
      if (decoded is! List) {
        throw Exception(
          'Resposta inesperada do servidor Carris (não é lista).',
        );
      }

      final deps = decoded
          .map(
            (e) => CarrisUpcomingDeparture.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList()
          .cast<CarrisUpcomingDeparture>();

      debugPrint(
        '[CARRIS API] getUpcomingDepartures -> ${deps.length} partidas.',
      );
      return deps;
    } on TimeoutException {
      debugPrint('[CARRIS API] getUpcomingDepartures TIMEOUT');
      throw Exception(
        'Timeout ao contactar o servidor Carris (getUpcomingDepartures).',
      );
    } catch (e) {
      debugPrint('[CARRIS API] getUpcomingDepartures ERROR: $e');
      rethrow;
    }
  }
}
