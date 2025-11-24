import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const String _envRoutesBase =
    String.fromEnvironment('ROUTES_BASE_URL', defaultValue: '');

String _computeRoutesBase() {
  if (_envRoutesBase.isNotEmpty) return _envRoutesBase;
  if (kIsWeb) return 'http://localhost:3002';
  try {
    if (Platform.isAndroid) {
      const String custom =
          String.fromEnvironment('ROUTES_BASE_URL', defaultValue: '');
      if (custom.isNotEmpty) return custom;
      // Android emulator -> host machine
      return 'http://10.0.2.2:3002';
    }
  } catch (_) {}
  return 'http://localhost:3002';
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

  OtpLeg({
    required this.mode,
    required this.distance,
    required this.duration,
    required this.startTime,
    required this.endTime,
    required this.fromName,
    required this.toName,
    this.routeName,
  });

  factory OtpLeg.fromJson(Map<String, dynamic> json) {
    return OtpLeg(
      mode: json['mode'] as String,
      distance: (json['distance'] as num).toDouble(),
      duration: json['duration'] as int,
      startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(json['endTime'] as int),
      fromName: json['from']['name'] as String,
      toName: json['to']['name'] as String,
      routeName: json['route']?['shortName'] as String? ??
          json['route']?['longName'] as String?,
    );
  }
}

class OtpItinerary {
  final int duration;
  final double walkDistance;
  final List<OtpLeg> legs;

  OtpItinerary({
    required this.duration,
    required this.walkDistance,
    required this.legs,
  });

  factory OtpItinerary.fromJson(Map<String, dynamic> json) {
    return OtpItinerary(
      duration: json['duration'] as int,
      walkDistance: (json['walkDistance'] as num).toDouble(),
      legs: (json['legs'] as List<dynamic>)
          .map((leg) => OtpLeg.fromJson(leg as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RoutesService {
  RoutesService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<OtpItinerary>> plan({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
  }) async {
    final uri = Uri.parse('$kRoutesBaseUrl/routes/plan');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fromLat': fromLat,
        'fromLon': fromLon,
        'toLat': toLat,
        'toLon': toLon,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('OTP request failed: ${response.body}');
    }

    final List<dynamic> parsed = jsonDecode(response.body) as List<dynamic>;
    return parsed
        .map((e) => OtpItinerary.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

