import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const String _envRoutesBase =
    String.fromEnvironment('ROUTES_BASE_URL', defaultValue: '');

String _computeRoutesBase() {
  if (_envRoutesBase.isNotEmpty) return _envRoutesBase;
  if (kIsWeb) return 'http://localhost:3000';
  try {
    if (Platform.isAndroid) {
      const String custom =
          String.fromEnvironment('ROUTES_BASE_URL', defaultValue: '');
      if (custom.isNotEmpty) return custom;
      // Android emulator -> host machine
      return 'http://10.0.2.2:3000';
    }
  } catch (_) {}
  return 'http://localhost:3000';
}

final String kRoutesBaseUrl = _computeRoutesBase();

class OtpLeg {
  final String mode;
  final double distance;
  final int duration;
  final DateTime startTime;
  final DateTime endTime;
  final String fromName;
  final String toName;
  final String? routeName;
  final String? polyline;

  OtpLeg({
    required this.mode,
    required this.distance,
    required this.duration,
    required this.startTime,
    required this.endTime,
    required this.fromName,
    required this.toName,
    this.routeName,
    this.polyline,
  });

  factory OtpLeg.fromJson(Map<String, dynamic> json) {
    return OtpLeg(
      mode: json['mode'] as String,
      distance: (json['distance'] as num).toDouble(),
      duration: (json['duration'] as num).toInt(),
      startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(json['endTime'] as int),
      fromName: json['from']['name'] as String,
      toName: json['to']['name'] as String,
      routeName: json['route']?['shortName'] as String? ??
          json['route']?['longName'] as String?,
      polyline: json['legGeometry']?['points'] as String?,
    );
  }
}

class OtpItinerary {
  final int duration;
  final double walkDistance;
  final DateTime startTime;
  final DateTime endTime;
  final List<OtpLeg> legs;

  OtpItinerary({
    required this.duration,
    required this.walkDistance,
    required this.startTime,
    required this.endTime,
    required this.legs,
  });

  factory OtpItinerary.fromJson(Map<String, dynamic> json) {
    return OtpItinerary(
      duration: (json['duration'] as num).toInt(),
      walkDistance: (json['walkDistance'] as num).toDouble(),
      startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(json['endTime'] as int),
      legs: (json['legs'] as List<dynamic>)
          .map((leg) => OtpLeg.fromJson(leg as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PlannedRoutesResult {
  PlannedRoutesResult({
    required this.originalCount,
    required this.filteredCount,
    required this.filterMode,
    this.maxWalkDistanceMeters,
    required this.itineraries,
  });

  final int originalCount;
  final int filteredCount;
  final String filterMode;
  final double? maxWalkDistanceMeters;
  final List<OtpItinerary> itineraries;
}

class RoutesService {
  RoutesService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<PlannedRoutesResult> plan({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
  }) async {
    final uri = Uri.parse('$kRoutesBaseUrl/routes/plan');
    print('[RoutesService] Calling $uri');
    print('[RoutesService] Body: fromLat=$fromLat, fromLon=$fromLon, toLat=$toLat, toLon=$toLon');
    
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'fromLat': fromLat,
              'fromLon': fromLon,
              'toLat': toLat,
              'toLon': toLon,
              'numItineraries': 5,
            }),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('[RoutesService] Request timed out after 30 seconds');
              throw Exception('Request timed out');
            },
          );

      print('[RoutesService] Response status: ${response.statusCode}');
      print('[RoutesService] Response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');

      if (response.statusCode != 200) {
        throw Exception('OTP request failed: ${response.body}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      print('[RoutesService] Decoded keys: ${decoded.keys.toList()}');
      
      final itinerariesJson =
          (decoded['itineraries'] as List<dynamic>? ?? const []);
      print('[RoutesService] Found ${itinerariesJson.length} itineraries');
      
      final itineraries = itinerariesJson
          .map((e) => OtpItinerary.fromJson(e as Map<String, dynamic>))
          .toList();

      return PlannedRoutesResult(
        originalCount:
            decoded['originalItineraryCount'] as int? ?? itineraries.length,
        filteredCount:
            decoded['filteredItineraryCount'] as int? ?? itineraries.length,
        filterMode: decoded['filterApplied']?['filterMode'] as String? ?? 'ANY',
        maxWalkDistanceMeters:
            (decoded['filterApplied']?['maxWalkDistanceMeters'] as num?)
                ?.toDouble(),
        itineraries: itineraries,
      );
    } catch (e, stackTrace) {
      print('[RoutesService] Error: $e');
      print('[RoutesService] Stack trace: $stackTrace');
      rethrow;
    }
  }
}
