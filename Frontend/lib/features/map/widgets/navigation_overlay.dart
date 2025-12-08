import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import '../state/navigation_controller.dart';
import '../../../services/routes_service.dart'; // OtpItinerary, OtpLeg

/// Overlay de navegação apresentado sobre o mapa durante a navegação ativa.
///
/// Este widget:
/// - Só é visível quando `NavigationController.isNavigating == true`.
/// - Mostra um cartão superior com:
///   - Modo da leg atual (ícone + label).
///   - Distância restante até ao fim da leg.
///   - Duração da leg vs. distância.
///   - Progresso global da rota (barra).
///   - Distância restante na rota e duração total.
///   - Coordenadas atuais (lat/lon) em modo debug.
/// - Mostra um botão inferior para parar a navegação e fechar o ecrã.
///
/// A UI é “read-only”: todos os dados vêm do `NavigationController`.
class NavigationOverlay extends StatelessWidget {
  const NavigationOverlay({super.key});

  /// Token de cor verde eco usada noutros componentes (Eco Mint).
  static const _ecoMint = Color(0xFF3CD4A0);

  /// Devolve um ícone representativo para a [leg] atual com base no mode.
  IconData _iconForLeg(OtpLeg? leg) {
    if (leg == null) return Icons.navigation;
    final mode = leg.mode.toUpperCase();

    if (mode == 'WALK' || mode == 'WALKING') {
      return Icons.directions_walk;
    }
    if (mode.contains('BUS')) return Icons.directions_bus;
    if (mode.contains('RAIL') ||
        mode.contains('TRAIN') ||
        mode == 'R' ||
        mode == 'IC') {
      return Icons.train;
    }
    if (mode.contains('METRO') || mode.contains('SUBWAY')) {
      return Icons.subway;
    }
    if (mode.contains('TRAM')) return Icons.tram;
    if (mode.contains('BIKE') || mode.contains('BICYCLE')) {
      return Icons.directions_bike;
    }
    if (mode.contains('CAR')) return Icons.directions_car;

    return Icons.directions_transit;
  }

  /// Devolve um label amigável para o modo de transporte da [leg].
  String _modeLabel(OtpLeg? leg) {
    if (leg == null) return 'A navegar';
    final mode = leg.mode.toUpperCase();
    if (mode == 'WALK' || mode == 'WALKING') return 'Caminha';
    if (mode.contains('BUS')) return 'Autocarro';
    if (mode.contains('RAIL') ||
        mode.contains('TRAIN') ||
        mode == 'R' ||
        mode == 'IC') return 'Comboio';
    if (mode.contains('METRO') || mode.contains('SUBWAY')) return 'Metro';
    if (mode.contains('TRAM')) return 'Elétrico';
    if (mode.contains('BIKE') || mode.contains('BICYCLE')) return 'Bicicleta';
    if (mode.contains('CAR')) return 'Carro';
    return 'Transporte';
  }

  /// Formata uma distância em metros para string legível (m ou km).
  String _formatDistance(num meters) {
    final m = meters.toDouble();
    if (m < 1000) return '${m.round()} m';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }

  /// Converte uma duração em segundos para string em minutos/horas.
  ///
  /// Exemplos:
  /// - 300 s → "5 min"
  /// - 3600 s → "1 h"
  /// - 3900 s → "1 h 5 min"
  String _formatDurationMinutes(num seconds) {
    final s = seconds.toDouble();
    final totalMin = (s / 60).round();
    if (totalMin < 60) return '$totalMin min';
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    if (m == 0) return '${h} h';
    return '${h} h ${m} min';
  }

  /// Formata um valor de latitude/longitude com 5 casas decimais.
  String _formatLatLon(num value) => value.toDouble().toStringAsFixed(5);

  @override
  Widget build(BuildContext context) {
    // Obtemos o controlador de navegação da árvore de providers.
    final navController = context.watch<NavigationController>();

    // Se não há navegação ativa, não desenhamos nada.
    if (!navController.isNavigating) {
      return const SizedBox.shrink();
    }

    final itinerary = navController.activeItinerary;
    if (itinerary == null) return const SizedBox.shrink();

    final leg = navController.currentLeg;
    final modeIcon = _iconForLeg(leg);
    final modeLabel = _modeLabel(leg);

    final legDistanceRemaining = navController.currentLegDistanceRemaining;
    final routeDistanceRemaining = navController.distanceRemaining;

    final legDuration = leg?.duration ?? 0;
    final routeDuration = itinerary.duration;

    final routeProgress = navController.progress;

    final Position? pos = navController.currentPosition;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final topPadding = media.padding.top;

    return Positioned.fill(
      child: Column(
        children: [
          // ===== CARD SUPERIOR =====
          Padding(
            padding: EdgeInsets.fromLTRB(12, topPadding + 8, 12, 0),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.cardColor, // adapta a light/dark
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 22,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ÍCONE GRANDE à esquerda
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        modeIcon,
                        size: 44,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Texto à direita
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Label do modo (ex.: “Autocarro”, “Caminha”)
                          Text(
                            modeLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Distância até ao fim da leg atual
                          Text(
                            '${_formatDistance(legDistanceRemaining)} até ${leg?.toName ?? 'destino'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Duração + distância da leg atual
                          Text(
                            'Esta etapa: ${_formatDurationMinutes(legDuration)} • ${_formatDistance(leg?.distance ?? 0)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.75),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Barra de progresso da rota
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 5,
                              value: routeProgress,
                              backgroundColor:
                                  colorScheme.onSurface.withValues(alpha: 0.15),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              // Distância restante da rota
                              Expanded(
                                child: Text(
                                  'Rota: ${_formatDistance(routeDistanceRemaining)} restantes',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color:
                                        colorScheme.onSurface.withValues(alpha: 0.9),
                                  ),
                                ),
                              ),
                              // Duração total da rota
                              Expanded(
                                child: Text(
                                  'Duração total: ${_formatDurationMinutes(routeDuration)}',
                                  textAlign: TextAlign.right,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color:
                                        colorScheme.onSurface.withOpacity(0.9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Coordenadas atuais (útil para debug)
                          if (pos != null)
                            Text(
                              'Lat: ${_formatLatLon(pos.latitude)}  •  Lon: ${_formatLatLon(pos.longitude)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    colorScheme.onSurface.withOpacity(0.75),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Spacer(),

          // ===== BOTÃO PARAR NAVEGAÇÃO =====
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              media.padding.bottom + 16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: media.size.width * 0.65,
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Pára a navegação e regressa ao ecrã anterior.
                      await navController.stopNavigation();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      elevation: 6,
                    ),
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text(
                      'Parar navegação',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
