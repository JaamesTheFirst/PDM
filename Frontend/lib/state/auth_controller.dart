import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  final _auth = AuthService.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<bool> login({required String identifier, required String password}) async {
    _isLoading = true; notifyListeners();
    final ok = await _auth.login(identifier: identifier, password: password);
    _isLoading = false; notifyListeners();
    return ok;
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    _isLoading = true; notifyListeners();
    final ok = await _auth.register(
      username: username, email: email, password: password, firstName: firstName, lastName: lastName,
    );
    _isLoading = false; notifyListeners();
    return ok;
  }

  Future<void> logout() async {
    await _auth.logout();
    notifyListeners();
  }

  Future<bool> isLoggedIn() => _auth.isLoggedIn();
}
