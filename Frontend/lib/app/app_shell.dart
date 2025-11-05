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

    // garante icons corretos na status bar
    final overlay = isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    return Scaffold(
      backgroundColor: t.scaffoldBackgroundColor, // ✅ usa tema (preto no dark)
      appBar: AppBar(
        systemOverlayStyle: overlay,
        backgroundColor: t.scaffoldBackgroundColor, // ✅ sem branco hardcoded
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
            color: t.colorScheme.onSurface, // ✅ texto branco no dark
          ),
        ),
      ),
      body: _pages[_index],
      bottomNavigationBar: AppBottomNav(currentIndex: _index, onTap: _onTapNav),
    );
  }
}
