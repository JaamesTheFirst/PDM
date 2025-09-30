import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _storage = const FlutterSecureStorage();

  Future<bool> login(String email, String password) async {
    final res = await ApiClient.instance.post(
      '/auth/login',
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (res.statusCode == 200) {
      final token = (jsonDecode(res.body)['access_token'] as String?) ?? '';
      if (token.isEmpty) return false;
      await _storage.write(key: 'token', value: token);
      return true;
    }
    return false;
  }

  Future<void> logout() async => _storage.delete(key: 'token');

  Future<String?> getToken() async => _storage.read(key: 'token');

  /// Exemplo de chamada autenticada (quando existir no backend).
  Future<http.Response> me() async {
    final token = await getToken();
    return ApiClient.instance.get('/users/me', headers: {
      if (token != null) 'Authorization': 'Bearer $token',
    });
  }
}
