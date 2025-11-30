import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  // Design System tokens
  static const _ecoMint = Color(0xFF3CD4A0);
  static const _coolGrey = Color(0xFFA1A1A1);
  static const _offWhiteSand = Color(0xFFF8F7F4);

  @override
  Widget build(BuildContext context) {
    const int tabCount = 5; // <-- AGORA 5 TABS
    const double barHeight = 94;
    const double horizontalPadding = 12;

    const double indicatorHeight = 5;
    const duration = Duration(milliseconds: 300);
    const curve = Curves.easeOutCubic;

    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    final bg = isDark ? t.scaffoldBackgroundColor : _offWhiteSand;

    final systemUi = SystemUiOverlayStyle(
      systemNavigationBarColor: bg,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );

    // alinhamento da barra verde
    final step = 2 / (tabCount - 1);
    final alignX = -1.0 + step * currentIndex;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUi,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: barHeight,
          child: Container(
            decoration: const BoxDecoration(
              color: null,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 18,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // ===== Barra verde no topo =====
                  AnimatedAlign(
                    alignment: Alignment(alignX, -1.0),
                    duration: duration,
                    curve: curve,
                    child: const FractionallySizedBox(
                      widthFactor: 1 / tabCount,
                      child: SizedBox(
                        height: indicatorHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: _ecoMint),
                        ),
                      ),
                    ),
                  ),

                  // ===== Itens =====
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        horizontalPadding,
                        10,
                        horizontalPadding,
                        14,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _NavItem(
                              icon: currentIndex == 0
                                  ? Icons.map
                                  : Icons.map_outlined,
                              label: 'Mapa',
                              selected: currentIndex == 0,
                              onTap: () => onTap(0),
                            ),
                          ),
                          Expanded(
                            child: _NavItem(
                              icon: Icons.history,
                              label: 'Histórico',
                              selected: currentIndex == 1,
                              onTap: () => onTap(1),
                            ),
                          ),
                          Expanded(
                            child: _NavItem(
                              icon: currentIndex == 2
                                  ? Icons.schedule
                                  : Icons.schedule_outlined,
                              label: 'Horários',
                              selected: currentIndex == 2,
                              onTap: () => onTap(2),
                            ),
                          ),
                          Expanded(
                            child: _NavItem(
                              icon: currentIndex == 3
                                  ? Icons.insights
                                  : Icons.insights_outlined,
                              label: 'Impacto',
                              selected: currentIndex == 3,
                              onTap: () => onTap(3),
                            ),
                          ),
                          Expanded(
                            child: _NavItem(
                              icon: currentIndex == 4
                                  ? Icons.settings
                                  : Icons.settings_outlined,
                              label: 'Definições',
                              selected: currentIndex == 4,
                              onTap: () => onTap(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _ecoMint = Color(0xFF3CD4A0);
  static const _coolGrey = Color(0xFFA1A1A1);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    final iconColor =
        selected ? _ecoMint : (isDark ? Colors.white70 : _coolGrey);
    final textColor = selected
        ? (isDark ? Colors.white : const Color(0xFF1C1C1C))
        : (isDark ? Colors.white70 : _coolGrey);

    const double iconSize = 28;
    const double selectedScale = 1.07;
    const double minTap = 48;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minTap),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? selectedScale : 1.0,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                child: Icon(icon, color: iconColor, size: iconSize),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w600,
                  color: textColor,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
