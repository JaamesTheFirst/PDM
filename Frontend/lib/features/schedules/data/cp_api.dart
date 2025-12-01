// lib/features/schedules/data/cp_api.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Resultado de pesquisa de estações CP (GET /cp/stops/search)
class CpStopSearchResult {
  final String gtfsId;
  final String name;
  final double? lat;
  final double? lon;

  CpStopSearchResult({
    required this.gtfsId,
    required this.name,
    this.lat,
    this.lon,
  });

  factory CpStopSearchResult.fromJson(Map<String, dynamic> json) {
    return CpStopSearchResult(
      gtfsId: json['gtfsId'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
    );
  }
}

/// Linha da “board” de partidas
class CpStopBoardRow {
  final String time; // "HH:MM"
  final String? destination;
  final String? lineShortName;
  final String? lineLongName;
  final String? routeGtfsId;
  final int delayMinutes;
  final bool isRealtime;

  CpStopBoardRow({
    required this.time,
    this.destination,
    this.lineShortName,
    this.lineLongName,
    this.routeGtfsId,
    required this.delayMinutes,
    required this.isRealtime,
  });

  factory CpStopBoardRow.fromJson(Map<String, dynamic> json) {
    return CpStopBoardRow(
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

/// Board completa de partidas de uma estação (GET /cp/stops/:id/departures/board)
class CpStopBoard {
  final String stopId;
  final String stopName;
  final double? lat;
  final double? lon;
  final List<CpStopBoardRow> departures;

  CpStopBoard({
    required this.stopId,
    required this.stopName,
    this.lat,
    this.lon,
    required this.departures,
  });

  factory CpStopBoard.fromJson(Map<String, dynamic> json) {
    final depsJson = (json['departures'] as List? ?? const []);
    return CpStopBoard(
      stopId: json['stopId'] as String,
      stopName: json['stopName'] as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      departures: depsJson
          .map((e) => CpStopBoardRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CpApiClient {
  CpApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // ⚠️ METE AQUI O IP DA TUA MÁQUINA
  static const String _baseUrl = 'http://192.168.1.244:3000';
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

  // ================== SEARCH STOPS (com fallback sem acentos) ==================

  Future<List<CpStopSearchResult>> searchStops(
    String query, {
    int limit = 5,
  }) async {
    final trimmed = query.trim();
    debugPrint('[CP API] searchStops raw="$trimmed"');

    if (trimmed.length < 2) return [];

    final normalized = _normalizeForSearch(trimmed);
    final Set<String> seenIds = {};
    final List<CpStopSearchResult> allResults = [];

    Future<void> _fetch(String q, {String tag = 'orig'}) async {
      if (allResults.length >= limit) return;

      final uri = _buildUri('/cp/stops/search', {
        'q': q,
        'limit': limit.toString(),
      });

      debugPrint('[CP API] searchStops($tag) -> GET $uri');

      try {
        final resp = await _client.get(uri).timeout(_timeout);
        debugPrint(
            '[CP API] searchStops($tag) status=${resp.statusCode} bodyLen=${resp.body.length}');

        if (resp.statusCode != 200) {
          debugPrint(
              '[CP API] searchStops($tag) HTTP error ${resp.statusCode}');
          return;
        }

        final json = jsonDecode(resp.body);
        if (json is! List) {
          debugPrint(
              '[CP API] searchStops($tag) resposta inesperada (não é array)');
          return;
        }

        for (final item in json) {
          if (allResults.length >= limit) break;
          final stop =
              CpStopSearchResult.fromJson(item as Map<String, dynamic>);
          if (seenIds.add(stop.gtfsId)) {
            allResults.add(stop);
          }
        }
      } on TimeoutException {
        debugPrint('[CP API] searchStops($tag) TIMEOUT');
      } catch (e) {
        debugPrint('[CP API] searchStops($tag) ERROR: $e');
      }
    }

    // 1. tenta com o texto original (com acentos)
    await _fetch(trimmed, tag: 'orig');

    // 2. se normalizado for diferente, tenta também sem acentos/lowercase
    if (allResults.length < limit &&
        normalized != trimmed.toLowerCase()) {
      await _fetch(normalized, tag: 'norm');
    }

    debugPrint(
        '[CP API] searchStops -> ${allResults.length} resultados finais.');
    return allResults;
  }

  // ===================== STOP BOARD (resto do dia / dia inteiro) =====================

  Future<CpStopBoard> getStopBoard({
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
      '/cp/stops/$stopGtfsId/departures/board',
      {
        'startTime': startTime,
        'timeRange': timeRange,
        'numberOfDepartures': numberOfDepartures,
      },
    );

    debugPrint('[CP API] getStopBoard -> GET $uri');

    try {
      final resp = await _client.get(uri).timeout(_timeout);
      debugPrint(
          '[CP API] getStopBoard status=${resp.statusCode} bodyLen=${resp.body.length}');

      if (resp.statusCode != 200) {
        throw Exception(
            'Erro ${resp.statusCode} ao carregar board de partidas CP.');
      }

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final board = CpStopBoard.fromJson(json);
      debugPrint(
          '[CP API] getStopBoard -> ${board.departures.length} partidas.');
      return board;
    } on TimeoutException {
      debugPrint('[CP API] getStopBoard TIMEOUT');
      throw Exception(
          'Timeout ao contactar o servidor CP (getStopBoard).');
    } catch (e) {
      debugPrint('[CP API] getStopBoard ERROR: $e');
      rethrow;
    }
  }
}
