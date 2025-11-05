import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static const _prefKey = 'theme_mode_v1';

  ThemeMode _mode = ThemeMode.dark; // default: DARK
  ThemeMode get themeMode => _mode;

  ThemeController() {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_prefKey);
    switch (v) {
      case 'light':
        _mode = ThemeMode.light;
        break;
      case 'dark':
        _mode = ThemeMode.dark;
        break;
      default:
        // se não existir ainda, fica dark
        _mode = ThemeMode.dark;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    _mode = m;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _prefKey,
      m == ThemeMode.light ? 'light' : m == ThemeMode.dark ? 'dark' : 'system',
    );
  }

  // tokens
  static const ecoMint = Color(0xFF3CD4A0);

  ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: ecoMint,
      brightness: Brightness.light,
      primary: ecoMint,
      surface: const Color(0xFFF8F7F4),
      onSurface: const Color(0xFF1C1C1C),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      cardColor: Colors.white,
    );
  }

  ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: ecoMint,
      brightness: Brightness.dark,
      primary: ecoMint,
      surface: const Color(0xFF101213),   // fundo principal preto
      onSurface: Colors.white,            // texto branco
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      cardColor: const Color(0xFF1A1D1E), // cartões escuros
    );
  }
}
