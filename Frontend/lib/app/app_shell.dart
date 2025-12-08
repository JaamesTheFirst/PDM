// lib/app/app_shell.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/map/pages/map_page.dart';
import '../features/history/pages/history_page.dart';
import '../features/settings/pages/settings_page.dart';
import '../features/impact/pages/impact_page.dart';
import '../features/schedules/pages/schedules_page.dart';
import 'widgets/app_bottom_nav.dart';

/// Shell principal da aplicação depois de o utilizador estar autenticado.
///
/// - Contém a bottom navigation bar com 5 tabs:
///   - Mapa
///   - Histórico
///   - Horários
///   - Impacto
///   - Definições
/// - Garante a gestão do título do [AppBar] de acordo com a tab.
/// - Integra com o modo fullscreen do [MapPage] para esconder
///   `AppBar` e bottom navigation quando o mapa está em modo imersivo.
class AppShell extends StatefulWidget {
  /// Notifier estático usado para navegar programaticamente entre tabs.
  ///
  /// Qualquer parte do código pode fazer:
  ///
  /// ```dart
  /// AppShell.navigateToTab.value = 2; // ir para "Horários"
  /// ```
  ///
  /// O listener interno do [_AppShellState] trata de validar o índice e
  /// atualizar o `_index`. Depois de processar, o valor é reposto para `null`
  /// para evitar navegações repetidas.
  static final ValueNotifier<int?> navigateToTab = ValueNotifier<int?>(null);

  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// Índice da tab atualmente selecionada na bottom navigation.
  int _index = 0;

  /// Lista das páginas correspondentes a cada tab.
  ///
  /// A ordem deve bater certo com a configuração da [AppBottomNav].
  final _pages = const [
    MapPage(),
    HistoryPage(),
    SchedulesPage(), // index 2
    ImpactPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    AppShell.navigateToTab.addListener(_handleTabNavigation);
  }

  @override
  void dispose() {
    AppShell.navigateToTab.removeListener(_handleTabNavigation);
    super.dispose();
  }

  /// Trata pedidos externos de navegação entre tabs via [AppShell.navigateToTab].
  ///
  /// - Valida o índice recebido.
  /// - Se for válido, faz `setState` para atualizar [_index].
  /// - Restaura o notifier para `null` para não repetir a navegação.
  void _handleTabNavigation() {
    final targetIndex = AppShell.navigateToTab.value;

    if (targetIndex != null &&
        targetIndex >= 0 &&
        targetIndex < _pages.length) {
      AppShell.navigateToTab.value = null; // limpa o pedido de navegação
      setState(() => _index = targetIndex);
    }
  }

  /// Callback passado à [AppBottomNav] quando o utilizador toca numa tab.
  void _onTapNav(int i) => setState(() => _index = i);

  /// Devolve o título adequado para o [AppBar] consoante a tab ativa.
  String _titleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Mapa EcoMove';
      case 1:
        return 'Histórico';
      case 2:
        return 'Horários';
      case 3:
        return 'Impacto';
      case 4:
      default:
        return 'Definições';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    // Estilo da status bar e system navigation bar.
    //
    // - Status bar a preto, com ícones claros.
    // - System navigation bar a acompanhar a cor do scaffold.
    final blackStatusBarOverlay = SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: t.scaffoldBackgroundColor,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    );

    return ValueListenableBuilder<bool>(
      // Notifier do MapPage que indica se o mapa está em fullscreen.
      valueListenable: MapPage.fullscreenNotifier,
      builder: (context, fullscreen, _) {
        // Ativa o modo edge-to-edge e aplica o estilo do sistema.
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setSystemUIOverlayStyle(blackStatusBarOverlay);

        final isMap = _index == 0;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: blackStatusBarOverlay,
          child: Scaffold(
            backgroundColor: t.scaffoldBackgroundColor,
            extendBody: true,
            extendBodyBehindAppBar: isMap && fullscreen,
            appBar: isMap && fullscreen
                ? null
                : AppBar(
                    systemOverlayStyle: blackStatusBarOverlay,
                    backgroundColor: t.scaffoldBackgroundColor,
                    elevation: 0,
                    centerTitle: true,
                    title: Text(
                      _titleForIndex(_index),
                      style: t.textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        color: t.colorScheme.onSurface,
                      ),
                    ),
                  ),
            body: SafeArea(
              // Usa sempre SafeArea para lidar com notches/câmaras.
              top: true,
              bottom: true,
              child: _pages[_index],
            ),
            bottomNavigationBar: isMap && fullscreen
                ? null
                : AppBottomNav(
                    currentIndex: _index,
                    onTap: _onTapNav,
                  ),
          ),
        );
      },
    );
  }
}
