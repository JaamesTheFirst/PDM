// lib/services/api_client.dart
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

// 1) Mock OFF por defeito (podes voltar a ligar com --dart-define=USE_MOCK=true)
const bool kUseMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

// 2) BASE_URL opcional por env; se vier vazio, escolhemos um default conforme a plataforma
const String _envBase = String.fromEnvironment('BASE_URL', defaultValue: '');

String _computeDefaultBase() {
  // Web/desktop/iOS simulador => localhost
  if (kIsWeb) return 'http://localhost:3000';
  try {
    if (Platform.isAndroid) {
      // For Android emulator, use 10.0.2.2 which maps to localhost on your machine
      // For physical Android device, use your machine's IP address
      // You can override by setting BASE_URL environment variable:
      // flutter run --dart-define=BASE_URL=http://YOUR_IP:3000
      const String customUrl = String.fromEnvironment('BASE_URL');
      if (customUrl.isNotEmpty) return customUrl;
      
      // Default: use 10.0.2.2 for emulator
      // For physical device, each dev should set their IP via --dart-define or update this line
      // Note: For physical devices, you'll need to use your Windows IP (e.g., 172.29.251.201)
      return 'http://192.168.1.114:3000';
    }
  } catch (_) {
    // Platform não existe no web; ignorar
  }
  return 'http://localhost:3000';
}

final String kBaseUrl = _envBase.isNotEmpty ? _envBase : _computeDefaultBase();

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    final uri = Uri.parse('$kBaseUrl$path');
    return http.get(uri, headers: {
      'Accept': 'application/json',
      if (headers != null) ...headers,
    });
  }

  Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final uri = Uri.parse('$kBaseUrl$path');
    return http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (headers != null) ...headers,
      },
      body: body,
    );
  }
}
