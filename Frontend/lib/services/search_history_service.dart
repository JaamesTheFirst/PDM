import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Entrada de histórico de pesquisas (destino pesquisado).
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

  /// Converte para JSON serializável.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'address': address,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Cria [SearchDestination] a partir de JSON guardado localmente.
  factory SearchDestination.fromJson(Map<String, dynamic> json) =>
      SearchDestination(
        address: json['address'] as String,
        name: json['name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

/// Serviço para guardar e ler histórico de pesquisas em storage segura.
///
/// Implementa uma “queue” de destinos recentes (tamanho máximo 20).
class SearchHistoryService {
  SearchHistoryService._();

  /// Instância singleton do [SearchHistoryService].
  static final SearchHistoryService instance = SearchHistoryService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _key = 'search_history';
  static const int _maxSize = 20;

  /// Adiciona um destino à fila de histórico.
  ///
  /// - Remove entradas duplicadas (mesma morada ou mesmas coordenadas).
  /// - Insere o novo destino no início da lista.
  /// - Garante que só existem [_maxSize] items guardados.
  Future<void> addDestination({
    required String address,
    required String name,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final List<SearchDestination> history = await getHistory();

      // Remove duplicados
      history.removeWhere(
        (SearchDestination item) =>
            item.address == address ||
            (item.latitude == latitude && item.longitude == longitude),
      );

      // Novo destino no topo
      history.insert(
        0,
        SearchDestination(
          address: address,
          name: name,
          latitude: latitude,
          longitude: longitude,
          timestamp: DateTime.now(),
        ),
      );

      // Apenas os últimos _maxSize.
      if (history.length > _maxSize) {
        history.removeRange(_maxSize, history.length);
      }

      final List<Map<String, dynamic>> jsonList =
          history.map((SearchDestination item) => item.toJson()).toList();
      await _storage.write(
        key: _key,
        value: jsonEncode(jsonList),
      );

      debugPrint('[SearchHistoryService] Added destination: $name');
    } catch (e) {
      debugPrint('[SearchHistoryService] Error adding destination: $e');
    }
  }

  /// Lê o histórico de destinos (mais recente primeiro).
  Future<List<SearchDestination>> getHistory() async {
    try {
      final String? jsonString = await _storage.read(key: _key);
      if (jsonString == null || jsonString.isEmpty) {
        return <SearchDestination>[];
      }

      final List<dynamic> jsonList =
          jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map<SearchDestination>(
            (dynamic e) =>
                SearchDestination.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('[SearchHistoryService] Error reading history: $e');
      return <SearchDestination>[];
    }
  }

  /// Apaga todo o histórico de pesquisas.
  Future<void> clear() async {
    await _storage.delete(key: _key);
    debugPrint('[SearchHistoryService] History cleared');
  }
}
