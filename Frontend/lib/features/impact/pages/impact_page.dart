// lib/features/impact/pages/impact_page.dart
import 'package:flutter/material.dart';

import '../../../services/impact_service.dart';

class ImpactPage extends StatefulWidget {
  const ImpactPage({super.key});

  @override
  State<ImpactPage> createState() => _ImpactPageState();
}

class _ImpactPageState extends State<ImpactPage> {
  static const _ecoMint = Color(0xFF3CD4A0);
  static const _solarYellow = Color(0xFFFFD166);
  static const _vibrantCoral = Color(0xFFFF6B6B);

  ImpactSummary? _summary;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImpact();
  }

  Future<void> _loadImpact() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final summary = await ImpactService.instance.getWeeklySummary();
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[ImpactPage] Error loading impact: $e');
      setState(() {
        _error = 'Não foi possível carregar o teu impacto ecológico.';
        _isLoading = false;
      });
    }
  }

  String _formatCo2(double kg) {
    // evitar -0 / 0.0000001 etc
    final normalized = kg.abs() < 0.0005 ? 0.0 : kg;

    if (normalized <= 0) return '0 g';
    if (normalized < 1) return '${(normalized * 1000).toStringAsFixed(0)} g';
    return '${normalized.toStringAsFixed(2)} kg';
  }

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).toStringAsFixed(0)} m';
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_ecoMint),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 40, color: t.colorScheme.error),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: t.textTheme.bodyMedium?.copyWith(
                  color: t.colorScheme.onSurface.withOpacity(.8),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadImpact,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final summary = _summary!;
    final hasTrips = summary.hasAnyTrips;

    final double saved =
        summary.totalCo2SavedKg <= 0 ? 0.0 : summary.totalCo2SavedKg;

    final num ecoPercentNum =
        (summary.ecoTripsRatio * 100).clamp(0.0, 100.0);
    final num activePercentNum =
        (summary.activeTripsRatio * 100).clamp(0.0, 100.0);

    final double ecoPercent = ecoPercentNum.toDouble();
    final double activePercent = activePercentNum.toDouble();

    final double ecoGoalProgress =
        (ecoPercent / 100).clamp(0.0, 1.0).toDouble();
    final double activeGoalProgress =
        (activePercent / 30).clamp(0.0, 1.0).toDouble();

    // EcoScore médio: só faz sentido se houver viagens
    final double avgEcoScore = (summary.totalTrips > 0 &&
            !summary.avgEcoScore.isNaN)
        ? summary.avgEcoScore
        : 0.0;

    return RefreshIndicator(
      onRefresh: _loadImpact,
      child: Container(
        color: t.scaffoldBackgroundColor,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // HERO CARD
            _HighlightCard(
              title: hasTrips ? 'Impacto acumulado' : 'Ainda a aquecer ✨',
              subtitle: hasTrips
                  ? 'Face a viajar sempre de carro'
                  : 'Começa a usar modos Eco para acumular impacto',
              // 👇 sem sinal "−"
              value: hasTrips && saved > 0
                  ? '${_formatCo2(saved)} CO₂'
                  : '0 g CO₂',
              icon: Icons.eco,
              color: _ecoMint,
            ),
            const SizedBox(height: 12),

            // CHIP DE PERÍODO (all-time)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: t.colorScheme.primary
                      .withOpacity(t.brightness == Brightness.dark ? .12 : .08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timeline_rounded,
                        size: 14, color: t.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Impacto acumulado',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: t.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // STATS GRID
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Distância total',
                    value: _formatDistance(summary.totalDistanceKm),
                    icon: Icons.directions_walk_rounded,
                    color: _solarYellow,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: hasTrips ? 'Rotas Eco' : 'Viagens concluídas',
                    value: hasTrips
                        ? '${ecoPercent.toStringAsFixed(0)} %'
                        : summary.totalTrips.toString(),
                    icon: hasTrips
                        ? Icons.energy_savings_leaf
                        : Icons.route_rounded,
                    color: _ecoMint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Viagens ativas',
                    value: '${activePercent.toStringAsFixed(0)} %',
                    icon: Icons.directions_run_rounded,
                    color: _vibrantCoral,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: 'EcoScore médio',
                    value: hasTrips && avgEcoScore > 0
                        ? '${avgEcoScore.toStringAsFixed(0)}/100'
                        : '—',
                    icon: Icons.emoji_nature_rounded,
                    color: _ecoMint,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // LISTA DE DIAS OU INFO CARD
            if (summary.days.isNotEmpty) ...[
              Text(
                'Últimos dias',
                style: t.textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  color: t.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ...summary.days.map((d) {
                final ratio =
                    saved > 0 ? (d.totalCo2SavedKg / saved) : 0.0;
                final double intensity =
                    ratio.clamp(0.15, 1.0).toDouble(); // 0.15–1.0

                return _DayRow(
                  date: d.date,
                  trips: d.trips,
                  distanceLabel: _formatDistance(d.totalDistanceKm),
                  savedLabel: _formatCo2(d.totalCo2SavedKg),
                  savedAmountKg: d.totalCo2SavedKg,
                  intensity:
                      d.totalCo2SavedKg > 0 ? intensity : 0.15,
                );
              }).toList(),
              const SizedBox(height: 24),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: t.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: t.brightness == Brightness.dark
                        ? Colors.white10
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.insights_rounded,
                        color: t.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Assim que começares a concluir viagens, '
                        'vais ver aqui o impacto distribuído pelos dias.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: t.colorScheme.onSurface
                              .withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // METAS
            Text(
              'Metas',
              style: t.textTheme.titleLarge?.copyWith(
                fontSize: 18,
                color: t.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            _GoalRow(
              label: '3 dias/semana em modo Eco',
              progress: ecoGoalProgress,
            ),
            const SizedBox(height: 8),
            _GoalRow(
              label: 'Pelo menos 30% das viagens ativas',
              progress: activeGoalProgress,
            ),

            const SizedBox(height: 24),

            // NOTA
            Text(
              'Estimativas com base em distância × fator de emissão. '
              'Os valores comparam as tuas rotas com a hipótese de usar sempre um carro típico.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: t.colorScheme.onSurface.withOpacity(.7),
              ),
            ),
            const SizedBox(height: 12),
            if (!hasTrips)
              Text(
                'Começa a planear e concluir rotas Eco para ver o teu impacto crescer aqui 👣🌱',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: t.colorScheme.primary.withOpacity(.9),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ====== WIDGETS ======

class _HighlightCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final Color color;

  const _HighlightCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          )
        ],
        border: Border.all(
          color: t.brightness == Brightness.dark
              ? Colors.white10
              : const Color(0x143CD4A0),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color.withOpacity(.16),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.textTheme.titleLarge?.copyWith(
                    fontSize: 16,
                    color: t.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: t.colorScheme.onSurface.withOpacity(.7),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 20, // ↓ antes 22
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

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      height: 88,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          )
        ],
        border: Border.all(
          color: t.brightness == Brightness.dark
              ? Colors.white10
              : const Color(0x143CD4A0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withOpacity(.16),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12, // ↓ antes 13
                    color: t.colorScheme.onSurface.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 16, // ↓ antes 18
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

class _GoalRow extends StatelessWidget {
  final String label;
  final double progress;

  const _GoalRow({required this.label, required this.progress});

  static const _ecoMint = Color(0xFF3CD4A0);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: t.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: t.brightness == Brightness.dark
                ? Colors.white12
                : const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation<Color>(_ecoMint),
          ),
        ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  final String date;
  final int trips;
  final String distanceLabel;
  final String savedLabel;
  final double savedAmountKg;
  final double intensity; // 0–1

  const _DayRow({
    required this.date,
    required this.trips,
    required this.distanceLabel,
    required this.savedLabel,
    required this.savedAmountKg,
    required this.intensity,
  });

  String _formatDateShort(String raw) {
    try {
      final dt = DateTime.parse(raw);
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      return '$day/$month';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final brightness = t.brightness;

    final dateLabel = _formatDateShort(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: brightness == Brightness.dark
              ? Colors.white10
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$dateLabel  •  $trips viagens',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: t.colorScheme.onSurface.withOpacity(.85),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              distanceLabel,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: t.colorScheme.onSurface.withOpacity(.75),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              // 👇 sem "−" também aqui
              savedLabel,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: t.colorScheme.onSurface.withOpacity(.9),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: intensity.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: t.brightness == Brightness.dark
                    ? Colors.white10
                    : const Color(0xFFE5E7EB),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF3CD4A0)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
