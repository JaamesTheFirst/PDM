import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SearchDestination {
  final String address;
  final String name;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  SearchDestination({
    required this.address,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'address': address,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SearchDestination.fromJson(Map<String, dynamic> json) =>
      SearchDestination(
        address: json['address'] as String,
        name: json['name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class SearchHistoryService {
  SearchHistoryService._();
  static final SearchHistoryService instance = SearchHistoryService._();

  final _storage = const FlutterSecureStorage();
  static const String _key = 'search_history';
  static const int _maxSize = 20;

  /// Add a destination to the search history queue
  Future<void> addDestination({
    required String address,
    required String name,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final history = await getHistory();
      
      // Remove duplicates (same address)
      history.removeWhere((item) => 
        item.address == address || 
        (item.latitude == latitude && item.longitude == longitude)
      );

      // Add new destination at the beginning
      history.insert(0, SearchDestination(
        address: address,
        name: name,
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
      ));

      // Keep only the last 20 items
      if (history.length > _maxSize) {
        history.removeRange(_maxSize, history.length);
      }

      // Save to storage
      final jsonList = history.map((item) => item.toJson()).toList();
      await _storage.write(key: _key, value: jsonEncode(jsonList));
      
      print('[SearchHistoryService] Added destination: $name');
    } catch (e) {
      print('[SearchHistoryService] Error adding destination: $e');
    }
  }

  /// Get the search history queue (most recent first)
  Future<List<SearchDestination>> getHistory() async {
    try {
      final jsonString = await _storage.read(key: _key);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((e) => SearchDestination.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[SearchHistoryService] Error reading history: $e');
      return [];
    }
  }

  /// Clear all search history
  Future<void> clear() async {
    await _storage.delete(key: _key);
    print('[SearchHistoryService] History cleared');
  }
}

