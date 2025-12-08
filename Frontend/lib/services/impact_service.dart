import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'auth_service.dart';

/// Estrutura de um dia com resumo de impacto ambiental.
class ImpactDayBucket {
  /// Data no formato `YYYY-MM-DD`.
  final String date;

  /// Emissões totais de CO₂ nesse dia (kg).
  final double totalCo2Kg;

  /// CO₂ poupado face ao cenário de carro nesse dia (kg).
  final double totalCo2SavedKg;

  /// Distância total percorrida nesse dia (km).
  final double totalDistanceKm;

  /// Número de viagens realizadas nesse dia.
  final int trips;

  ImpactDayBucket({
    required this.date,
    required this.totalCo2Kg,
    required this.totalCo2SavedKg,
    required this.totalDistanceKm,
    required this.trips,
  });

  /// Cria [ImpactDayBucket] a partir do JSON devolvido pelo backend.
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

/// Resumo de impacto global (semana / all-time).
class ImpactSummary {
  /// Início do período considerado.
  final DateTime periodStart;

  /// Fim do período considerado.
  final DateTime periodEnd;

  /// CO₂ total emitido no período (kg).
  final double totalCo2Kg;

  /// CO₂ total poupado face ao cenário de carro (kg).
  final double totalCo2SavedKg;

  /// Distância total percorrida (km).
  final double totalDistanceKm;

  /// Número total de viagens.
  final int totalTrips;

  /// Número de viagens consideradas “eco”.
  final int ecoTrips;

  /// Percentagem de viagens “eco” (0–1).
  final double ecoTripsRatio;

  /// Número de viagens com actividade física (walking/bike, etc.).
  final int activeTrips;

  /// Percentagem de viagens activas (0–1).
  final double activeTripsRatio;

  /// Eco score médio das viagens no período.
  final double avgEcoScore;

  /// Lista de buckets agregados por dia.
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

  /// Cria [ImpactSummary] a partir do JSON devolvido pelo backend.
  factory ImpactSummary.fromJson(Map<String, dynamic> json) {
    final List<dynamic> daysJson = json['days'] as List<dynamic>? ?? <dynamic>[];

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
          .map((dynamic e) =>
              ImpactDayBucket.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Indica se o utilizador tem pelo menos uma viagem neste período.
  bool get hasAnyTrips => totalTrips > 0;
}

/// Serviço para obter resumos de impacto do backend.
class ImpactService {
  ImpactService._();

  /// Instância singleton do [ImpactService].
  static final ImpactService instance = ImpactService._();

  final ApiClient _client = ApiClient.instance;

  /// Obtém o resumo de impacto "all-time" do utilizador autenticado.
  ///
  /// Mantém o nome histórico `getWeeklySummary`, mas actualmente o
  /// endpoint usado é `/impact/summary/all-time`.
  ///
  /// Em caso de erro HTTP (status fora de 200–299), lança [Exception].
  Future<ImpactSummary> getWeeklySummary() async {
    final String? token = await AuthService.instance.getToken();

    final http.Response resp = await _client.get(
      '/impact/summary/all-time',
      headers: <String, String>{
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    if (kDebugMode) {
      debugPrint(
        '[ImpactService] GET /impact/summary/all-time '
        '-> ${resp.statusCode} ${resp.body}',
      );
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
        'Erro ao carregar impacto (HTTP ${resp.statusCode}): ${resp.body}',
      );
    }

    final Map<String, dynamic> data =
        jsonDecode(resp.body) as Map<String, dynamic>;

    return ImpactSummary.fromJson(data);
  }
}
