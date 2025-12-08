import 'package:flutter/foundation.dart';
import '../../../services/auth_service.dart';

/// Controller responsável por orquestrar as operações de autenticação
/// no frontend e expor estado reativo ao UI.
///
/// Encapsula o [AuthService] e fornece:
/// - login
/// - registo
/// - logout
/// - verificação de sessão ativa
class AuthController extends ChangeNotifier {
  final _auth = AuthService.instance;

  bool _isLoading = false;

  /// Indica se existe uma operação de autenticação em curso.
  ///
  /// Usado pelo UI para mostrar spinners e desativar botões enquanto
  /// os pedidos de login/registo são processados.
  bool get isLoading => _isLoading;

  /// Tenta autenticar o utilizador com [identifier] e [password].
  ///
  /// - Ativa o estado de loading.
  /// - Chama [AuthService.login].
  /// - Desativa o estado de loading.
  /// - Devolve `true` se o login for bem-sucedido.
  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    final ok =
        await _auth.login(identifier: identifier, password: password);

    _isLoading = false;
    notifyListeners();
    return ok;
  }

  /// Regista um novo utilizador com os dados fornecidos.
  ///
  /// - Ativa o estado de loading.
  /// - Chama [AuthService.register].
  /// - Desativa o estado de loading.
  /// - Devolve `true` se o registo for bem-sucedido.
  Future<bool> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    _isLoading = true;
    notifyListeners();

    final ok = await _auth.register(
      username: username,
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
    );

    _isLoading = false;
    notifyListeners();
    return ok;
  }

  /// Termina a sessão do utilizador atual.
  ///
  /// Chama [AuthService.logout] e, no fim, notifica ouvintes para que
  /// o UI possa reagir (por exemplo, voltar ao ecrã de login).
  Future<void> logout() async {
    await _auth.logout();
    notifyListeners();
  }

  /// Verifica se existe sessão ativa.
  ///
  /// Delega para [AuthService.isLoggedIn].
  Future<bool> isLoggedIn() => _auth.isLoggedIn();
}
