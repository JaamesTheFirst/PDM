import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/history_service.dart';
import '../../../app/app_shell.dart';
import '../../map/pages/map_page.dart';
import '../../../app/app_router.dart';
import '../../auth/state/auth_controller.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _historyService = HistoryService.instance;
  List<RouteHistoryItem> _history = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
    // Listen to auth state changes (e.g., when user logs in)
    context.read<AuthController>().addListener(_onAuthStateChanged);
  }

  @override
  void dispose() {
    context.read<AuthController>().removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    // Reload history when auth state changes (e.g., after login)
    if (mounted) {
      _checkAuthAndLoad();
    }
  }

  Future<void> _checkAuthAndLoad() async {
    final authController = context.read<AuthController>();
    final isLoggedIn = await authController.isLoggedIn();
    
    if (!isLoggedIn) {
      setState(() {
        _isLoading = false;
        _error = 'Por favor, inicia sessão para veres o teu histórico';
      });
      return;
    }
    
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final history = await _historyService.getHistory(limit: 20);
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        // Provide user-friendly error messages
        if (e.toString().contains('Not authenticated') || 
            e.toString().contains('not authenticated')) {
          _error = 'Por favor, inicia sessão para veres o teu histórico';
        } else if (e.toString().contains('Failed to fetch') || 
                   e.toString().contains('timed out')) {
          _error = 'Erro ao conectar ao servidor. Verifica a tua ligação à internet.';
        } else {
          _error = e.toString();
        }
        _isLoading = false;
      });
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins > 0 ? '$hours h $mins min' : '$hours h';
  }

  String _formatDistance(int meters) {
    if (meters < 1000) {
      return '$meters m';
    }
    final km = (meters / 1000).toStringAsFixed(1);
    return '$km km';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Hoje';
    } else if (diff.inDays == 1) {
      return 'Ontem';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} dias atrás';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).round();
      return weeks == 1 ? '1 semana atrás' : '$weeks semanas atrás';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  IconData _iconForMode(String mode) {
    switch (mode.toUpperCase()) {
      case 'WALK':
      case 'WALKING':
        return Icons.directions_walk;
      case 'BICYCLE':
      case 'BICYCLE_RENT':
        return Icons.pedal_bike;
      case 'BUS':
      case 'TRAM':
        return Icons.directions_bus;
      case 'SUBWAY':
      case 'RAIL':
        return Icons.train;
      case 'CAR':
      case 'DRIVING':
        return Icons.directions_car;
      default:
        return Icons.directions_transit;
    }
  }

  Future<void> _repeatSearch(RouteHistoryItem item) async {
    // Mudar para o tab do mapa
    AppShell.navigateToTab.value = 0;

    // Pequeno delay para dar tempo ao MapPage montar
    await Future.delayed(const Duration(milliseconds: 300));

    // Enviar os dados para o MapPage via ValueNotifier
    MapPage.pendingRouteSearch.value = {
      'fromId': 'history_${item.id}_from',
      'fromName': item.originName,
      'fromLat': item.originLatitude,
      'fromLon': item.originLongitude,
      'toId': 'history_${item.id}_to',
      'toName': item.destinationName,
      'toLat': item.destinationLatitude,
      'toLon': item.destinationLongitude,
    };

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('A carregar rota...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    
    // Check auth state when building - if we have an auth error but user is now logged in, reload
    if (_error != null && _error!.toLowerCase().contains('not authenticated')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final authController = context.read<AuthController>();
        authController.isLoggedIn().then((isLoggedIn) {
          if (isLoggedIn && mounted) {
            _checkAuthAndLoad();
          }
        });
      });
    }

    if (_isLoading) {
      return Container(
        color: t.scaffoldBackgroundColor,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      final isAuthError = _error!.toLowerCase().contains('not authenticated') || 
                          _error!.toLowerCase().contains('autenticado');
      
      return Container(
        color: t.scaffoldBackgroundColor,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAuthError ? Icons.login : Icons.error_outline, 
                size: 48, 
                color: isAuthError ? t.colorScheme.primary : t.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                isAuthError ? 'Sessão não iniciada' : 'Erro ao carregar histórico',
                style: t.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _error!,
                style: t.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (isAuthError)
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to login screen
                    // After login, AuthController will notify listeners and _onAuthStateChanged will reload
                    Navigator.of(context).pushNamed('/login');
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Iniciar sessão'),
                )
              else
                ElevatedButton(
                  onPressed: _loadHistory,
                  child: const Text('Tentar novamente'),
                ),
            ],
          ),
        ),
      );
    }

    if (_history.isEmpty) {
      return Container(
        color: t.scaffoldBackgroundColor,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history,
                size: 48,
                color: t.colorScheme.onSurface.withOpacity(.6),
              ),
              const SizedBox(height: 12),
              Text(
                'O teu histórico vai aparecer aqui',
                style: TextStyle(
                  fontSize: 16,
                  color: t.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Planeia um trajeto para começares a registar.',
                style: TextStyle(
                  fontSize: 14,
                  color: t.colorScheme.onSurface.withOpacity(.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: t.scaffoldBackgroundColor,
      child: RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _history.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = _history[index];
            return _HistoryCard(
              item: item,
              onTap: () => _repeatSearch(item),
              formatDuration: _formatDuration,
              formatDistance: _formatDistance,
              formatDate: _formatDate,
              iconForMode: _iconForMode,
            );
          },
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  static const _ecoMint = Color(0xFF3CD4A0);

  final RouteHistoryItem item;
  final VoidCallback onTap;
  final String Function(int) formatDuration;
  final String Function(int) formatDistance;
  final String Function(DateTime) formatDate;
  final IconData Function(String) iconForMode;

  const _HistoryCard({
    required this.item,
    required this.onTap,
    required this.formatDuration,
    required this.formatDistance,
    required this.formatDate,
    required this.iconForMode,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final primaryIcon = iconForMode(item.primaryMode);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: t.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: t.brightness == Brightness.dark
                ? Colors.white10
                : const Color(0x143CD4A0),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _ecoMint.withOpacity(0.16),
                  child: Icon(primaryIcon, color: _ecoMint, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.originName,
                        style: t.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color:
                                t.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.destinationName,
                              style: t.textTheme.bodySmall?.copyWith(
                                color: t.colorScheme.onSurface
                                    .withOpacity(0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  formatDate(item.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        t.colorScheme.onSurface.withOpacity(0.5),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.access_time,
                  label: formatDuration(item.durationSeconds),
                  color: t.colorScheme.onSurface.withOpacity(0.7),
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.straighten,
                  label: formatDistance(item.distanceMeters),
                  color: t.colorScheme.onSurface.withOpacity(0.7),
                ),
                if (item.modes.length > 1) ...[
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.swap_horiz,
                    label: '${item.modes.length} modos',
                    color: _ecoMint,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
