import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;

import '../../../../services/mapbox_directions_service.dart';
import '../../../../services/mapbox_searchbox_service.dart';

/// ============= ARGS =============
class RouteOptionsArgs {
  final mbx.MapboxMap mapboxMap;
  final SearchboxPlace from;
  final SearchboxPlace to;
  RouteOptionsArgs({
    required this.mapboxMap,
    required this.from,
    required this.to,
  });
}

class RouteOptionsOverlay extends StatefulWidget {
  final mbx.MapboxMap mapboxMap;
  final SearchboxPlace from;
  final SearchboxPlace to;
  final VoidCallback onClose;

  const RouteOptionsOverlay({
    super.key,
    required this.mapboxMap,
    required this.from,
    required this.to,
    required this.onClose,
  });

  @override
  State<RouteOptionsOverlay> createState() => _RouteOptionsOverlayState();
}

class _RouteData {
  final List<List<num>> geometry;
  final double distance; // m
  final double duration; // s
  _RouteData({required this.geometry, required this.distance, required this.duration});
}

class _RouteOptionsOverlayState extends State<RouteOptionsOverlay> {
  static const _ecoMint = Color(0xFF3CD4A0);

  // desenho no mapa
  mbx.PolylineAnnotationManager? _lineMgr;
  mbx.PolylineAnnotation? _routeLine;
  mbx.CircleAnnotationManager? _poiMgr;
  mbx.CircleAnnotation? _fromDot;
  mbx.CircleAnnotation? _toDot;

  // estado de modo
  String _selected = 'walking';
  bool _loading = false;

  // cache de rotas por modo
  final Map<String, _RouteData> _cache = {};

  /// quanto o painel está "colapsado".
  /// 0 = expandido ao máximo; valor maior = painel mais baixo (mais mapa visível em cima).
  double _collapse = 0.0;

  /// Percentagem do colapso a partir da qual fazemos snap para o modo compacto
  static const double _snapThresholdRatio = 0.55;

  @override
  void initState() {
    super.initState();
    _ensureDots();
    _selectMode('walking', draw: true);
  }

  @override
  void dispose() {
    // mantemos anotações no mapa ao fechar
    super.dispose();
  }

  Future<void> _ensureDots() async {
    _poiMgr ??= await widget.mapboxMap.annotations.createCircleAnnotationManager();
    try {
      await _poiMgr!.deleteAll();
    } catch (_) {}
    _fromDot = await _poiMgr!.create(
      mbx.CircleAnnotationOptions(
        geometry: mbx.Point(
          coordinates: mbx.Position(widget.from.longitude, widget.from.latitude),
        ),
        circleRadius: 7,
        circleColor: 0xFF1C1C1C,
        circleStrokeColor: 0xFFFFFFFF,
        circleStrokeWidth: 2,
      ),
    );
    _toDot = await _poiMgr!.create(
      mbx.CircleAnnotationOptions(
        geometry: mbx.Point(
          coordinates: mbx.Position(widget.to.longitude, widget.to.latitude),
        ),
        circleRadius: 7,
        circleColor: _ecoMint.value,
        circleStrokeColor: 0xFFFFFFFF,
        circleStrokeWidth: 2,
      ),
    );
  }

  /// Ajusta a câmara para encaixar a geometria da rota (mostra De + Para).
  Future<void> _fitRouteGeometry(List<List<num>> geometry) async {
    if (geometry.isEmpty) return;

    final points = geometry
        .map(
          (c) => mbx.Point(
            coordinates: mbx.Position(
              (c[0]).toDouble(),
              (c[1]).toDouble(),
            ),
          ),
        )
        .toList();

    final padding = mbx.MbxEdgeInsets(
      top: 40,
      left: 40,
      right: 40,
      bottom: 40,
    );

    try {
      final cam = await widget.mapboxMap.cameraForCoordinates(
        points,
        padding,
        0,
        0,
      );
      await widget.mapboxMap.flyTo(
        cam,
        mbx.MapAnimationOptions(duration: 900),
      );
    } catch (_) {}
  }

  Future<void> _selectMode(String mode, {bool draw = false}) async {
    setState(() {
      _selected = mode;
      _loading = true;
    });

    _RouteData data;
    if (_cache.containsKey(mode)) {
      data = _cache[mode]!;
    } else {
      final profile = (mode == 'scooter' || mode == 'bike_share' || mode == 'scooter_share')
          ? 'cycling'
          : (mode == 'taxi' ? 'driving' : mode);
      final r = await MapboxDirectionsService.instance.getRoute(
        fromLon: widget.from.longitude,
        fromLat: widget.from.latitude,
        toLon: widget.to.longitude,
        toLat: widget.to.latitude,
        profile: profile,
      );
      if (r == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }
      data = _RouteData(
        geometry: r.geometry,
        distance: r.distance.toDouble(),
        duration: r.duration.toDouble(),
      );
      _cache[mode] = data;
    }

    if (draw) {
      await _drawRoute(data);
      await _fitRouteGeometry(data.geometry);
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _drawRoute(_RouteData route) async {
    _lineMgr ??= await widget.mapboxMap.annotations.createPolylineAnnotationManager();
    try {
      if (_routeLine != null) await _lineMgr!.delete(_routeLine!);
    } catch (_) {}
    _routeLine = await _lineMgr!.create(
      mbx.PolylineAnnotationOptions(
        geometry: mbx.LineString(
          coordinates: route.geometry
              .map((c) => mbx.Position((c[0]).toDouble(), (c[1]).toDouble()))
              .toList(),
        ),
        lineColor: _ecoMint.value,
        lineWidth: 5.0,
      ),
    );
  }

  String _fmt(double meters) =>
      meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(1)} km';
  String _fmtDur(double seconds) => '${(seconds / 60).round()} min';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final media = MediaQuery.of(context);
    final bottomInset = media.padding.bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;

        // altura mínima do painel (header + 1 modo + botões)
        const double minPanelHeight = 230.0;

        // altura máxima (painel quase cheio)
        final double maxPanelHeight = maxH;

        // quanto é que o painel pode "colapsar" no máximo
        final double maxCollapse = (maxPanelHeight - minPanelHeight).clamp(0.0, maxH);

        // aplica clamp ao _collapse
        final double effectiveCollapse = _collapse.clamp(0.0, maxCollapse);

        final double panelHeight = maxPanelHeight - effectiveCollapse;

        // limiar real em px para snap + "modo compacto"
        final double snapThreshold = maxCollapse * _snapThresholdRatio;

        // modos disponíveis
        final modes = <_ModeCard>[
          _ModeCard(
            keyId: 'walking',
            title: 'Caminhar',
            icon: Icons.directions_walk,
            badge: 'Eco',
          ),
          _ModeCard(
            keyId: 'cycling',
            title: 'Bicicleta',
            icon: Icons.directions_bike,
          ),
          _ModeCard(
            keyId: 'scooter',
            title: 'Scooter',
            icon: Icons.electric_scooter,
          ),
          _ModeCard(
            keyId: 'bike_share',
            title: 'Bicicleta (partilha)',
            icon: Icons.pedal_bike,
          ),
          _ModeCard(
            keyId: 'scooter_share',
            title: 'Scooter (partilha)',
            icon: Icons.two_wheeler,
          ),
          _ModeCard(
            keyId: 'taxi',
            title: 'Táxi',
            icon: Icons.local_taxi,
          ),
          _ModeCard(
            keyId: 'driving',
            title: 'Carro',
            icon: Icons.directions_car,
          ),
          _ModeCard(
            keyId: 'bus_disabled',
            title: 'Autocarro',
            icon: Icons.directions_bus,
            disabled: true,
            note: 'em breve',
          ),
          _ModeCard(
            keyId: 'train_disabled',
            title: 'Comboio',
            icon: Icons.train,
            disabled: true,
            note: 'em breve',
          ),
        ];

        // estamos em modo "compacto"? (quase colapsado)
        final bool isCompact = effectiveCollapse >= snapThreshold && maxCollapse > 0;

        _ModeCard selectedCard =
            modes.firstWhere((m) => _effectiveKeyFor(m) == _selected, orElse: () => modes.first);

        String _subtitleFor(_ModeCard m) {
          final effectiveKey = _effectiveKeyFor(m);
          final isDisabled = m.disabled;
          final cached = _cache[effectiveKey];
          if (isDisabled) return m.note ?? 'indisponível';
          if (cached == null) {
            return (_loading && _selected == effectiveKey) ? 'a calcular…' : '—';
          }
          return '${_fmt(cached.distance)} • ${_fmtDur(cached.duration)}';
        }

        return Container(
          color: Colors.transparent,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: panelHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: t.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 24,
                    offset: Offset(0, -4),
                    color: Color(0x26000000),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset + 12),
                child: Column(
                  children: [
                    // handle + drag
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragUpdate: (d) {
                        setState(() {
                          _collapse += d.delta.dy;
                          if (_collapse < 0) _collapse = 0;
                          if (_collapse > maxCollapse) _collapse = maxCollapse;
                        });
                      },
                      onVerticalDragEnd: (_) {
                        // SNAP: decide se fica expandido ou compacto
                        if (maxCollapse <= 0) return;
                        setState(() {
                          if (_collapse < snapThreshold) {
                            _collapse = 0; // expandido, mostra lista inteira
                          } else {
                            _collapse = maxCollapse; // compacto, só 1 item
                          }
                        });
                      },
                      child: SizedBox(
                        height: 40,
                        child: Center(
                          child: Container(
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              color: t.colorScheme.onSurface.withOpacity(.25),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // header + fechar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: Row(
                        children: [
                          const Icon(Icons.route, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${widget.from.name} → ${widget.to.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: widget.onClose,
                            icon: const Icon(Icons.close),
                            tooltip: 'Fechar',
                          ),
                        ],
                      ),
                    ),

                    // lista de modos
                    Expanded(
                      child: isCompact
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: _ModeTile(
                                  icon: selectedCard.icon,
                                  title: selectedCard.title,
                                  subtitle: _subtitleFor(selectedCard),
                                  badge: selectedCard.badge,
                                  disabled: selectedCard.disabled,
                                  selected: true,
                                  onTap: selectedCard.disabled
                                      ? null
                                      : () => _selectMode(
                                            _effectiveKeyFor(selectedCard),
                                            draw: true,
                                          ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemBuilder: (_, i) {
                                final m = modes[i];
                                final isDisabled = m.disabled;
                                final effectiveKey = _effectiveKeyFor(m);
                                final isSelected = _selected == effectiveKey;
                                final subtitle = _subtitleFor(m);
                                return _ModeTile(
                                  icon: m.icon,
                                  title: m.title,
                                  subtitle: subtitle,
                                  badge: m.badge,
                                  disabled: isDisabled,
                                  selected: isSelected,
                                  onTap: isDisabled
                                      ? null
                                      : () async =>
                                          _selectMode(effectiveKey, draw: true),
                                );
                              },
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemCount: modes.length,
                            ),
                    ),

                    // ações no fundo
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: widget.onClose,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: t.colorScheme.onSurface,
                                side: BorderSide(
                                  color: t.colorScheme.onSurface.withOpacity(.2),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              child: const Text('Fechar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: widget.onClose,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _ecoMint,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              child: const Text(
                                'Aplicar & fechar',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
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
        );
      },
    );
  }

  String _effectiveKeyFor(_ModeCard m) {
    return m.keyId.endsWith('_disabled')
        ? m.keyId.replaceAll('_disabled', '')
        : m.keyId;
  }
}

class _ModeCard {
  final String keyId;
  final String title;
  final IconData icon;
  final bool disabled;
  final String? badge;
  final String? note;
  _ModeCard({
    required this.keyId,
    required this.title,
    required this.icon,
    this.disabled = false,
    this.badge,
    this.note,
  });
}

class _ModeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool disabled;
  final bool selected;
  final String? badge;
  final VoidCallback? onTap;

  const _ModeTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.disabled = false,
    this.selected = false,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final baseColor = disabled
        ? t.colorScheme.onSurface.withOpacity(.12)
        : (selected
            ? t.colorScheme.primary.withOpacity(.12)
            : t.cardColor);

    return Material(
      color: baseColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: disabled
                    ? t.colorScheme.onSurface.withOpacity(.4)
                    : t.colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: disabled
                                  ? t.colorScheme.onSurface.withOpacity(.5)
                                  : t.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3CD4A0),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (selected) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.check_circle,
                            size: 20,
                            color: t.colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: t.colorScheme.onSurface.withOpacity(.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
