import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../mapbox_config.dart';
import 'mapbox_geocoding_service.dart' as geoc; // alias para evitar choque de nomes

// ---------------------- MODELOS ----------------------

class SearchboxPlace {
  final String id;
  final String name;
  final String placeName;
  final double longitude;
  final double latitude;
  final String? featureType;   // poi | address | street | place ...
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
      final f = v.first;
      return f is String ? f : f.toString();
    }
    return v.toString();
  }

  factory SearchboxSuggestion.fromJson(Map<String, dynamic> j) {
    final poi = (j['poi'] is Map) ? j['poi'] as Map : null;
    return SearchboxSuggestion(
      mapboxId: j['mapbox_id'] as String,
      name: _asString(j['name']) ?? _asString(j['feature_name']) ?? '',
      placeName: _asString(j['place_formatted']) ?? _asString(j['full_address']) ?? '',
      featureType: _asString(j['feature_type']),
      brand: _asString(poi?['brand']),
      category: _asString(poi?['category']),
    );
  }
}

// ---------------------- SERVICE ----------------------

class MapboxSearchBoxService {
  MapboxSearchBoxService._();
  static final MapboxSearchBoxService instance = MapboxSearchBoxService._();

  // === Verbose logging (liga/desliga globalmente) ===
  static bool verbose = false;

  // === Buffer do último erro/HTTP ===
  String? _lastEndpoint;
  int? _lastStatus;
  String? _lastError;      // descrição amigável (ex: timeout, parse, etc.)
  String? _lastBodyShort;  // primeiros ~300 chars do body
  Duration? _lastLatency;
  DateTime? _lastAt;

  Map<String, Object?> get lastDebug => {
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
      // guarda só um preview para não encher logs
      _lastBodyShort = body.length > 300 ? '${body.substring(0, 300)}…' : body;
    } else {
      _lastBodyShort = null;
    }

    if (verbose) {
      debugPrint('[SearchBox][HTTP] $_lastEndpoint');
      if (status != null) debugPrint('  status=$status (${_lastLatency?.inMilliseconds} ms)');
      if (error != null) debugPrint('  error=$error');
      if (_lastBodyShort != null) debugPrint('  body=$_lastBodyShort');
    }
  }

  static const _host = 'api.mapbox.com';
  static const _suggestPath  = '/search/searchbox/v1/suggest';
  static const _retrieveBase = '/search/searchbox/v1/retrieve'; // + '/{mapbox_id}'

  // ---------- HTTP util ----------
  static Future<http.Response?> _get(
    Uri uri, {
    int retries = 1,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    http.Response? res;
    final sw = Stopwatch()..start();
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
        await Future.delayed(const Duration(milliseconds: 150));
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
  static double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat/2)*math.sin(dLat/2) +
        math.cos(lat1*math.pi/180.0)*math.cos(lat2*math.pi/180.0) *
        math.sin(dLon/2)*math.sin(dLon/2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
    return r * c;
  }

  Future<(bool,String)> debugCheck({required double lon, required double lat}) async {
    final uri = Uri.https(_host, _suggestPath, {
      'q': 'cafe',
      'limit':'1',
      'proximity':'$lon,$lat',
      'origin':'$lon,$lat',
      'session_token':'debug_${DateTime.now().millisecondsSinceEpoch}',
      'access_token': kMapboxAccessToken,
    });
    final res = await _get(uri);
    if (res == null) return (false,'timeout');
    if (res.statusCode != 200) return (false,'${res.statusCode}: ${res.body}');
    return (true,'OK');
  }

  static int _clampLimit(int? limit) {
    final l = limit ?? 10;
    return l < 1 ? 1 : (l > 10 ? 10 : l);
  }

  // ---------- SUGGEST ----------
  Future<List<SearchboxSuggestion>> suggest(
    String query, {
    required String sessionToken,
    double? proximityLon, double? proximityLat,
    double? originLon, double? originLat,
    int? limit,
    String language = 'pt',
    String? countryIso2,
    List<String>? types,
  }) async {
    final q = query.trim();
    if (q.length < 2) return [];

    final params = <String,String>{
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

    final uri = Uri.https(_host, _suggestPath, params);
    if (verbose) debugPrint('[SearchBox][suggest] $params');
    final res = await _get(uri);
    if (res == null) {
      if (verbose) debugPrint('[SearchBox][suggest] -> null (timeout/rede)');
      return [];
    }
    if (res.statusCode != 200) {
      if (verbose) debugPrint('[SearchBox][suggest] HTTP ${res.statusCode}');
      return [];
    }

    try {
      final data = json.decode(res.body) as Map<String, dynamic>;
      final raw = (data['suggestions'] as List?) ?? const [];
      final out = raw
          .whereType<Map<String, dynamic>>()
          .map(SearchboxSuggestion.fromJson)
          .toList();
      if (verbose) debugPrint('[SearchBox][suggest] ok: ${out.length} sugestões');
      return out;
    } catch (e) {
      _setLast(uri: uri, error: 'parse error: $e', latency: _lastLatency);
      if (verbose) debugPrint('[SearchBox][suggest] parse error: $e');
      return [];
    }
  }

  static String? _s(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is List && v.isNotEmpty) {
      return v.first is String ? v.first : v.first.toString();
    }
    return v.toString();
  }

  // ---------- RETRIEVE (single) ----------
  Future<SearchboxPlace?> retrieve({
    required String mapboxId,
    required String sessionToken,
    String language = 'pt',
  }) async {
    final uri = Uri.https(
      _host,
      '$_retrieveBase/${Uri.encodeComponent(mapboxId)}',
      {
        'session_token': sessionToken,
        'language': language,
        'access_token': kMapboxAccessToken,
      },
    );
    if (verbose) debugPrint('[SearchBox][retrieve] id=$mapboxId');

    final res = await _get(uri);
    if (res == null) return null;
    if (res.statusCode != 200) {
      if (verbose) debugPrint('[SearchBox][retrieve] HTTP ${res.statusCode}');
      return null;
    }

    try {
      final data = json.decode(res.body) as Map<String, dynamic>;
      final feat = (data['features'] as List?)?.first as Map<String, dynamic>?;
      if (feat == null) return null;

      final coords =
          (feat['geometry']?['coordinates'] as List?)?.cast<num>() ?? const [0, 0];
      final props = (feat['properties'] as Map?) ?? const {};
      final namePreferred = _s(props['name_preferred']) ?? _s(feat['text']) ?? '';
      final placeFormatted =
          _s(props['place_formatted']) ?? _s(feat['place_name']) ?? '';

      final p = SearchboxPlace(
        id: _s(props['mapbox_id']) ?? _s(props['id']) ?? mapboxId,
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
      _setLast(uri: uri, error: 'parse error: $e', latency: _lastLatency);
      if (verbose) debugPrint('[SearchBox][retrieve] parse error: $e');
      return null;
    }
  }

  // ---------- RETRIEVE MANY (parallel) ----------
  Future<Map<String, SearchboxPlace>> retrieveManyParallel({
    required List<String> mapboxIds,
    required String sessionToken,
    String language = 'pt',
  }) async {
    if (verbose) debugPrint('[SearchBox][retrieveMany] ids=${mapboxIds.length}');
    final futures = mapboxIds.map((id) async {
      final p = await retrieve(
        mapboxId: id,
        sessionToken: sessionToken,
        language: language,
      );
      return MapEntry(id, p);
    }).toList();

    final results = await Future.wait(futures, eagerError: false);
    final out = <String, SearchboxPlace>{};
    for (final kv in results) {
      final p = kv.value;
      if (p != null) out[kv.key] = p;
    }
    if (verbose) debugPrint('[SearchBox][retrieveMany] ok=${out.length}');
    return out;
  }

  /// Nearby misto (POIs + ruas) via Search Box; intercala e ordena por distância.
  Future<List<SearchboxPlace>> nearbyMixed({
    required double lon,
    required double lat,
    required String sessionToken,
    String language = 'pt',
    String? countryIso2,
    int total = 10,
  }) async {
    final safeTotal = total.clamp(1, 10);
    if (verbose) debugPrint('[SearchBox][nearbyMixed] @($lat,$lon) total=$safeTotal');

    // Heurística: duas queries curtas e locais
    final pois = await suggest(
      'cafe',
      sessionToken: sessionToken,
      proximityLon: lon,
      proximityLat: lat,
      originLon: lon,
      originLat: lat,
      limit: safeTotal,
      language: language,
      countryIso2: countryIso2,
      types: const ['poi'],
    );

    final streets = await suggest(
      'rua',
      sessionToken: sessionToken,
      proximityLon: lon,
      proximityLat: lat,
      originLon: lon,
      originLat: lat,
      limit: safeTotal,
      language: language,
      countryIso2: countryIso2,
      types: const ['street'],
    );

    if (pois.isEmpty && streets.isEmpty) {
      if (verbose) debugPrint('[SearchBox][nearbyMixed] vazio (pois+streets)');
      return [];
    }

    // Intercalar resultados
    final merged = <SearchboxSuggestion>[];
    final itA = pois.iterator, itB = streets.iterator;
    while (merged.length < safeTotal && (itA.moveNext() || itB.moveNext())) {
      if (merged.length < safeTotal) merged.add(itA.current);
      if (merged.length < safeTotal) merged.add(itB.current);
    }
    if (merged.length < safeTotal) {
      merged.addAll(pois.skip(merged.length));
      if (merged.length > safeTotal) merged.removeRange(safeTotal, merged.length);
    }

    final retrieved = await retrieveManyParallel(
      mapboxIds: merged.map((s) => s.mapboxId).toList(),
      sessionToken: sessionToken,
      language: language,
    );

    final list = retrieved.values
        .map(
          (f) => f.copyWith(
            distanceMeters: haversineMeters(lat, lon, f.latitude, f.longitude),
          ),
        )
        .toList()
      ..sort((a, b) => (a.distanceMeters ?? 9e9).compareTo(b.distanceMeters ?? 9e9));

    // dedupe por id
    final seen = <String>{};
    final out = list.where((f) => seen.add(f.id)).take(safeTotal).toList();
    if (verbose) debugPrint('[SearchBox][nearbyMixed] ok=${out.length}');
    return out;
  }

  /// Tenta Search Box; se vier vazio, fallback com Geocoding (POIs + "Rua").
  Future<List<SearchboxPlace>> nearbyMixedWithFallback({
    required double lon,
    required double lat,
    required String sessionToken,
    String language = 'pt',
    String? countryIso2,
    int total = 12,
  }) async {
    if (verbose) debugPrint('[SearchBox][nearbyMixedWithFallback] start');
    // 1) primeiro: tentar o Search Box normal
    final sb = await nearbyMixed(
      lon: lon,
      lat: lat,
      sessionToken: sessionToken,
      language: language,
      countryIso2: countryIso2,
      total: total.clamp(1, 12),
    );
    if (sb.isNotEmpty) {
      if (verbose) debugPrint('[SearchBox][nearbyMixedWithFallback] got from SearchBox');
      return sb;
    }

    // 2) fallback: Geocoding — POIs por categorias e ruas com bbox pequeno
    if (verbose) debugPrint('[SearchBox][nearbyMixedWithFallback] using Geocoding fallback');
    final geocodingPOIs = await geoc.MapboxGeocodingService.instance.nearbyPOIs(
      lon: lon,
      lat: lat,
      language: language,
      countryIso2: countryIso2,
      limit: total * 2,
    );

    final geocodingStreets =
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
      final feat = (m.placeTypes.contains('poi') ||
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
        distanceMeters:
            MapboxSearchBoxService.haversineMeters(lat, lon, m.latitude, m.longitude),
      );
    }

    final merged = <SearchboxPlace>[
      ...geocodingPOIs.map(toSB),
      ...geocodingStreets.map(toSB),
    ];

    // dedupe por id e ordenar por distância
    final seen = <String>{};
    final out = merged.where((p) => seen.add(p.id)).toList()
      ..sort(
        (a, b) => (a.distanceMeters ?? 9e9).compareTo(b.distanceMeters ?? 9e9),
      );

    if (verbose) debugPrint('[SearchBox][nearbyMixedWithFallback] geoc out=${out.length}');
    return out.take(total).toList();
  }
}
