import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Base URL para o módulo de planeamento de rotas.
///
/// Pode ser sobreposta via:
/// `--dart-define=ROUTES_BASE_URL=http://...`
/// Se não estiver definida, usa o valor do [AppConfig] gerado pelo spin-up script.
const String _envRoutesBase =
    String.fromEnvironment('ROUTES_BASE_URL', defaultValue: '');

/// Base URL efectiva usada para planeamento de rotas.
final String kRoutesBaseUrl =
    _envRoutesBase.isNotEmpty ? _envRoutesBase : AppConfig.apiBaseUrl;

/// Leg (segmento) de um itinerário OTP.
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

  /// `true` se for uma leg de bike-share.
  final bool? rentedBike;

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
    this.rentedBike,
  });

  /// Cria [OtpLeg] a partir do JSON devolvido pelo OTP.
  factory OtpLeg.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> fromObj =
        json['from'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final Map<String, dynamic> toObj =
        json['to'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final Map<String, dynamic>? routeObj =
        json['route'] as Map<String, dynamic>?;
    final Map<String, dynamic>? legGeometryObj =
        json['legGeometry'] as Map<String, dynamic>?;

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
      routeName:
          routeObj?['shortName'] as String? ?? routeObj?['longName'] as String?,
      polyline: legGeometryObj?['points'] as String?,
      rentedBike: json['rentedBike'] as bool?,
    );
  }
}

/// Itinerário completo devolvido pelo OTP.
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

  /// Cria [OtpItinerary] a partir do JSON do OTP.
  factory OtpItinerary.fromJson(Map<String, dynamic> json) {
    final List<dynamic> legsJson = json['legs'] as List<dynamic>? ?? <dynamic>[];

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
          .map<OtpLeg>((dynamic leg) {
            try {
              return OtpLeg.fromJson(leg as Map<String, dynamic>);
            } catch (e) {
              debugPrint('[OtpItinerary] Error parsing leg: $e');
              debugPrint('[OtpItinerary] Leg data: $leg');
              rethrow;
            }
          })
          .toList(),
    );
  }
}

/// Resultado da operação de planeamento de rotas.
///
/// Contém:
/// - [originalCount]: nº de itinerários antes de filtros.
/// - [filteredCount]: nº de itinerários após filtros.
/// - [filterMode]: modo de filtro aplicado no backend.
/// - [maxWalkDistanceMeters]: limite de walking usado.
/// - [itineraries]: lista final de [OtpItinerary].
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

/// Preferências de filtro para planeamento de rotas.
class RouteFilters {
  /// Modo de filtro para o backend (`ANY`, `WALK_ONLY`, `BUS_ONLY`, etc.).
  final String? filterMode;

  /// Distância máxima de walking em metros.
  final int? maxWalkDistanceMeters;

  /// Modos base para o OTP (`['WALK', 'TRANSIT']`, `['WALK', 'CAR']`, etc.).
  final List<String>? modes;

  /// Tipos de transporte público para granular endpoint
  /// (`['BUS', 'RAIL', 'METRO', ...]`).
  final List<String>? transitTypes;

  const RouteFilters({
    this.filterMode,
    this.maxWalkDistanceMeters,
    this.modes,
    this.transitTypes,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = <String, dynamic>{};
    if (filterMode != null) map['filterMode'] = filterMode;
    if (maxWalkDistanceMeters != null) {
      map['maxWalkDistanceMeters'] = maxWalkDistanceMeters;
    }
    if (modes != null && modes!.isNotEmpty) {
      map['modes'] = modes;
    }
    if (transitTypes != null && transitTypes!.isNotEmpty) {
      map['transitTypes'] = transitTypes;
    }
    return map;
  }

  /// Indica se existe pelo menos um filtro activo.
  bool get hasActiveFilters =>
      (modes != null && modes!.isNotEmpty) ||
      (transitTypes != null && transitTypes!.isNotEmpty) ||
      filterMode != null ||
      maxWalkDistanceMeters != null;

  /// Indica se este filtro requer o endpoint granular no backend.
  bool get requiresGranularEndpoint =>
      transitTypes != null && transitTypes!.isNotEmpty;
}

/// Serviço para chamar o backend de planeamento de rotas.
///
/// Esconde a lógica de:
/// - Construção do body adequado (com/sem filtros granulares);
/// - Tratamento de timeouts;
/// - Parsing dos itinerários OTP.
class RoutesService {
  RoutesService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Planeia rotas entre dois pontos.
  ///
  /// - Usa `/routes/plan` por omissão;
  /// - Usa `/routes/plan-granular` quando [filters.requiresGranularEndpoint]
  ///   for `true`.
  Future<PlannedRoutesResult> plan({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    RouteFilters? filters,
  }) async {
    // Usa granular endpoint se transitTypes estiverem definidos.
    final bool useGranular = filters?.requiresGranularEndpoint ?? false;
    final String endpoint = useGranular ? 'plan-granular' : 'plan';
    final Uri uri = Uri.parse('$kRoutesBaseUrl/routes/$endpoint');

    debugPrint('[RoutesService] Calling $uri');
    debugPrint(
      '[RoutesService] Body: fromLat=$fromLat, fromLon=$fromLon, '
      'toLat=$toLat, toLon=$toLon',
    );

    // Body base.
    final Map<String, dynamic> body = <String, dynamic>{
      'fromLat': fromLat,
      'fromLon': fromLon,
      'toLat': toLat,
      'toLon': toLon,
      'numItineraries': 5,
    };

    // Acrescentar filtros conforme o endpoint.
    if (filters != null) {
      if (useGranular) {
        body['baseModes'] = filters.modes ?? <String>['WALK', 'TRANSIT'];
        if (filters.transitTypes != null &&
            filters.transitTypes!.isNotEmpty) {
          body['transitTypes'] = filters.transitTypes;
        }
        if (filters.maxWalkDistanceMeters != null) {
          body['maxWalkDistanceMeters'] = filters.maxWalkDistanceMeters;
        }
      } else {
        body.addAll(filters.toJson());
        // `transitTypes` não é suportado no endpoint regular.
        body.remove('transitTypes');
      }
    }

    try {
      final http.Response response = await _client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint(
                '[RoutesService] Request timed out after 30 seconds',
              );
              throw Exception(
                'Request timed out. Verifica se o backend está a correr '
                'e se a ligação à rede está ativa.',
              );
            },
          );

      debugPrint('[RoutesService] Response status: ${response.statusCode}');
      final int maxLen = response.body.length > 500 ? 500 : response.body.length;
      debugPrint(
        '[RoutesService] Response body: ${response.body.substring(0, maxLen)}',
      );

      // Aceita 200 (OK) e 201 (Created) como sucesso.
      if (response.statusCode != 200 && response.statusCode != 201) {
        final String bodyPreview = response.body.length > 200
            ? response.body.substring(0, 200)
            : response.body;
        throw Exception(
          'Erro do servidor: ${response.statusCode}. $bodyPreview',
        );
      }

      final Map<String, dynamic> decoded =
          jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint(
        '[RoutesService] Decoded keys: ${decoded.keys.toList()}',
      );

      final List<dynamic> itinerariesJson =
          decoded['itineraries'] as List<dynamic>? ?? const <dynamic>[];
      debugPrint(
        '[RoutesService] Found ${itinerariesJson.length} itineraries',
      );

      if (itinerariesJson.isNotEmpty) {
        final Map<dynamic, dynamic> firstItinerary =
            itinerariesJson.first as Map<dynamic, dynamic>;
        debugPrint(
          '[RoutesService] First itinerary keys: '
          '${firstItinerary.keys.toList()}',
        );
        if (firstItinerary.containsKey('legs')) {
          final List<dynamic>? firstLegs =
              firstItinerary['legs'] as List<dynamic>?;
          if (firstLegs != null && firstLegs.isNotEmpty) {
            final Map<dynamic, dynamic> firstLeg =
                firstLegs.first as Map<dynamic, dynamic>;
            debugPrint(
              '[RoutesService] First leg keys: ${firstLeg.keys.toList()}',
            );
            debugPrint(
              '[RoutesService] First leg from: ${firstLeg['from']}',
            );
            debugPrint(
              '[RoutesService] First leg to: ${firstLeg['to']}',
            );
          }
        }
      }

      final List<OtpItinerary> itineraries = <OtpItinerary>[];
      for (int i = 0; i < itinerariesJson.length; i++) {
        try {
          final OtpItinerary itinerary = OtpItinerary.fromJson(
            itinerariesJson[i] as Map<String, dynamic>,
          );
          itineraries.add(itinerary);
          debugPrint(
            '[RoutesService] Successfully parsed itinerary $i with '
            '${itinerary.legs.length} legs',
          );
        } catch (e, stackTrace) {
          debugPrint(
            '[RoutesService] Error parsing itinerary $i: $e',
          );
          debugPrint(
            '[RoutesService] Itinerary data: ${itinerariesJson[i]}',
          );
          debugPrint('[RoutesService] Stack: $stackTrace');
          // Continua a tentar os restantes itinerários.
        }
      }
      debugPrint(
        '[RoutesService] Successfully parsed ${itineraries.length} '
        'out of ${itinerariesJson.length} itineraries',
      );

      return PlannedRoutesResult(
        originalCount:
            decoded['originalItineraryCount'] as int? ?? itineraries.length,
        filteredCount:
            decoded['filteredItineraryCount'] as int? ?? itineraries.length,
        filterMode:
            decoded['filterApplied']?['filterMode'] as String? ?? 'ANY',
        maxWalkDistanceMeters:
            (decoded['filterApplied']?['maxWalkDistanceMeters'] as num?)
                ?.toDouble(),
        itineraries: itineraries,
      );
    } catch (e, stackTrace) {
      debugPrint('[RoutesService] Error: $e');
      debugPrint('[RoutesService] Stack trace: $stackTrace');
      rethrow;
    }
  }
}
