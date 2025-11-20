import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/map/pages/map_page.dart';
import '../features/history/pages/history_page.dart';
import '../features/settings/pages/settings_page.dart';
import '../features/impact/pages/impact_page.dart';
import 'widgets/app_bottom_nav.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  final _pages = const [
    MapPage(),
    HistoryPage(),
    ImpactPage(),
    SettingsPage(),
  ];

  void _onTapNav(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    final baseOverlay =
        isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    // barras com a mesma cor do scaffold
    final normalOverlay = baseOverlay.copyWith(
      statusBarColor: t.scaffoldBackgroundColor,
      systemNavigationBarColor: t.scaffoldBackgroundColor,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    );

    // barras transparentes (para fullscreen do mapa)
    final transparentOverlay = baseOverlay.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    );

    return ValueListenableBuilder<bool>(
      valueListenable: MapPage.fullscreenNotifier,
      builder: (context, fullscreen, _) {
        final overlay = fullscreen ? transparentOverlay : normalOverlay;

        // edge-to-edge sempre; barras transparentes ou com cor, consoante o modo
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setSystemUIOverlayStyle(overlay);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay,
          child: Scaffold(
            backgroundColor: t.scaffoldBackgroundColor,
            extendBody: true,
            extendBodyBehindAppBar: fullscreen,
            appBar: fullscreen
                ? null
                : AppBar(
                    systemOverlayStyle: normalOverlay,
                    backgroundColor: t.scaffoldBackgroundColor,
                    elevation: 0,
                    centerTitle: true,
                    title: Text(
                      _index == 0
                          ? 'Mapa EcoMove'
                          : _index == 1
                              ? 'Histórico'
                              : _index == 2
                                  ? 'Impacto'
                                  : 'Definições',
                      style: t.textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        color: t.colorScheme.onSurface,
                      ),
                    ),
                  ),
            body: SafeArea(
              // quando fullscreen = true, deixamos o conteúdo ocupar até ao topo
              top: !fullscreen,
              bottom: true,
              child: _pages[_index],
            ),
            bottomNavigationBar:
                fullscreen ? null : AppBottomNav(currentIndex: _index, onTap: _onTapNav),
          ),
        );
      },
    );
  }
}
