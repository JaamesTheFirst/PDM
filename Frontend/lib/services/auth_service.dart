import 'dart:convert';

import 'package:flutter/foundation.dart'; // debugPrint
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';

/// Serviço responsável pela autenticação do utilizador no frontend.
///
/// Funcionalidades principais:
/// - `login` com email/username + password.
/// - `register` de novos utilizadores.
/// - Persistência do `access_token` em [FlutterSecureStorage].
/// - Helpers `isLoggedIn`, `getToken` e chamada autenticada a `/auth/me`.
///
/// Este serviço é um singleton exposto como [AuthService.instance].
class AuthService {
  AuthService._();

  /// Instância singleton do [AuthService].
  static final AuthService instance = AuthService._();

  /// Armazena o token JWT do utilizador em armazenamento seguro.
  ///
  /// *Chave utilizada:* `'token'`.
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Faz login no backend com `[identifier]` (email ou username) e `[password]`.
  ///
  /// Request enviado:
  /// ```json
  /// {
  ///   "identifier": "<email-ou-username>",
  ///   "password": "<password>"
  /// }
  /// ```
  ///
  /// Em caso de sucesso (HTTP 200/201 com `access_token`):
  /// - Guarda o token em [FlutterSecureStorage].
  /// - Devolve `true`.
  ///
  /// Em qualquer erro (rede, status != 200/201, JSON inválido, sem token):
  /// - Faz log de debug.
  /// - Devolve `false`.
  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    final Map<String, String> body = <String, String>{
      'identifier': identifier,
      'password': password,
    };

    debugPrint(
      '[AuthService] LOGIN request → path=/auth/login body=${{
        'identifier': identifier,
        'passwordLength': password.length,
      }}',
    );

    late http.Response res;
    try {
      res = await ApiClient.instance.post(
        '/auth/login',
        body: jsonEncode(body),
      );
    } catch (e) {
      debugPrint('[AuthService] LOGIN network error: $e');
      return false;
    }

    debugPrint(
      '[AuthService] LOGIN response ← status=${res.statusCode}, body=${res.body}',
    );

    return _saveTokenIfOk(res, context: 'LOGIN');
  }

  /// Regista um novo utilizador no backend.
  ///
  /// Request enviado:
  /// ```json
  /// {
  ///   "username": "...",
  ///   "email": "...",
  ///   "password": "...",
  ///   "firstName": "...", // opcional
  ///   "lastName": "..."   // opcional
  /// }
  /// ```
  ///
  /// Em caso de sucesso (HTTP 200/201 com `access_token`):
  /// - Guarda o token em [FlutterSecureStorage].
  /// - Devolve `true`.
  ///
  /// Em qualquer erro (rede, status != 200/201, JSON inválido, sem token):
  /// - Faz log de debug.
  /// - Devolve `false`.
  Future<bool> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'username': username,
      'email': email,
      'password': password,
      if (firstName != null && firstName.isNotEmpty) 'firstName': firstName,
      if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
    };

    debugPrint(
      '[AuthService] REGISTER request → path=/auth/register body=${{
        'username': username,
        'email': email,
        'passwordLength': password.length,
        'hasFirstName': firstName != null && firstName.isNotEmpty,
        'hasLastName': lastName != null && lastName.isNotEmpty,
      }}',
    );

    late http.Response res;
    try {
      res = await ApiClient.instance.post(
        '/auth/register',
        body: jsonEncode(body),
      );
    } catch (e) {
      debugPrint('[AuthService] REGISTER network error: $e');
      return false;
    }

    debugPrint(
      '[AuthService] REGISTER response ← status=${res.statusCode}, body=${res.body}',
    );

    return _saveTokenIfOk(res, context: 'REGISTER');
  }

  /// Trata a resposta de login/register.
  ///
  /// Regras:
  /// - Se `statusCode` for 200/201 e existir `access_token`:
  ///   - Guarda o token em [FlutterSecureStorage].
  ///   - Faz uma leitura imediata para validar a gravação.
  ///   - Devolve `true`.
  /// - Caso contrário:
  ///   - Faz log de erro detalhado.
  ///   - Devolve `false`.
  Future<bool> _saveTokenIfOk(
    http.Response res, {
    required String context,
  }) async {
    if (res.statusCode == 200 || res.statusCode == 201) {
      dynamic decoded;
      try {
        decoded = jsonDecode(res.body);
      } catch (e) {
        debugPrint(
          '[AuthService] [$context] Failed to decode JSON response: $e | raw body=${res.body}',
        );
        return false;
      }

      final String token = (decoded['access_token'] as String?) ?? '';
      if (token.isEmpty) {
        debugPrint(
          '[AuthService] [$context] Response missing access_token. Full decoded body=$decoded',
        );
        return false;
      }

      await _storage.write(key: 'token', value: token);
      debugPrint(
        '[AuthService] [$context] Token saved successfully (length: ${token.length})',
      );

      final String? saved = await _storage.read(key: 'token');
      debugPrint(
        '[AuthService] [$context] Token verification: ${saved != null ? "OK" : "FAILED"}',
      );
      return true;
    }

    // Quando NÃO for 200/201, loga status + body completo.
    debugPrint(
      '[AuthService] [$context] Request failed. status=${res.statusCode}, body=${res.body}',
    );
    return false;
  }

  /// Remove o token JWT guardado e "faz logout" localmente.
  ///
  /// Não faz nenhuma chamada ao backend – apenas apaga o valor da storage.
  Future<void> logout() async {
    debugPrint('[AuthService] logout() → deleting token');
    await _storage.delete(key: 'token');
  }

  /// Obtém o token JWT guardado em storage segura, ou `null` se não existir.
  ///
  /// Também faz log com o tamanho do token (quando presente), para debug.
  Future<String?> getToken() async {
    final String? token = await _storage.read(key: 'token');
    debugPrint(
      '[AuthService] getToken() → ${token != null ? "token found (length: ${token.length})" : "null"}',
    );
    return token;
  }

  /// Faz uma chamada autenticada ao endpoint `/auth/me`.
  ///
  /// - Se existir token guardado, envia `Authorization: Bearer <token>`.
  /// - Se **não** existir token, a chamada é feita sem cabeçalho de auth,
  ///   podendo resultar em `401` do backend.
  Future<http.Response> me() async {
    final String? token = await getToken();
    debugPrint(
      '[AuthService] /auth/me request → hasToken=${token != null}, tokenLength=${token?.length ?? 0}',
    );
    return ApiClient.instance.get(
      '/auth/me',
      headers: <String, String>{
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }

  /// Indica se existe um token guardado em storage.
  ///
  /// **Nota:** Não valida se o token expirou – apenas verifica se existe.
  Future<bool> isLoggedIn() async {
    final String? token = await getToken();
    final bool loggedIn = token != null;
    debugPrint('[AuthService] isLoggedIn() → $loggedIn');
    return loggedIn;
  }
}
