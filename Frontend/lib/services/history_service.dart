import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

const String _envHistoryBase =
    String.fromEnvironment('ROUTES_BASE_URL', defaultValue: '');

String _computeHistoryBase() {
  if (_envHistoryBase.isNotEmpty) return _envHistoryBase;

  if (kIsWeb) return 'http://localhost:3000';

  try {
    if (Platform.isAndroid) {
      const String custom =
          String.fromEnvironment('ROUTES_BASE_URL', defaultValue: '');
      if (custom.isNotEmpty) return custom;
      // Android device -> IP da máquina de desenvolvimento
      return 'http://192.168.1.69:3000';
    }
  } catch (_) {
    // ignore
  }

  return 'http://localhost:3000';
}

final String kHistoryBaseUrl = _computeHistoryBase();

class RouteHistoryItem {
  final String id;
  final String originName;
  final double originLatitude;
  final double originLongitude;
  final String destinationName;
  final double destinationLatitude;
  final double destinationLongitude;
  final String primaryMode;
  final List<String> modes;
  final int distanceMeters;
  final int durationSeconds;
  final String status;

  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? updatedAt;

  final double? co2Kg;
  final double? co2SavedVsCarKg;
  final String? polyline;
  final List<dynamic>? segments;
  final Map<String, dynamic>? metadata;

  RouteHistoryItem({
    required this.id,
    required this.originName,
    required this.originLatitude,
    required this.originLongitude,
    required this.destinationName,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.primaryMode,
    required this.modes,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.status,
    this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.updatedAt,
    this.co2Kg,
    this.co2SavedVsCarKg,
    this.polyline,
    this.segments,
    this.metadata,
  });

  factory RouteHistoryItem.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(String key) {
      final value = json[key];
      if (value is String && value.isNotEmpty) {
        return DateTime.parse(value);
      }
      return null;
    }

    return RouteHistoryItem(
      id: json['id'] as String,
      originName: json['originName'] as String,
      originLatitude: (json['originLatitude'] as num).toDouble(),
      originLongitude: (json['originLongitude'] as num).toDouble(),
      destinationName: json['destinationName'] as String,
      destinationLatitude: (json['destinationLatitude'] as num).toDouble(),
      destinationLongitude: (json['destinationLongitude'] as num).toDouble(),
      primaryMode: json['primaryMode'] as String,
      modes: (json['modes'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      distanceMeters: (json['distanceMeters'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'PLANNED',
      createdAt: _parseDate('createdAt'),
      startedAt: _parseDate('startedAt'),
      finishedAt: _parseDate('finishedAt'),
      updatedAt: _parseDate('updatedAt'),
      co2Kg: (json['co2Kg'] as num?)?.toDouble(),
      co2SavedVsCarKg: (json['co2SavedVsCarKg'] as num?)?.toDouble(),
      polyline: json['polyline'] as String?,
      segments: json['segments'] as List<dynamic>?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

class HistoryService {
  HistoryService._();
  static final HistoryService instance = HistoryService._();

  final _auth = AuthService.instance;
  final _client = http.Client();

  Future<List<RouteHistoryItem>> getHistory({int limit = 20}) async {
    final token = await _auth.getToken();
    if (token == null) {
      debugPrint('[HistoryService] No token found - user not authenticated');
      throw Exception('Not authenticated');
    }

    final uri = Uri.parse('$kHistoryBaseUrl/routes/history')
        .replace(queryParameters: {'limit': limit.toString()});

    debugPrint('[HistoryService] Fetching history from: $uri');
    debugPrint('[HistoryService] Using base URL: $kHistoryBaseUrl');

    try {
      final response = await _client.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      debugPrint('[HistoryService] Response status: ${response.statusCode}');
      debugPrint(
          '[HistoryService] Response body length: ${response.body.length}');

      if (response.statusCode == 401) {
        debugPrint(
            '[HistoryService] 401 Unauthorized - token might be invalid');
        throw Exception('Not authenticated');
      }

      if (response.statusCode != 200) {
        debugPrint('[HistoryService] Error response: ${response.body}');
        throw Exception(
          'Failed to fetch history: ${response.statusCode} ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body) as List<dynamic>;
      debugPrint('[HistoryService] Found ${decoded.length} history items');

      return decoded
          .map((e) => RouteHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[HistoryService] Exception: $e');
      rethrow;
    }
  }

  /// Guarda uma rota escolhida no backend.
  ///
  /// [payload] deve ter:
  /// {
  ///   "itinerary": {...}, // JSON do itinerary OTP
  ///   "originName": "...",
  ///   "originLatitude": ...,
  ///   "originLongitude": ...,
  ///   "destinationName": "...",
  ///   "destinationLatitude": ...,
  ///   "destinationLongitude": ...
  /// }
  Future<void> saveRouteFromItinerary(Map<String, dynamic> payload) async {
    final token = await _auth.getToken();
    if (token == null) {
      debugPrint('[HistoryService] No token found - user not authenticated');
      throw Exception('Not authenticated');
    }

    final uri = Uri.parse('$kHistoryBaseUrl/routes/history');

    debugPrint('[HistoryService] Saving route to: $uri');

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Request timed out');
            },
          );

      debugPrint('[HistoryService] Save status: ${response.statusCode}');
      if (response.statusCode == 401) {
        debugPrint(
            '[HistoryService] 401 Unauthorized when saving route history');
        throw Exception('Not authenticated');
      }

      if (response.statusCode != 201 && response.statusCode != 200) {
        debugPrint('[HistoryService] Error saving: ${response.body}');
        throw Exception(
          'Failed to save route: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[HistoryService] Exception saving route: $e');
      rethrow;
    }
  }
}
