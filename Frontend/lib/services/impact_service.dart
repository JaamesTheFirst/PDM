// lib/services/impact_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'auth_service.dart';

/// Um dia com resumo de impacto
class ImpactDayBucket {
  final String date; // YYYY-MM-DD
  final double totalCo2Kg;
  final double totalCo2SavedKg;
  final double totalDistanceKm;
  final int trips;

  ImpactDayBucket({
    required this.date,
    required this.totalCo2Kg,
    required this.totalCo2SavedKg,
    required this.totalDistanceKm,
    required this.trips,
  });

  factory ImpactDayBucket.fromJson(Map<String, dynamic> json) {
    return ImpactDayBucket(
      date: json['date'] as String,
      totalCo2Kg: (json['totalCo2Kg'] as num).toDouble(),
      totalCo2SavedKg: (json['totalCo2SavedKg'] as num).toDouble(),
      totalDistanceKm: (json['totalDistanceKm'] as num).toDouble(),
      trips: json['trips'] as int,
    );
  }
}

/// Resumo de impacto (serve para week / all-time)
class ImpactSummary {
  final DateTime periodStart;
  final DateTime periodEnd;

  final double totalCo2Kg;
  final double totalCo2SavedKg;
  final double totalDistanceKm;
  final int totalTrips;

  final int ecoTrips;
  final double ecoTripsRatio; // 0–1

  final int activeTrips;
  final double activeTripsRatio; // 0–1
  final double avgEcoScore;
  final List<ImpactDayBucket> days;

  ImpactSummary({
    required this.periodStart,
    required this.periodEnd,
    required this.totalCo2Kg,
    required this.totalCo2SavedKg,
    required this.totalDistanceKm,
    required this.totalTrips,
    required this.ecoTrips,
    required this.ecoTripsRatio,
    required this.activeTrips,
    required this.activeTripsRatio,
    required this.avgEcoScore,
    required this.days,
  });

  factory ImpactSummary.fromJson(Map<String, dynamic> json) {
    final daysJson = (json['days'] as List<dynamic>? ?? []);

    return ImpactSummary(
      periodStart: DateTime.parse(json['periodStart'] as String),
      periodEnd: DateTime.parse(json['periodEnd'] as String),
      totalCo2Kg: (json['totalCo2Kg'] as num).toDouble(),
      totalCo2SavedKg: (json['totalCo2SavedKg'] as num).toDouble(),
      totalDistanceKm: (json['totalDistanceKm'] as num).toDouble(),
      totalTrips: json['totalTrips'] as int,
      ecoTrips: json['ecoTrips'] as int,
      ecoTripsRatio: (json['ecoTripsRatio'] as num).toDouble(),
      activeTrips: json['activeTrips'] as int,
      activeTripsRatio: (json['activeTripsRatio'] as num).toDouble(),
      avgEcoScore: (json['avgEcoScore'] as num?)?.toDouble() ?? 0.0,
      days: daysJson
          .map((e) => ImpactDayBucket.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
  bool get hasAnyTrips => totalTrips > 0;
}

class ImpactService {
  ImpactService._();

  static final ImpactService instance = ImpactService._();

  final ApiClient _client = ApiClient.instance;

  /// Mantém o nome antigo mas por baixo chama o ALL-TIME
  Future<ImpactSummary> getWeeklySummary() async {
    final token = await AuthService.instance.getToken();

    // 👇 trocado para o endpoint all-time
    final http.Response resp = await _client.get(
      '/impact/summary/all-time',
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    if (kDebugMode) {
      debugPrint(
        '[ImpactService] GET /impact/summary/all-time -> '
        '${resp.statusCode} ${resp.body}',
      );
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
        'Erro ao carregar impacto (HTTP ${resp.statusCode}): ${resp.body}',
      );
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return ImpactSummary.fromJson(data);
  }
}
