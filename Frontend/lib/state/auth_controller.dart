import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  final _auth = AuthService.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    final ok = await _auth.login(email, password);
    _isLoading = false;
    notifyListeners();
    return ok;
  }

  Future<void> logout() async {
    await _auth.logout();
    notifyListeners();
  }
}
