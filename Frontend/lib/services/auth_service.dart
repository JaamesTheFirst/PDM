import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _storage = const FlutterSecureStorage();

  Future<bool> login({required String identifier, required String password}) async {
    final res = await ApiClient.instance.post(
      '/auth/login',
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );
    return _saveTokenIfOk(res);
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final res = await ApiClient.instance.post(
      '/auth/register',
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        if (firstName != null && firstName.isNotEmpty) 'firstName': firstName,
        if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
      }),
    );
    return _saveTokenIfOk(res);
  }

  Future<bool> _saveTokenIfOk(http.Response res) async {
    if (res.statusCode == 200 || res.statusCode == 201) {
      final token = (jsonDecode(res.body)['access_token'] as String?) ?? '';
      if (token.isEmpty) {
        print('[AuthService] Login response missing access_token');
        return false;
      }
      await _storage.write(key: 'token', value: token);
      print('[AuthService] Token saved successfully (length: ${token.length})');
      // Verify it was saved
      final saved = await _storage.read(key: 'token');
      print('[AuthService] Token verification: ${saved != null ? "OK" : "FAILED"}');
      return true;
    }
    print('[AuthService] Login failed with status: ${res.statusCode}');
    return false;
  }

  Future<void> logout() async => _storage.delete(key: 'token');

  Future<String?> getToken() async {
    final token = await _storage.read(key: 'token');
    print('[AuthService] getToken() called, result: ${token != null ? "token found (length: ${token.length})" : "null"}');
    return token;
  }

  Future<http.Response> me() async {
    final token = await getToken();
    return ApiClient.instance.get('/auth/me', headers: {
      if (token != null) 'Authorization': 'Bearer $token',
    });
  }

  Future<bool> isLoggedIn() async => (await getToken()) != null;
}
