// lib/data/gbfs_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Disponibilidade agregada de uma estação GBFS.
class GbfsStationAvailability {
  final String id;
  final String name;
  final int? freeVehicles;
  final int? totalDocks;
  final String? address;
  final double? latitude;
  final double? longitude;

  GbfsStationAvailability({
    required this.id,
    required this.name,
    required this.freeVehicles,
    required this.totalDocks,
    this.address,
    this.latitude,
    this.longitude,
  });

  factory GbfsStationAvailability.fromJson(Map<String, dynamic> json) {
    final id = json['station_id']?.toString() ?? '';
    final name = (json['name'] ?? 'Estação $id') as String;

    int? asInt(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    double? asDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    // alguns sistemas usam bikes, outros vehicles
    final numBikes = asInt(json['num_bikes_available']);
    final numVehicles = asInt(json['num_vehicles_available']);
    final numDocks = asInt(json['num_docks_available']);
    final capacity = asInt(json['capacity']);

    final free = numBikes ?? numVehicles;
    final total = capacity ??
        ((numDocks != null && free != null) ? numDocks + free : null);

    final address = json['address'] as String?;
    final lat = asDouble(json['lat']);
    final lon = asDouble(json['lon']);

    return GbfsStationAvailability(
      id: id,
      name: name,
      freeVehicles: free,
      totalDocks: total ?? numDocks,
      address: address,
      latitude: lat,
      longitude: lon,
    );
  }
}

/// Veículo solto (free_bike_status)
class GbfsFreeBike {
  final String id;
  final double? latitude;
  final double? longitude;
  final String? vehicleTypeId;
  final bool? isReserved;
  final bool? isDisabled;

  GbfsFreeBike({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.vehicleTypeId,
    this.isReserved,
    this.isDisabled,
  });

  factory GbfsFreeBike.fromJson(Map<String, dynamic> json) {
    String pickId(Map<String, dynamic> j) {
      if (j['bike_id'] != null) return j['bike_id'].toString();
      if (j['vehicle_id'] != null) return j['vehicle_id'].toString();
      if (j['id'] != null) return j['id'].toString();
      if (j['name'] != null) return j['name'].toString();
      return 'unknown';
    }

    double? asDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return GbfsFreeBike(
      id: pickId(json),
      latitude: asDouble(json['lat']),
      longitude: asDouble(json['lon']),
      vehicleTypeId: json['vehicle_type_id'] as String?,
      isReserved: json['is_reserved'] as bool?,
      isDisabled: json['is_disabled'] as bool?,
    );
  }
}

/// Resposta do endpoint /gbfs/:systemId/availability
class GbfsAvailabilityResponse {
  final String systemId;
  final int lastUpdated;
  final int ttl;
  final List<GbfsStationAvailability> stations;
  final List<GbfsFreeBike> freeBikes;

  GbfsAvailabilityResponse({
    required this.systemId,
    required this.lastUpdated,
    required this.ttl,
    required this.stations,
    required this.freeBikes,
  });

  factory GbfsAvailabilityResponse.fromJson(Map<String, dynamic> json) {
    final systemId = json['system_id']?.toString() ?? '';
    final lastUpdated = json['last_updated'] as int? ?? 0;
    final ttl = json['ttl'] as int? ?? 60;

    final data = json['data'] as Map<String, dynamic>? ?? {};

    final stationsJson =
        (data['stations'] as List<dynamic>? ?? const []);
    final stations = stationsJson
        .map(
          (e) => GbfsStationAvailability.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    final freeBikesJson =
        (data['free_bikes'] as List<dynamic>? ?? const []);
    final freeBikes = freeBikesJson
        .map(
          (e) => GbfsFreeBike.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    return GbfsAvailabilityResponse(
      systemId: systemId,
      lastUpdated: lastUpdated,
      ttl: ttl,
      stations: stations,
      freeBikes: freeBikes,
    );
  }
}

/// Sistema GBFS guardado na BD (tabela gbfsSystem)
class GbfsSystem {
  final int id;
  final String systemId;
  final String name;
  final String? location;
  final String? countryCode;

  GbfsSystem({
    required this.id,
    required this.systemId,
    required this.name,
    required this.location,
    required this.countryCode,
  });

  factory GbfsSystem.fromJson(Map<String, dynamic> json) {
    return GbfsSystem(
      id: json['id'] as int,
      systemId: json['systemId'] as String,
      name: json['name'] as String,
      location: json['location'] as String?,
      countryCode: json['countryCode'] as String?,
    );
  }
}

/// Cliente para falar com o teu backend GBFS
class GbfsApiClient {
  /// Ajusta isto ao IP/porta do teu backend Nest
  final String baseUrl;

  const GbfsApiClient({
    this.baseUrl = 'http://192.168.1.244:3000',
  });

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse(baseUrl).replace(
      path: path,
      queryParameters: query?.map(
        (k, v) => MapEntry(k, v.toString()),
      ),
    );
  }

  /// GET /gbfs/systems
  Future<List<GbfsSystem>> listSystems() async {
    final uri = _uri('/gbfs/systems');
    final resp = await http.get(uri);

    if (resp.statusCode != 200) {
      throw Exception(
        'Failed to load GBFS systems: ${resp.statusCode}',
      );
    }

    final data = jsonDecode(resp.body) as List<dynamic>;
    return data
        .map(
          (e) => GbfsSystem.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  /// GET /gbfs/:systemId/availability?lang=pt
  Future<GbfsAvailabilityResponse> getAvailability(
    String systemId, {
    String? lang,
  }) async {
    final uri = _uri('/gbfs/$systemId/availability', {
      if (lang != null) 'lang': lang,
    });

    final resp = await http.get(uri);

    if (resp.statusCode != 200) {
      throw Exception(
        'Failed to load GBFS availability: ${resp.statusCode}',
      );
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return GbfsAvailabilityResponse.fromJson(data);
  }
}
