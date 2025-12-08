// lib/features/schedules/data/flixbus_api.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';

/// ====================== ROUTES / LINHAS ======================

class FlixbusRoute {
  final String gtfsId;
  final String? shortName;
  final String? longName;
  final String? mode;
  final String? agencyName;
  final String? agencyGtfsId;

  FlixbusRoute({
    required this.gtfsId,
    this.shortName,
    this.longName,
    this.mode,
    this.agencyName,
    this.agencyGtfsId,
  });

  factory FlixbusRoute.fromJson(Map<String, dynamic> json) {
    return FlixbusRoute(
      gtfsId: json['gtfsId'] as String,
      shortName: json['shortName'] as String?,
      longName: json['longName'] as String?,
      mode: json['mode'] as String?,
      agencyName: json['agencyName'] as String?,
      agencyGtfsId: json['agencyGtfsId'] as String?,
    );
  }
}

class FlixbusStopBasic {
  final String gtfsId;
  final String name;
  final double? lat;
  final double? lon;

  FlixbusStopBasic({
    required this.gtfsId,
    required this.name,
    this.lat,
    this.lon,
  });

  factory FlixbusStopBasic.fromJson(Map<String, dynamic> json) {
    return FlixbusStopBasic(
      gtfsId: json['gtfsId'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
    );
  }
}

class FlixbusRouteDetail {
  final String gtfsId;
  final String? shortName;
  final String? longName;
  final String? mode;
  final String? agencyName;
  final String? agencyGtfsId;
  final List<FlixbusStopBasic> stops;

  FlixbusRouteDetail({
    required this.gtfsId,
    this.shortName,
    this.longName,
    this.mode,
    this.agencyName,
    this.agencyGtfsId,
    required this.stops,
  });

  factory FlixbusRouteDetail.fromJson(Map<String, dynamic> json) {
    final stopsJson = (json['stops'] as List? ?? const []);
    return FlixbusRouteDetail(
      gtfsId: json['gtfsId'] as String,
      shortName: json['shortName'] as String?,
      longName: json['longName'] as String?,
      mode: json['mode'] as String?,
      agencyName: json['agencyName'] as String?,
      agencyGtfsId: json['agencyGtfsId'] as String?,
      stops: stopsJson
          .map((e) => FlixbusStopBasic.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// ====================== SEARCH STOPS / BOARD ======================

/// Resultado de pesquisa de paragens FlixBus (GET /flixbus/stops/search)
class FlixbusStopSearchResult {
  final String gtfsId;
  final String name;
  final double? lat;
  final double? lon;

  FlixbusStopSearchResult({
    required this.gtfsId,
    required this.name,
    this.lat,
    this.lon,
  });

  factory FlixbusStopSearchResult.fromJson(Map<String, dynamic> json) {
    return FlixbusStopSearchResult(
      gtfsId: json['gtfsId'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
    );
  }
}

/// Linha da “board” de partidas FlixBus
class FlixbusStopBoardRow {
  final String time; // "HH:MM"
  final String? destination;
  final String? lineShortName;
  final String? lineLongName;
  final String? routeGtfsId;
  final int delayMinutes;
  final bool isRealtime;

  FlixbusStopBoardRow({
    required this.time,
    this.destination,
    this.lineShortName,
    this.lineLongName,
    this.routeGtfsId,
    required this.delayMinutes,
    required this.isRealtime,
  });

  factory FlixbusStopBoardRow.fromJson(Map<String, dynamic> json) {
    return FlixbusStopBoardRow(
      time: json['time'] as String,
      destination: json['destination'] as String?,
      lineShortName: json['lineShortName'] as String?,
      lineLongName: json['lineLongName'] as String?,
      routeGtfsId: json['routeGtfsId'] as String?,
      delayMinutes: (json['delayMinutes'] as num?)?.toInt() ?? 0,
      isRealtime: json['isRealtime'] as bool? ?? false,
    );
  }
}

/// Board completa de partidas de uma paragem (GET /flixbus/stops/:id/departures/board)
class FlixbusStopBoard {
  final String stopId;
  final String stopName;
  final double? lat;
  final double? lon;
  final List<FlixbusStopBoardRow> departures;

  FlixbusStopBoard({
    required this.stopId,
    required this.stopName,
    this.lat,
    this.lon,
    required this.departures,
  });

  factory FlixbusStopBoard.fromJson(Map<String, dynamic> json) {
    final depsJson = (json['departures'] as List? ?? const []);
    return FlixbusStopBoard(
      stopId: json['stopId'] as String,
      stopName: json['stopName'] as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      departures: depsJson
          .map((e) =>
              FlixbusStopBoardRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// ====================== CLIENT ======================

class FlixbusApiClient {
  FlixbusApiClient({http.Client? client, String? baseUrl})
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

  int _toEpochSeconds(DateTime dt) =>
      dt.millisecondsSinceEpoch ~/ 1000; // local time

  // ===== Normalização sem acentos + lowercase =====

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

  // ================== ROUTES (LINHAS FLIXBUS) ==================

  Future<List<FlixbusRoute>> getRoutes() async {
    final uri = _buildUri('/flixbus/routes/graph');
    debugPrint('[FLIXBUS API] getRoutes -> GET $uri');

    try {
      final resp = await _client.get(uri).timeout(_timeout);
      debugPrint(
        '[FLIXBUS API] getRoutes status=${resp.statusCode} bodyLen=${resp.body.length}',
      );

      if (resp.statusCode != 200) {
        throw Exception(
          'Erro ${resp.statusCode} ao carregar linhas FlixBus.',
        );
      }

      final json = jsonDecode(resp.body);
      if (json is! List) {
        throw Exception(
          'Resposta inesperada em getRoutes (não é array).',
        );
      }

      final routes = json
          .map((e) => FlixbusRoute.fromJson(e as Map<String, dynamic>))
          .toList()
          .cast<FlixbusRoute>();

      debugPrint('[FLIXBUS API] getRoutes -> ${routes.length} linhas.');
      return routes;
    } on TimeoutException {
      debugPrint('[FLIXBUS API] getRoutes TIMEOUT');
      throw Exception(
        'Timeout ao contactar o servidor FlixBus (getRoutes).',
      );
    } catch (e) {
      debugPrint('[FLIXBUS API] getRoutes ERROR: $e');
      rethrow;
    }
  }

  Future<FlixbusRouteDetail> getRouteDetail(String routeGtfsId) async {
    final uri = _buildUri('/flixbus/routes/graph/$routeGtfsId');
    debugPrint('[FLIXBUS API] getRouteDetail($routeGtfsId) -> GET $uri');

    try {
      final resp = await _client.get(uri).timeout(_timeout);
      debugPrint(
        '[FLIXBUS API] getRouteDetail status=${resp.statusCode} bodyLen=${resp.body.length}',
      );

      if (resp.statusCode != 200) {
        throw Exception(
          'Erro ${resp.statusCode} ao carregar detalhe da linha FlixBus.',
        );
      }

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final detail = FlixbusRouteDetail.fromJson(json);
      debugPrint(
        '[FLIXBUS API] getRouteDetail -> ${detail.stops.length} paragens.',
      );
      return detail;
    } on TimeoutException {
      debugPrint('[FLIXBUS API] getRouteDetail TIMEOUT');
      throw Exception(
        'Timeout ao contactar o servidor FlixBus (getRouteDetail).',
      );
    } catch (e) {
      debugPrint('[FLIXBUS API] getRouteDetail ERROR: $e');
      rethrow;
    }
  }

  // ================== SEARCH STOPS (mantemos, se precisares) ==================

  Future<List<FlixbusStopSearchResult>> searchStops(
    String query, {
    int limit = 5,
  }) async {
    final trimmed = query.trim();
    debugPrint('[FLIXBUS API] searchStops raw="$trimmed"');

    if (trimmed.length < 2) return [];

    final normalized = _normalizeForSearch(trimmed);
    final Set<String> seenIds = {};
    final List<FlixbusStopSearchResult> allResults = [];

    Future<void> _fetch(String q, {String tag = 'orig'}) async {
      if (allResults.length >= limit) return;

      final uri = _buildUri('/flixbus/stops/search', {
        'q': q,
        'limit': limit.toString(),
      });

      debugPrint('[FLIXBUS API] searchStops($tag) -> GET $uri');

      try {
        final resp = await _client.get(uri).timeout(_timeout);
        debugPrint(
          '[FLIXBUS API] searchStops($tag) status=${resp.statusCode} bodyLen=${resp.body.length}',
        );

        if (resp.statusCode != 200) {
          debugPrint(
            '[FLIXBUS API] searchStops($tag) HTTP error ${resp.statusCode}',
          );
          return;
        }

        final json = jsonDecode(resp.body);
        if (json is! List) {
          debugPrint(
            '[FLIXBUS API] searchStops($tag) resposta inesperada (não é array)',
          );
          return;
        }

        for (final item in json) {
          if (allResults.length >= limit) break;
          final stop =
              FlixbusStopSearchResult.fromJson(item as Map<String, dynamic>);
          if (seenIds.add(stop.gtfsId)) {
            allResults.add(stop);
          }
        }
      } on TimeoutException {
        debugPrint('[FLIXBUS API] searchStops($tag) TIMEOUT');
      } catch (e) {
        debugPrint('[FLIXBUS API] searchStops($tag) ERROR: $e');
      }
    }

    // 1. texto original
    await _fetch(trimmed, tag: 'orig');

    // 2. versão normalizada
    if (allResults.length < limit &&
        normalized != trimmed.toLowerCase()) {
      await _fetch(normalized, tag: 'norm');
    }

    debugPrint(
      '[FLIXBUS API] searchStops -> ${allResults.length} resultados finais.',
    );
    return allResults;
  }

  // ===================== STOP BOARD (resto do dia / dia inteiro) =====================

  Future<FlixbusStopBoard> getStopBoard({
    required String stopGtfsId,
    required DateTime day,
  }) async {
    final now = DateTime.now();
    final isToday =
        now.year == day.year && now.month == day.month && now.day == day.day;

    late int startTime;
    late int timeRange;

    if (isToday) {
      // Hoje: a partir de agora até ao fim do dia
      startTime = _toEpochSeconds(now);

      final endOfDay =
          DateTime(now.year, now.month, now.day, 23, 59, 59);
      timeRange = endOfDay.difference(now).inSeconds;
      if (timeRange < 0) timeRange = 0;
    } else {
      // Outro dia: dia inteiro
      final startOfDay = DateTime(day.year, day.month, day.day);
      startTime = _toEpochSeconds(startOfDay);
      timeRange = 24 * 3600;
    }

    const numberOfDepartures = 80;

    final uri = _buildUri(
      '/flixbus/stops/$stopGtfsId/departures/board',
      {
        'startTime': startTime,
        'timeRange': timeRange,
        'numberOfDepartures': numberOfDepartures,
      },
    );

    debugPrint('[FLIXBUS API] getStopBoard -> GET $uri');

    try {
      final resp = await _client.get(uri).timeout(_timeout);
      debugPrint(
        '[FLIXBUS API] getStopBoard status=${resp.statusCode} bodyLen=${resp.body.length}',
      );

      if (resp.statusCode != 200) {
        throw Exception(
          'Erro ${resp.statusCode} ao carregar board de partidas FlixBus.',
        );
      }

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final board = FlixbusStopBoard.fromJson(json);
      debugPrint(
        '[FLIXBUS API] getStopBoard -> ${board.departures.length} partidas.',
      );
      return board;
    } on TimeoutException {
      debugPrint('[FLIXBUS API] getStopBoard TIMEOUT');
      throw Exception(
        'Timeout ao contactar o servidor FlixBus (getStopBoard).',
      );
    } catch (e) {
      debugPrint('[FLIXBUS API] getStopBoard ERROR: $e');
      rethrow;
    }
  }
}
