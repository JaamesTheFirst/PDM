import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/navigation_controller.dart';

class NavigationOverlay extends StatelessWidget {
  const NavigationOverlay({super.key});

  static const _ecoMint = Color(0xFF3CD4A0);

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  // Aceita num (int ou double) para evitar erro de tipo com currentLeg.duration
  String _formatTime(num seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '$hours h $mins min';
  }

  @override
  Widget build(BuildContext context) {
    final navController = context.watch<NavigationController>();
    final theme = Theme.of(context);

    if (!navController.isNavigating) {
      return const SizedBox.shrink();
    }

    final itinerary = navController.activeItinerary;
    if (itinerary == null) return const SizedBox.shrink();

    final distanceRemaining = navController.distanceRemaining;
    final progress = navController.progress;
    final nextInstruction = navController.nextInstruction;
    final currentLeg = navController.currentLeg;
    final isReRouting = navController.isReRouting;

    return SafeArea(
      child: Column(
        children: [
          // Top navigation card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Re-routing indicator
                if (isReRouting)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'A recalcular rota...',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(_ecoMint),
                  ),
                ),
                const SizedBox(height: 12),

                // Next instruction
                if (nextInstruction != null && !isReRouting)
                  Text(
                    nextInstruction!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 8),

                // Distance and time remaining
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.navigation,
                          size: 16,
                          color: _ecoMint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDistance(distanceRemaining),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (currentLeg != null)
                      Text(
                        _formatTime(currentLeg.duration),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // Bottom action buttons
          Container(
            margin: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Stop navigation button
                ElevatedButton.icon(
                  onPressed: () {
                    navController.stopNavigation();
                  },
                  icon: const Icon(Icons.stop),
                  label: const Text('Parar Navegação'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
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
