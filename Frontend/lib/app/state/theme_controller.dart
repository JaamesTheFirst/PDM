import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controla o tema global da aplicação (claro/escuro/sistema),
/// persistindo a escolha do utilizador em `SharedPreferences`.
///
/// A instância deste controller deve ser exposta via [ChangeNotifierProvider]
/// (ou semelhante) para que o UI possa reagir a alterações de [themeMode].
class ThemeController extends ChangeNotifier {
  /// Chave usada em `SharedPreferences` para guardar o modo de tema.
  static const _prefKey = 'theme_mode_v1';

  /// Modo de tema atualmente ativo.
  ///
  /// Por omissão, começa em [ThemeMode.dark] até o valor persistido
  /// ser carregado em [_load].
  ThemeMode _mode = ThemeMode.dark;

  /// Exposição pública do modo de tema atual.
  ThemeMode get themeMode => _mode;

  /// Cria o [ThemeController] e inicia o carregamento
  /// do tema persistido em background.
  ///
  /// O UI começa em modo escuro por omissão e é atualizado assim
  /// que [_load] terminar e chamar [notifyListeners].
  ThemeController() {
    _load();
  }

  /// Carrega o modo de tema guardado em `SharedPreferences`.
  ///
  /// Se ainda não existir nenhum valor, usa [ThemeMode.dark] como default.
  /// No fim, chama [notifyListeners] para atualizar o UI.
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
      case 'system':
        _mode = ThemeMode.system;
        break;
      default:
        // Se não existir ainda, fica dark.
        _mode = ThemeMode.dark;
    }

    notifyListeners();
  }

  /// Atualiza o modo de tema atual e persiste a escolha do utilizador.
  ///
  /// - Atualiza [_mode]
  /// - Chama [notifyListeners] para que o UI reaja
  /// - Guarda a seleção em `SharedPreferences` com a chave [_prefKey]
  Future<void> setThemeMode(ThemeMode m) async {
    _mode = m;
    notifyListeners();

    final p = await SharedPreferences.getInstance();
    await p.setString(
      _prefKey,
      m == ThemeMode.light
          ? 'light'
          : m == ThemeMode.dark
              ? 'dark'
              : 'system',
    );
  }

  /// Cor token principal usada como seed do tema e para elementos de destaque.
  static const ecoMint = Color(0xFF3CD4A0);

  /// Tema claro da aplicação.
  ///
  /// Baseado em [ColorScheme.fromSeed] com [ecoMint] e superfícies claras.
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

  /// Tema escuro da aplicação.
  ///
  /// Fundo preto, cartões escuros e texto claro, também baseado em
  /// [ColorScheme.fromSeed] com [ecoMint].
  ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: ecoMint,
      brightness: Brightness.dark,
      primary: ecoMint,
      surface: const Color(0xFF101213), // fundo principal
      onSurface: Colors.white, // texto principal
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
