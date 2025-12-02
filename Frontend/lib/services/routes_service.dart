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
      // Android emulator -> host machine (10.0.2.2)
      // For physical Android devices, you MUST set ROUTES_BASE_URL:
      // flutter run --dart-define=ROUTES_BASE_URL=http://YOUR_WINDOWS_IP:3000
      // Default to 10.0.2.2 (emulator) - will fail on physical devices
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
    // Handle null/missing from/to objects
    final fromObj = json['from'] as Map<String, dynamic>? ?? {};
    final toObj = json['to'] as Map<String, dynamic>? ?? {};
    final routeObj = json['route'] as Map<String, dynamic>?;
    final legGeometryObj = json['legGeometry'] as Map<String, dynamic>?;
    
    return OtpLeg(
      mode: json['mode'] as String? ?? 'UNKNOWN',
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      startTime: DateTime.fromMillisecondsSinceEpoch(
        (json['startTime'] as num?)?.toInt() ?? 0,
      ),
      endTime: DateTime.fromMillisecondsSinceEpoch(
        (json['endTime'] as num?)?.toInt() ?? 0,
      ),
      fromName: fromObj['name'] as String? ?? 'Origin',
      toName: toObj['name'] as String? ?? 'Destination',
      routeName: routeObj?['shortName'] as String? ??
          routeObj?['longName'] as String?,
      polyline: legGeometryObj?['points'] as String?,
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
    final legsJson = json['legs'] as List<dynamic>? ?? [];
    
    return OtpItinerary(
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      walkDistance: (json['walkDistance'] as num?)?.toDouble() ?? 0.0,
      startTime: DateTime.fromMillisecondsSinceEpoch(
        (json['startTime'] as num?)?.toInt() ?? 0,
      ),
      endTime: DateTime.fromMillisecondsSinceEpoch(
        (json['endTime'] as num?)?.toInt() ?? 0,
      ),
      legs: legsJson
          .map((leg) {
            try {
              return OtpLeg.fromJson(leg as Map<String, dynamic>);
            } catch (e) {
              print('[OtpItinerary] Error parsing leg: $e');
              print('[OtpItinerary] Leg data: $leg');
              rethrow;
            }
          })
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

/// Filter preferences for route planning
class RouteFilters {
  final String? filterMode; // 'ANY', 'WALK_ONLY', 'BUS_ONLY', 'RAIL_ONLY', etc.
  final int? maxWalkDistanceMeters;
  final List<String>? modes; // ['WALK', 'TRANSIT'], ['WALK', 'CAR'], etc.

  const RouteFilters({
    this.filterMode,
    this.maxWalkDistanceMeters,
    this.modes,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (filterMode != null) map['filterMode'] = filterMode;
    if (maxWalkDistanceMeters != null) map['maxWalkDistanceMeters'] = maxWalkDistanceMeters;
    if (modes != null) map['modes'] = modes;
    return map;
  }
}

class RoutesService {
  RoutesService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<PlannedRoutesResult> plan({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    RouteFilters? filters,
  }) async {
    final uri = Uri.parse('$kRoutesBaseUrl/routes/plan');
    print('[RoutesService] Calling $uri');
    print('[RoutesService] Body: fromLat=$fromLat, fromLon=$fromLon, toLat=$toLat, toLon=$toLon');
    
    // Build request body with filters
    final body = <String, dynamic>{
      'fromLat': fromLat,
      'fromLon': fromLon,
      'toLat': toLat,
      'toLon': toLon,
      'numItineraries': 5,
    };
    
    if (filters != null) {
      body.addAll(filters.toJson());
    }
    
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('[RoutesService] Request timed out after 30 seconds');
              throw Exception('Request timed out. Verifica se o backend está a correr e se a ligação à rede está ativa.');
            },
          );

      print('[RoutesService] Response status: ${response.statusCode}');
      print('[RoutesService] Response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');

      // Accept both 200 (OK) and 201 (Created) as success
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Erro do servidor: ${response.statusCode}. ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      print('[RoutesService] Decoded keys: ${decoded.keys.toList()}');
      
      final itinerariesJson =
          (decoded['itineraries'] as List<dynamic>? ?? const []);
      print('[RoutesService] Found ${itinerariesJson.length} itineraries');
      
      if (itinerariesJson.isNotEmpty) {
        print('[RoutesService] First itinerary keys: ${(itinerariesJson[0] as Map).keys.toList()}');
        if ((itinerariesJson[0] as Map).containsKey('legs')) {
          final firstLegs = (itinerariesJson[0] as Map)['legs'] as List?;
          if (firstLegs != null && firstLegs.isNotEmpty) {
            print('[RoutesService] First leg keys: ${(firstLegs[0] as Map).keys.toList()}');
            print('[RoutesService] First leg from: ${(firstLegs[0] as Map)['from']}');
            print('[RoutesService] First leg to: ${(firstLegs[0] as Map)['to']}');
          }
        }
      }
      
      final itineraries = <OtpItinerary>[];
      for (var i = 0; i < itinerariesJson.length; i++) {
        try {
          final itinerary = OtpItinerary.fromJson(itinerariesJson[i] as Map<String, dynamic>);
          itineraries.add(itinerary);
          print('[RoutesService] Successfully parsed itinerary $i with ${itinerary.legs.length} legs');
        } catch (e, stackTrace) {
          print('[RoutesService] Error parsing itinerary $i: $e');
          print('[RoutesService] Itinerary data: ${itinerariesJson[i]}');
          print('[RoutesService] Stack: $stackTrace');
          // Continue parsing other itineraries instead of failing completely
        }
      }
      print('[RoutesService] Successfully parsed ${itineraries.length} out of ${itinerariesJson.length} itineraries');

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
