import 'dart:convert';
import 'package:http/http.dart' as http;

const bool kUseMock = bool.fromEnvironment('USE_MOCK', defaultValue: true);
const String kBaseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'http://localhost:3000', // Android: usa 10.0.2.2
);

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    if (kUseMock && path == '/health') {
      final body = jsonEncode({
        'status': 'ok',
        'uptime': 123.45,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'source': 'mock',
      });
      return http.Response(body, 200, headers: {'content-type': 'application/json'});
    }

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
    if (kUseMock && path == '/auth/login') {
      final ok = body.toString().contains('"password":"123456"');
      if (ok) {
        return http.Response(
          jsonEncode({'access_token': 'MOCK.JWT.TOKEN'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'statusCode': 401, 'message': 'Unauthorized'}),
        401,
        headers: {'content-type': 'application/json'},
      );
    }

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
