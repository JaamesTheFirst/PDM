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
      // Android emulator -> host machine
      return 'http://10.0.2.2:3000';
    }
  } catch (_) {}
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
  final DateTime createdAt;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String status;

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
    required this.createdAt,
    required this.startedAt,
    this.finishedAt,
    required this.status,
  });

  factory RouteHistoryItem.fromJson(Map<String, dynamic> json) {
    return RouteHistoryItem(
      id: json['id'] as String,
      originName: json['originName'] as String,
      originLatitude: (json['originLatitude'] as num).toDouble(),
      originLongitude: (json['originLongitude'] as num).toDouble(),
      destinationName: json['destinationName'] as String,
      destinationLatitude: (json['destinationLatitude'] as num).toDouble(),
      destinationLongitude: (json['destinationLongitude'] as num).toDouble(),
      primaryMode: json['primaryMode'] as String,
      modes: (json['modes'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      distanceMeters: json['distanceMeters'] as int,
      durationSeconds: json['durationSeconds'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      startedAt: DateTime.parse(json['startedAt'] as String),
      finishedAt: json['finishedAt'] != null
          ? DateTime.parse(json['finishedAt'] as String)
          : null,
      status: json['status'] as String,
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
      print('[HistoryService] No token found - user not authenticated');
      throw Exception('Not authenticated');
    }

    final uri = Uri.parse('$kHistoryBaseUrl/routes/history')
        .replace(queryParameters: {'limit': limit.toString()});
    
    print('[HistoryService] Fetching history from: $uri');
    print('[HistoryService] Using base URL: $kHistoryBaseUrl');

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

      print('[HistoryService] Response status: ${response.statusCode}');
      print('[HistoryService] Response body length: ${response.body.length}');

      if (response.statusCode == 401) {
        print('[HistoryService] 401 Unauthorized - token might be invalid');
        throw Exception('Not authenticated');
      }

      if (response.statusCode != 200) {
        print('[HistoryService] Error response: ${response.body}');
        throw Exception('Failed to fetch history: ${response.statusCode} ${response.body}');
      }

      final decoded = jsonDecode(response.body) as List<dynamic>;
      print('[HistoryService] Found ${decoded.length} history items');
      
      return decoded
          .map((e) => RouteHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[HistoryService] Exception: $e');
      rethrow;
    }
  }
}

