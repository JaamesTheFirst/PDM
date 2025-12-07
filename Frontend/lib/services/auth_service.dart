import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _storage = const FlutterSecureStorage();

  /// LOGIN
  ///
  /// Envia:
  /// {
  ///   "identifier": "<email-ou-username>",
  ///   "password": "<password>"
  /// }
  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    final body = {
      'identifier': identifier,
      'password': password,
    };

    print(
        '[AuthService] LOGIN request → path=/auth/login body=${{
          'identifier': identifier,
          'passwordLength': password.length,
        }}');

    late http.Response res;
    try {
      res = await ApiClient.instance.post(
        '/auth/login',
        body: jsonEncode(body),
      );
    } catch (e) {
      print('[AuthService] LOGIN network error: $e');
      return false;
    }

    print(
        '[AuthService] LOGIN response ← status=${res.statusCode}, body=${res.body}');

    return _saveTokenIfOk(res, context: 'LOGIN');
  }

  /// REGISTO
  ///
  /// Envia:
  /// {
  ///   "username": "...",
  ///   "email": "...",
  ///   "password": "...",
  ///   "firstName": "...", // opcional
  ///   "lastName": "..."   // opcional
  /// }
  Future<bool> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final body = <String, dynamic>{
      'username': username,
      'email': email,
      'password': password,
      if (firstName != null && firstName.isNotEmpty) 'firstName': firstName,
      if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
    };

    print(
        '[AuthService] REGISTER request → path=/auth/register body=${{
          'username': username,
          'email': email,
          'passwordLength': password.length,
          'hasFirstName': firstName != null && firstName.isNotEmpty,
          'hasLastName': lastName != null && lastName.isNotEmpty,
        }}');

    late http.Response res;
    try {
      res = await ApiClient.instance.post(
        '/auth/register',
        body: jsonEncode(body),
      );
    } catch (e) {
      print('[AuthService] REGISTER network error: $e');
      return false;
    }

    print(
        '[AuthService] REGISTER response ← status=${res.statusCode}, body=${res.body}');

    return _saveTokenIfOk(res, context: 'REGISTER');
  }

  /// Trata a resposta de login/register:
  /// - Se 200/201 e tiver access_token → guarda no secure storage
  /// - Caso contrário, loga erro e devolve false
  Future<bool> _saveTokenIfOk(
    http.Response res, {
    required String context,
  }) async {
    if (res.statusCode == 200 || res.statusCode == 201) {
      dynamic decoded;
      try {
        decoded = jsonDecode(res.body);
      } catch (e) {
        print(
            '[AuthService] [$context] Failed to decode JSON response: $e | raw body=${res.body}');
        return false;
      }

      final token = (decoded['access_token'] as String?) ?? '';
      if (token.isEmpty) {
        print(
            '[AuthService] [$context] Response missing access_token. Full decoded body=$decoded');
        return false;
      }

      await _storage.write(key: 'token', value: token);
      print(
          '[AuthService] [$context] Token saved successfully (length: ${token.length})');

      final saved = await _storage.read(key: 'token');
      print(
          '[AuthService] [$context] Token verification: ${saved != null ? "OK" : "FAILED"}');
      return true;
    }

    // Quando NÃO for 200/201, loga status + body completo
    print(
        '[AuthService] [$context] Request failed. status=${res.statusCode}, body=${res.body}');
    return false;
  }

  Future<void> logout() async {
    print('[AuthService] logout() → deleting token');
    await _storage.delete(key: 'token');
  }

  Future<String?> getToken() async {
    final token = await _storage.read(key: 'token');
    print(
        '[AuthService] getToken() → ${token != null ? "token found (length: ${token.length})" : "null"}');
    return token;
  }

  Future<http.Response> me() async {
    final token = await getToken();
    print(
        '[AuthService] /auth/me request → hasToken=${token != null}, tokenLength=${token?.length ?? 0}');
    return ApiClient.instance.get(
      '/auth/me',
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    final loggedIn = token != null;
    print('[AuthService] isLoggedIn() → $loggedIn');
    return loggedIn;
  }
}
