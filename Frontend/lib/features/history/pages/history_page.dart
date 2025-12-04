import 'package:flutter/material.dart';

import '../../../services/history_service.dart';
import '../../../app/app_shell.dart';
import '../../map/pages/map_page.dart';

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

  /// Quais cards estão expandidos (por id)
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final history = await _historyService.getHistory();
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar histórico: $e';
        _isLoading = false;
      });
    }
  }

  /// Formata SEMPRE como data/hora absoluta: dd/MM/yyyy HH:mm
  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  Future<void> _repeatTrip(RouteHistoryItem item) async {
    // Mudar para o tab do mapa
    AppShell.navigateToTab.value = 0;

    // Pequeno delay para o MapPage montar
    await Future.delayed(const Duration(milliseconds: 300));

    // Origem = localização atual; destino = destino da viagem antiga.
    MapPage.pendingRouteSearch.value = {
      'toId': 'route_${item.id}',
      'toName': item.destinationName,
      'toAddress': item.destinationName,
      'toLat': item.destinationLatitude,
      'toLon': item.destinationLongitude,
    };

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('A carregar rota do histórico...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    if (_isLoading) {
      return Container(
        color: t.scaffoldBackgroundColor,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        color: t.scaffoldBackgroundColor,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                'Erro ao carregar histórico',
                style: t.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _error!,
                style: t.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
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
                'Ainda não há viagens no histórico',
                style: TextStyle(fontSize: 16, color: t.colorScheme.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                'Planeia e aplica uma rota para começar a guardar as tuas viagens.',
                style: TextStyle(
                  fontSize: 14,
                  color: t.colorScheme.onSurface.withOpacity(.7),
                ),
                textAlign: TextAlign.center,
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

            // depois – dá prioridade ao createdAt
            final refDate =
                item.createdAt ??
                item.startedAt ??
                item.finishedAt ??
                item.updatedAt ??
                DateTime.now();

            final isExpanded = _expandedIds.contains(item.id);

            return _RouteHistoryCard(
              item: item,
              formattedDate: _formatDate(refDate),
              isExpanded: isExpanded,
              onToggleExpanded: () {
                setState(() {
                  if (isExpanded) {
                    _expandedIds.remove(item.id);
                  } else {
                    _expandedIds.add(item.id);
                  }
                });
              },
              onRepeatTrip: () => _repeatTrip(item),
            );
          },
        ),
      ),
    );
  }
}

class _RouteHistoryCard extends StatelessWidget {
  static const _ecoMint = Color(0xFF3CD4A0);

  final RouteHistoryItem item;
  final String formattedDate;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onRepeatTrip;

  const _RouteHistoryCard({
    required this.item,
    required this.formattedDate,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onRepeatTrip,
  });

  IconData _iconForMode(String mode) {
    final m = mode.toUpperCase();
    if (m == 'WALKING' || m == 'WALK' || m == 'FOOT') {
      return Icons.directions_walk;
    }
    if (m == 'BIKE' || m == 'BICYCLE') return Icons.directions_bike;
    if (m == 'SCOOTER' || m == 'SCOOTER_SHARE') {
      return Icons.electric_scooter;
    }
    if (m == 'BUS' || m == 'COACH') return Icons.directions_bus;
    if (m == 'TRAIN' || m == 'RAIL') return Icons.train;
    if (m == 'METRO' || m == 'SUBWAY' || m == 'TRAM') return Icons.subway;
    if (m == 'CAR' || m == 'EV_CAR' || m == 'TAXI') {
      return Icons.directions_car;
    }
    return Icons.directions_transit;
  }

  String _modeLabel(String mode) {
    final m = mode.toUpperCase();
    if (m == 'WALK' || m == 'WALKING' || m == 'FOOT') return 'A pé';
    if (m == 'BIKE' || m == 'BICYCLE') return 'Bicicleta';
    if (m == 'SCOOTER' || m == 'SCOOTER_SHARE') return 'Trotinete';
    if (m == 'BUS') return 'Autocarro';
    if (m == 'COACH') return 'Expresso';
    if (m == 'TRAIN' || m == 'RAIL') return 'Comboio';
    if (m == 'METRO' || m == 'SUBWAY') return 'Metro';
    if (m == 'TRAM') return 'Eléctrico';
    if (m == 'CAR' || m == 'EV_CAR') return 'Carro';
    if (m == 'TAXI') return 'Táxi';
    return mode;
  }

  bool _isPlaceholderName(String? value) {
    if (value == null) return true;
    final v = value.trim();
    if (v.isEmpty) return true;
    final lower = v.toLowerCase();
    return lower == 'origin' || lower == 'destination';
  }

  String _resolveEndpointName({
    required String? baseName,
    required List<dynamic> segments,
    required bool useFrom,
  }) {
    String? name = baseName?.trim();

    if (_isPlaceholderName(name)) {
      if (segments.isNotEmpty) {
        final dynamic leg = useFrom ? segments.first : segments.last;
        if (leg is Map<String, dynamic>) {
          final endpoint = leg[useFrom ? 'from' : 'to'];
          if (endpoint is Map<String, dynamic>) {
            final sName = (endpoint['name'] as String?)?.trim();
            if (!_isPlaceholderName(sName)) {
              name = sName;
            }
          }
        }
      }
    }

    if (name == null || name.isEmpty) {
      return useFrom ? 'Origem' : 'Destino';
    }
    return name;
  }

  /// Formata duração em min / h / dias
  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0 min';

    final totalMinutes = (totalSeconds / 60).round();

    if (totalMinutes < 60) {
      // < 1h
      return '$totalMinutes min';
    }

    final totalHours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (totalHours < 24) {
      // entre 1h e 24h
      if (minutes == 0) return '${totalHours} h';
      return '${totalHours} h ${minutes} min';
    }

    // >= 24h → dias + horas
    final days = totalHours ~/ 24;
    final hours = totalHours % 24;

    final dayLabel = days == 1 ? '1 dia' : '$days dias';

    if (hours == 0) {
      return dayLabel;
    }
    return '$dayLabel ${hours} h';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    final distanceKm = item.distanceMeters / 1000.0;
    final durationLabel = _formatDuration(item.durationSeconds);
    final subtitle = '$durationLabel • ${distanceKm.toStringAsFixed(1)} km';

    final List<dynamic> segments = item.segments is List
        ? (item.segments as List)
        : const [];

    final originDisplay = _resolveEndpointName(
      baseName: item.originName,
      segments: segments,
      useFrom: true,
    );
    final destinationDisplay = _resolveEndpointName(
      baseName: item.destinationName,
      segments: segments,
      useFrom: false,
    );

    return InkWell(
      onTap: onToggleExpanded,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
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
            color: isExpanded
                ? _ecoMint.withOpacity(0.7)
                : (t.brightness == Brightness.dark
                      ? Colors.white10
                      : const Color(0x143CD4A0)),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _ecoMint.withOpacity(0.16),
                  child: Icon(
                    _iconForMode(item.primaryMode),
                    color: _ecoMint,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$originDisplay → $destinationDisplay',
                        style: t.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: t.textTheme.bodySmall?.copyWith(
                          color: t.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: t.colorScheme.onSurface.withOpacity(0.5),
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: t.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    _ItinerarySegmentsView(
                      segments: segments,
                      iconForMode: _iconForMode,
                      modeLabel: _modeLabel,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: onRepeatTrip,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Repetir rota'),
                        style: TextButton.styleFrom(
                          foregroundColor: _ecoMint,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
              sizeCurve: Curves.easeOutCubic,
            ),
          ],
        ),
      ),
    );
  }
}

class _ItinerarySegmentsView extends StatelessWidget {
  final List<dynamic>? segments;
  final IconData Function(String mode) iconForMode;
  final String Function(String mode) modeLabel;

  const _ItinerarySegmentsView({
    required this.segments,
    required this.iconForMode,
    required this.modeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    final legs = segments ?? const [];

    if (legs.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Detalhes de itinerário não disponíveis.',
          style: t.textTheme.bodySmall?.copyWith(
            color: t.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < legs.length; i++)
          _SegmentRow(
            leg: legs[i],
            isFirst: i == 0,
            isLast: i == legs.length - 1,
            iconForMode: iconForMode,
            modeLabel: modeLabel,
          ),
      ],
    );
  }
}

class _SegmentRow extends StatelessWidget {
  final dynamic leg;
  final bool isFirst;
  final bool isLast;
  final IconData Function(String mode) iconForMode;
  final String Function(String mode) modeLabel;

  const _SegmentRow({
    required this.leg,
    required this.isFirst,
    required this.isLast,
    required this.iconForMode,
    required this.modeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    final legMap = leg as Map<String, dynamic>? ?? {};

    final mode = (legMap['mode'] as String?) ?? 'WALK';

    String? fromName;
    String? toName;

    final from = legMap['from'];
    if (from is Map<String, dynamic>) {
      fromName = from['name'] as String?;
    }

    final to = legMap['to'];
    if (to is Map<String, dynamic>) {
      toName = to['name'] as String?;
    }

    String? routeName;
    final route = legMap['route'];
    if (route is Map<String, dynamic>) {
      routeName =
          (route['shortName'] as String?) ?? (route['longName'] as String?);
    }

    final distanceMeters = (legMap['distance'] as num?)?.toDouble();
    final durationSeconds = (legMap['duration'] as num?)?.toDouble();

    final distanceKm = distanceMeters != null
        ? (distanceMeters / 1000.0)
        : null;
    final durationMin = durationSeconds != null
        ? (durationSeconds / 60.0).round()
        : null;

    final titleBuffer = StringBuffer();
    titleBuffer.write(modeLabel(mode));
    if (routeName != null && routeName.trim().isNotEmpty) {
      titleBuffer.write(' $routeName');
    }

    final detailsBuffer = StringBuffer();
    if (durationMin != null) {
      detailsBuffer.write('${durationMin} min');
    }
    if (distanceKm != null) {
      if (detailsBuffer.isNotEmpty) detailsBuffer.write(' • ');
      detailsBuffer.write('${distanceKm.toStringAsFixed(1)} km');
    }

    final pathLabel = (fromName != null && toName != null)
        ? '$fromName → $toName'
        : (fromName ?? toName ?? '');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            SizedBox(height: isFirst ? 10 : 4),
            Icon(iconForMode(mode), size: 18, color: t.colorScheme.primary),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: t.colorScheme.primary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: isLast ? 0 : 8,
              top: isFirst ? 0 : 4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleBuffer.toString(),
                  style: t.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (detailsBuffer.isNotEmpty)
                  Text(
                    detailsBuffer.toString(),
                    style: t.textTheme.bodySmall?.copyWith(
                      color: t.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                if (pathLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      pathLabel,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: t.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
