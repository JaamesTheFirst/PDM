import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../mapbox_config.dart';
import 'mapbox_geocoding_service.dart' as geoc;

/// Lugar simplificado usado no frontend (SearchBox ou fallback).
class SearchboxPlace {
  final String id;
  final String name;
  final String placeName;
  final double longitude;
  final double latitude;
  final String? featureType; // poi | address | street | place ...
  final String? category;
  final double? distanceMeters;

  const SearchboxPlace({
    required this.id,
    required this.name,
    required this.placeName,
    required this.longitude,
    required this.latitude,
    this.featureType,
    this.category,
    this.distanceMeters,
  });

  /// Cópia com novo [distanceMeters].
  SearchboxPlace copyWith({double? distanceMeters}) => SearchboxPlace(
        id: id,
        name: name,
        placeName: placeName,
        longitude: longitude,
        latitude: latitude,
        featureType: featureType,
        category: category,
        distanceMeters: distanceMeters ?? this.distanceMeters,
      );
}

/// Sugestão devolvida pelo endpoint `/searchbox/v1/suggest`.
class SearchboxSuggestion {
  final String mapboxId;
  final String name;
  final String placeName;
  final String? featureType;
  final String? brand;
  final String? category;

  SearchboxSuggestion({
    required this.mapboxId,
    required this.name,
    required this.placeName,
    this.featureType,
    this.brand,
    this.category,
  });

  static String? _asString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is List && v.isNotEmpty) {
      final dynamic f = v.first;
      return f is String ? f : f.toString();
    }
    return v.toString();
  }

  /// Cria [SearchboxSuggestion] a partir do JSON do Search Box.
  factory SearchboxSuggestion.fromJson(Map<String, dynamic> j) {
    final Map<dynamic, dynamic>? poi =
        (j['poi'] is Map) ? j['poi'] as Map<dynamic, dynamic> : null;
    return SearchboxSuggestion(
      mapboxId: j['mapbox_id'] as String,
      name: _asString(j['name']) ??
          _asString(j['feature_name']) ??
          '',
      placeName: _asString(j['place_formatted']) ??
          _asString(j['full_address']) ??
          '',
      featureType: _asString(j['feature_type']),
      brand: _asString(poi?['brand']),
      category: _asString(poi?['category']),
    );
  }
}

/// Serviço para consumir a API Mapbox Search Box.
///
/// Funciona em três níveis:
/// 1. `suggest` / `retrieve` para search-as-you-type.
/// 2. `nearbyMixed` para POIs + ruas intermistas.
/// 3. `nearbyMixedWithFallback` que faz fallback para Geocoding
///    clássico quando o Search Box não devolver nada.
class MapboxSearchBoxService {
  MapboxSearchBoxService._();

  /// Instância singleton do [MapboxSearchBoxService].
  static final MapboxSearchBoxService instance =
      MapboxSearchBoxService._();

  /// Activa logs verbosos em todos os métodos.
  static bool verbose = false;

  // === Buffer do último erro/HTTP ===
  String? _lastEndpoint;
  int? _lastStatus;
  String? _lastError; // descrição amigável
  String? _lastBodyShort; // preview do body
  Duration? _lastLatency;
  DateTime? _lastAt;

  /// Último estado de debug de chamadas HTTP do serviço.
  Map<String, Object?> get lastDebug => <String, Object?>{
        'endpoint': _lastEndpoint,
        'status': _lastStatus,
        'error': _lastError,
        'latency_ms': _lastLatency?.inMilliseconds,
        'when': _lastAt?.toIso8601String(),
        'body_preview': _lastBodyShort,
      };

  void _setLast({
    required Uri uri,
    int? status,
    String? error,
    String? body,
    Duration? latency,
  }) {
    _lastEndpoint = uri.toString();
    _lastStatus = status;
    _lastError = error;
    _lastLatency = latency;
    _lastAt = DateTime.now();
    if (body != null) {
      _lastBodyShort =
          body.length > 300 ? '${body.substring(0, 300)}…' : body;
    } else {
      _lastBodyShort = null;
    }

    if (verbose) {
      debugPrint('[SearchBox][HTTP] $_lastEndpoint');
      if (status != null) {
        debugPrint(
          '  status=$status (${_lastLatency?.inMilliseconds} ms)',
        );
      }
      if (error != null) debugPrint('  error=$error');
      if (_lastBodyShort != null) {
        debugPrint('  body=$_lastBodyShort');
      }
    }
  }

  static const String _host = 'api.mapbox.com';
  static const String _suggestPath = '/search/searchbox/v1/suggest';
  static const String _retrieveBase = '/search/searchbox/v1/retrieve';

  // ---------- HTTP util ----------

  /// Pequeno helper para GET com timeout e retry,
  /// registando o resultado em [_setLast].
  static Future<http.Response?> _get(
    Uri uri, {
    int retries = 1,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    http.Response? res;
    final Stopwatch sw = Stopwatch()..start();
    for (int i = 0; i <= retries; i++) {
      try {
        res = await http.get(uri).timeout(timeout);
        break;
      } catch (e) {
        if (i == retries) {
          instance._setLast(
            uri: uri,
            error: 'timeout/network: $e',
            latency: sw.elapsed,
          );
          return null;
        }
        await Future<Duration>.delayed(
          const Duration(milliseconds: 150),
        );
      }
    }
    instance._setLast(
      uri: uri,
      status: res?.statusCode,
      body: res?.body,
      latency: sw.elapsed,
    );
    return res;
  }

  // ---------- geo util ----------

  /// Haversine em metros.
  static double haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double r = 6371000.0;
    final double dLat = (lat2 - lat1) * math.pi / 180.0;
    final double dLon = (lon2 - lon1) * math.pi / 180.0;
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  /// Chamada de debug para validar se o Search Box está acessível.
  Future<(bool, String)> debugCheck({
    required double lon,
    required double lat,
  }) async {
    final Uri uri = Uri.https(_host, _suggestPath, <String, String>{
      'q': 'cafe',
      'limit': '1',
      'proximity': '$lon,$lat',
      'origin': '$lon,$lat',
      'session_token':
          'debug_${DateTime.now().millisecondsSinceEpoch}',
      'access_token': kMapboxAccessToken,
    });
    final http.Response? res = await _get(uri);
    if (res == null) return (false, 'timeout');
    if (res.statusCode != 200) {
      return (false, '${res.statusCode}: ${res.body}');
    }
    return (true, 'OK');
  }

  static int _clampLimit(int? limit) {
    final int l = limit ?? 10;
    return l < 1
        ? 1
        : (l > 10)
            ? 10
            : l;
  }

  // ---------- SUGGEST ----------

  /// Sugestões de pesquisa via Search Box.
  ///
  /// - [query] texto digitado pelo utilizador.
  /// - [sessionToken] deve ser reutilizado durante uma sessão de pesquisa.
  /// - [proximity*] e [origin*] ajudam a priorizar resultados perto.
  Future<List<SearchboxSuggestion>> suggest(
    String query, {
    required String sessionToken,
    double? proximityLon,
    double? proximityLat,
    double? originLon,
    double? originLat,
    int? limit,
    String language = 'pt',
    String? countryIso2,
    List<String>? types,
  }) async {
    final String q = query.trim();
    if (q.length < 2) return <SearchboxSuggestion>[];

    final Map<String, String> params = <String, String>{
      'q': q,
      'limit': '${_clampLimit(limit)}',
      'language': language,
      'session_token': sessionToken,
      'access_token': kMapboxAccessToken,
    };
    if (proximityLon != null && proximityLat != null) {
      params['proximity'] = '$proximityLon,$proximityLat';
    }
    if (originLon != null && originLat != null) {
      params['origin'] = '$originLon,$originLat';
    }
    if (countryIso2 != null && countryIso2.isNotEmpty) {
      params['country'] = countryIso2;
    }
    if (types != null && types.isNotEmpty) {
      params['types'] = types.join(',');
    }

    final Uri uri = Uri.https(_host, _suggestPath, params);
    if (verbose) debugPrint('[SearchBox][suggest] $params');
    final http.Response? res = await _get(uri);
    if (res == null) {
      if (verbose) {
        debugPrint(
          '[SearchBox][suggest] -> null (timeout/rede)',
        );
      }
      return <SearchboxSuggestion>[];
    }
    if (res.statusCode != 200) {
      if (verbose) {
        debugPrint(
          '[SearchBox][suggest] HTTP ${res.statusCode}',
        );
      }
      return <SearchboxSuggestion>[];
    }

    try {
      final Map<String, dynamic> data =
          jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> raw =
          (data['suggestions'] as List?) ?? const <dynamic>[];
      final List<SearchboxSuggestion> out = raw
          .whereType<Map<String, dynamic>>()
          .map<SearchboxSuggestion>(SearchboxSuggestion.fromJson)
          .toList();
      if (verbose) {
        debugPrint(
          '[SearchBox][suggest] ok: ${out.length} sugestões',
        );
      }
      return out;
    } catch (e) {
      instance._setLast(
        uri: uri,
        error: 'parse error: $e',
        latency: instance._lastLatency,
      );
      if (verbose) {
        debugPrint('[SearchBox][suggest] parse error: $e');
      }
      return <SearchboxSuggestion>[];
    }
  }

  static String? _s(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is List && v.isNotEmpty) {
      return v.first is String ? v.first as String : v.first.toString();
    }
    return v.toString();
  }

  // ---------- RETRIEVE (single) ----------

  /// Recupera detalhes completos de um lugar a partir de um [mapboxId].
  Future<SearchboxPlace?> retrieve({
    required String mapboxId,
    required String sessionToken,
    String language = 'pt',
  }) async {
    final Uri uri = Uri.https(
      _host,
      '$_retrieveBase/${Uri.encodeComponent(mapboxId)}',
      <String, String>{
        'session_token': sessionToken,
        'language': language,
        'access_token': kMapboxAccessToken,
      },
    );
    if (verbose) debugPrint('[SearchBox][retrieve] id=$mapboxId');

    final http.Response? res = await _get(uri);
    if (res == null) return null;
    if (res.statusCode != 200) {
      if (verbose) {
        debugPrint(
          '[SearchBox][retrieve] HTTP ${res.statusCode}',
        );
      }
      return null;
    }

    try {
      final Map<String, dynamic> data =
          jsonDecode(res.body) as Map<String, dynamic>;
      final Map<String, dynamic>? feat =
          (data['features'] as List?)
              ?.first as Map<String, dynamic>?;
      if (feat == null) return null;

      final List<num> coords =
          (feat['geometry']?['coordinates'] as List?)?.cast<num>() ??
              <num>[0, 0];
      final Map<dynamic, dynamic> props =
          (feat['properties'] as Map?) ?? const <dynamic, dynamic>{};

      final String namePreferred =
          _s(props['name_preferred']) ?? _s(feat['text']) ?? '';
      final String placeFormatted =
          _s(props['place_formatted']) ??
              _s(feat['place_name']) ??
              '';

      final SearchboxPlace p = SearchboxPlace(
        id: _s(props['mapbox_id']) ??
            _s(props['id']) ??
            mapboxId,
        name: namePreferred,
        placeName: placeFormatted,
        longitude: coords.isNotEmpty ? coords[0].toDouble() : 0.0,
        latitude: coords.length > 1 ? coords[1].toDouble() : 0.0,
        featureType: _s(props['feature_type']),
        category: _s(props['poi_category']) ?? _s(props['maki']),
      );
      if (verbose) debugPrint('[SearchBox][retrieve] ok');
      return p;
    } catch (e) {
      instance._setLast(
        uri: uri,
        error: 'parse error: $e',
        latency: instance._lastLatency,
      );
      if (verbose) {
        debugPrint('[SearchBox][retrieve] parse error: $e');
      }
      return null;
    }
  }

  // ---------- RETRIEVE MANY (parallel) ----------

  /// Faz retrieve em paralelo para vários [mapboxIds] e devolve um mapa
  /// `id -> SearchboxPlace` apenas com os que foram encontrados.
  Future<Map<String, SearchboxPlace>> retrieveManyParallel({
    required List<String> mapboxIds,
    required String sessionToken,
    String language = 'pt',
  }) async {
    if (verbose) {
      debugPrint(
        '[SearchBox][retrieveMany] ids=${mapboxIds.length}',
      );
    }
    final List<Future<MapEntry<String, SearchboxPlace?>>> futures =
        mapboxIds
            .map((String id) async {
              final SearchboxPlace? p = await retrieve(
                mapboxId: id,
                sessionToken: sessionToken,
                language: language,
              );
              return MapEntry<String, SearchboxPlace?>(id, p);
            })
            .toList();

    final List<MapEntry<String, SearchboxPlace?>> results =
        await Future.wait(
      futures,
      eagerError: false,
    );
    final Map<String, SearchboxPlace> out =
        <String, SearchboxPlace>{};
    for (final MapEntry<String, SearchboxPlace?> kv in results) {
      final SearchboxPlace? p = kv.value;
      if (p != null) out[kv.key] = p;
    }
    if (verbose) {
      debugPrint(
        '[SearchBox][retrieveMany] ok=${out.length}',
      );
    }
    return out;
  }

  /// Nearby misto (POIs + ruas) via Search Box; intercala resultados e
  /// ordena por distância ao ponto [lon], [lat].
  Future<List<SearchboxPlace>> nearbyMixed({
    required double lon,
    required double lat,
    required String sessionToken,
    String language = 'pt',
    String? countryIso2,
    int total = 10,
  }) async {
    final int safeTotal = total.clamp(1, 10);
    if (verbose) {
      debugPrint(
        '[SearchBox][nearbyMixed] @($lat,$lon) total=$safeTotal',
      );
    }

    // Duas queries curtas e locais: POIs e ruas.
    final List<SearchboxSuggestion> pois = await suggest(
      'cafe',
      sessionToken: sessionToken,
      proximityLon: lon,
      proximityLat: lat,
      originLon: lon,
      originLat: lat,
      limit: safeTotal,
      language: language,
      countryIso2: countryIso2,
      types: const <String>['poi'],
    );

    final List<SearchboxSuggestion> streets = await suggest(
      'rua',
      sessionToken: sessionToken,
      proximityLon: lon,
      proximityLat: lat,
      originLon: lon,
      originLat: lat,
      limit: safeTotal,
      language: language,
      countryIso2: countryIso2,
      types: const <String>['street'],
    );

    if (pois.isEmpty && streets.isEmpty) {
      if (verbose) {
        debugPrint(
          '[SearchBox][nearbyMixed] vazio (pois+streets)',
        );
      }
      return <SearchboxPlace>[];
    }

    // Intercalar resultados.
    final List<SearchboxSuggestion> merged =
        <SearchboxSuggestion>[];
    final Iterator<SearchboxSuggestion> itA = pois.iterator;
    final Iterator<SearchboxSuggestion> itB = streets.iterator;
    while (merged.length < safeTotal &&
        (itA.moveNext() || itB.moveNext())) {
      if (merged.length < safeTotal) merged.add(itA.current);
      if (merged.length < safeTotal) merged.add(itB.current);
    }
    if (merged.length < safeTotal) {
      merged.addAll(pois.skip(merged.length));
      if (merged.length > safeTotal) {
        merged.removeRange(safeTotal, merged.length);
      }
    }

    final Map<String, SearchboxPlace> retrieved =
        await retrieveManyParallel(
      mapboxIds: merged.map((SearchboxSuggestion s) => s.mapboxId).toList(),
      sessionToken: sessionToken,
      language: language,
    );

    final List<SearchboxPlace> list = retrieved.values
        .map(
          (SearchboxPlace f) => f.copyWith(
            distanceMeters: haversineMeters(
              lat,
              lon,
              f.latitude,
              f.longitude,
            ),
          ),
        )
        .toList()
      ..sort(
        (SearchboxPlace a, SearchboxPlace b) =>
            (a.distanceMeters ?? 9e9)
                .compareTo(b.distanceMeters ?? 9e9),
      );

    // dedupe por id
    final Set<String> seen = <String>{};
    final List<SearchboxPlace> out =
        list.where((SearchboxPlace f) => seen.add(f.id)).take(safeTotal).toList();
    if (verbose) {
      debugPrint(
        '[SearchBox][nearbyMixed] ok=${out.length}',
      );
    }
    return out;
  }

  /// Tenta Search Box; se não houver resultados, faz fallback para Geocoding
  /// clássico (POIs + ruas) e devolve até [total] lugares.
  Future<List<SearchboxPlace>> nearbyMixedWithFallback({
    required double lon,
    required double lat,
    required String sessionToken,
    String language = 'pt',
    String? countryIso2,
    int total = 12,
  }) async {
    if (verbose) {
      debugPrint(
        '[SearchBox][nearbyMixedWithFallback] start',
      );
    }
    // 1) primeiro: tentar o Search Box normal
    final List<SearchboxPlace> sb = await nearbyMixed(
      lon: lon,
      lat: lat,
      sessionToken: sessionToken,
      language: language,
      countryIso2: countryIso2,
      total: total.clamp(1, 12),
    );
    if (sb.isNotEmpty) {
      if (verbose) {
        debugPrint(
          '[SearchBox][nearbyMixedWithFallback] got from SearchBox',
        );
      }
      return sb;
    }

    // 2) fallback: Geocoding — POIs por categorias e ruas com bbox
    if (verbose) {
      debugPrint(
        '[SearchBox][nearbyMixedWithFallback] using Geocoding fallback',
      );
    }
    final List<geoc.MapboxPlace> geocodingPOIs =
        await geoc.MapboxGeocodingService.instance.nearbyPOIs(
      lon: lon,
      lat: lat,
      language: language,
      countryIso2: countryIso2,
      limit: total * 2,
    );

    final List<geoc.MapboxPlace> geocodingStreets =
        await geoc.MapboxGeocodingService.instance.searchPlaces(
      'Rua',
      limit: total,
      language: language,
      countryIso2: countryIso2,
      proximityLon: lon,
      proximityLat: lat,
      bboxRadiusKm: 5,
    );

    // converter geoc.MapboxPlace -> SearchboxPlace
    SearchboxPlace toSB(geoc.MapboxPlace m) {
      final String feat = (m.placeTypes.contains('poi') ||
              m.placeTypes.contains('poi.landmark'))
          ? 'poi'
          : (m.placeTypes.contains('address') ? 'address' : 'place');
      return SearchboxPlace(
        id: m.id.isNotEmpty ? m.id : '${m.longitude},${m.latitude}',
        name: m.name,
        placeName: m.placeName,
        longitude: m.longitude,
        latitude: m.latitude,
        featureType: feat,
        category: m.category,
        distanceMeters: haversineMeters(
          lat,
          lon,
          m.latitude,
          m.longitude,
        ),
      );
    }

    final List<SearchboxPlace> merged = <SearchboxPlace>[
      ...geocodingPOIs.map<SearchboxPlace>(toSB),
      ...geocodingStreets.map<SearchboxPlace>(toSB),
    ];

    // dedupe por id e ordenar por distância
    final Set<String> seen = <String>{};
    final List<SearchboxPlace> out =
        merged.where((SearchboxPlace p) => seen.add(p.id)).toList()
          ..sort(
            (SearchboxPlace a, SearchboxPlace b) =>
                (a.distanceMeters ?? 9e9)
                    .compareTo(b.distanceMeters ?? 9e9),
          );

    if (verbose) {
      debugPrint(
        '[SearchBox][nearbyMixedWithFallback] geoc out=${out.length}',
      );
    }
    return out.take(total).toList();
  }
}
