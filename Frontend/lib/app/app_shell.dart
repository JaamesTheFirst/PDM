import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/map/pages/map_page.dart';
import '../features/history/pages/history_page.dart';
import '../features/settings/pages/settings_page.dart';
import '../features/impact/pages/impact_page.dart';
import '../features/schedules/pages/schedules_page.dart';
import 'widgets/app_bottom_nav.dart';

class AppShell extends StatefulWidget {
  static final ValueNotifier<int?> navigateToTab = ValueNotifier<int?>(null);
  
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  final _pages = const [
    MapPage(),
    HistoryPage(),
    SchedulesPage(), // <- NOVO index 2
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

  void _handleTabNavigation() {
    final targetIndex = AppShell.navigateToTab.value;
    if (targetIndex != null && targetIndex >= 0 && targetIndex < _pages.length) {
      AppShell.navigateToTab.value = null; // Clear the navigation request
      setState(() => _index = targetIndex);
    }
  }

  void _onTapNav(int i) => setState(() => _index = i);

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

    // Black status bar overlay - automatically handles notches/camera holes
    // Status bar icons will be light (white) so they're visible on black
    final blackStatusBarOverlay = SystemUiOverlayStyle(
      statusBarColor: Colors.black, // Black status bar area
      statusBarIconBrightness: Brightness.light, // White icons (visible on black)
      systemNavigationBarColor: t.scaffoldBackgroundColor,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    );

    return ValueListenableBuilder<bool>(
      valueListenable: MapPage.fullscreenNotifier,
      builder: (context, fullscreen, _) {
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
              top: true, // Always use SafeArea top to handle notches/camera holes
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
