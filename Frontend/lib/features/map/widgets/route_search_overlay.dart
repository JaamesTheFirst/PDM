import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;

import '../../../../services/mapbox_geocoding_service.dart';
import '../../../../services/mapbox_directions_service.dart';
import '../../../../services/mapbox_searchbox_service.dart';
import '../../../../services/search_history_service.dart';
import './route_options_overlay.dart'; // RouteOptionsArgs

class RouteSearchOverlay extends StatefulWidget {
  final mbx.MapboxMap mapboxMap;
  final mbx.Point userLocation;
  final VoidCallback onClose;

  /// devolve os argumentos para abrir as opções
  final ValueChanged<RouteOptionsArgs> onConfirmOptions;

  const RouteSearchOverlay({
    super.key,
    required this.mapboxMap,
    required this.userLocation,
    required this.onClose,
    required this.onConfirmOptions,
  });

  @override
  State<RouteSearchOverlay> createState() => _RouteSearchOverlayState();
}

enum _ActiveField { from, to }

class _RouteSearchOverlayState extends State<RouteSearchOverlay> {
  // ⬇️ sem heightFactor / drag – o pai controla a altura
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final FocusNode _fromFocus = FocusNode();
  final FocusNode _toFocus = FocusNode();
  _ActiveField _active = _ActiveField.to;

  static const _ecoMint = Color(0xFF3CD4A0);
  static const _offWhiteSand = Color(0xFFF8F7F4);
  static const _destRed = Color(0xFFE53935);

  String _sessionToken = 's_${DateTime.now().millisecondsSinceEpoch}';

  final List<SearchboxSuggestion> _sbSuggestions = [];
  final Map<String, SearchboxPlace> _sbCache = {};
  final List<SearchboxPlace> _nearby = [];

  SearchboxPlace? _selectedTo;
  SearchboxPlace? _selectedFrom;
  bool _isSearching = false;
  bool _isLoadingNearby = false;
  String? _emptyMsg;
  Timer? _debounce;
  int _nearbyGen = 0;

  mbx.CircleAnnotationManager? _circleMgr;
  mbx.PolylineAnnotationManager? _lineMgr;
  mbx.CircleAnnotation? _destCircle;
  mbx.PolylineAnnotation? _routeLine;

  double? _distance;
  double? _duration;
  String _mode = 'walking';

  bool _fromIsCurrent = true;

  final RegExp _zipOnly = RegExp(r'^\d{4}-\d{3}$', caseSensitive: false);
  bool _badName(String s) => s.trim().isEmpty || _zipOnly.hasMatch(s.trim());

  bool _isInPortugalBounds(mbx.Position p) {
    const minLon = -32.0, maxLon = -6.0, minLat = 31.5, maxLat = 42.6;
    final lon = p.lng.toDouble(), lat = p.lat.toDouble();
    return lon >= minLon && lon <= maxLon && lat >= minLat && lat <= maxLat;
  }

  String? _countryIsoFor(mbx.Position p) =>
      _isInPortugalBounds(p) ? 'pt' : null;

  String _formatToField(SearchboxPlace p) {
    final name = p.name.trim();
    final zipAtStart = RegExp(r'^\d{4}-\d{3}\s*', caseSensitive: false);
    String _cleanSeg(String s) {
      var x = s.trim();
      if (_zipOnly.hasMatch(x)) return '';
      x = x.replaceFirst(zipAtStart, '').trim();
      if (x.toLowerCase().startsWith('distrito de ')) return '';
      return x;
    }

    final parts = p.placeName
        .split(',')
        .map(_cleanSeg)
        .where((s) => s.isNotEmpty)
        .toList();

    String? city;
    for (final seg in parts) {
      final low = seg.toLowerCase();
      if (low == 'portugal') continue;
      if (!RegExp(r'\d').hasMatch(seg)) {
        city = seg;
        break;
      }
    }

    final hasPortugal = parts.any((s) => s.toLowerCase() == 'portugal');
    final country = hasPortugal ? 'Portugal' : null;

    final pieces = <String>[];
    if (name.isNotEmpty) pieces.add(name);
    if (city != null &&
        city.isNotEmpty &&
        city.toLowerCase() != name.toLowerCase()) {
      pieces.add(city);
    } else if (city == null || city.isEmpty) {
      final firstAlt = parts.firstWhere(
        (s) =>
            s.toLowerCase() != 'portugal' &&
            s.toLowerCase() != name.toLowerCase(),
        orElse: () => '',
      );
      if (firstAlt.isNotEmpty) pieces.add(firstAlt);
    }
    if (country != null) pieces.add(country);

    return pieces.isNotEmpty
        ? pieces.join(', ')
        : (name.isNotEmpty ? name : p.placeName);
  }

  @override
  void initState() {
    super.initState();
    _resetSession();
    _initFromAddress();
    _fromFocus.addListener(_onFocusChange);
    _toFocus.addListener(_onFocusChange);
    _active = _ActiveField.to;

    final p = widget.userLocation.coordinates;
    MapboxSearchBoxService.instance.debugCheck(
      lon: p.lng.toDouble(),
      lat: p.lat.toDouble(),
    );

    _loadNearbyForActive();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _fromController.dispose();
    _toController.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    _circleMgr?.deleteAll().catchError((_) {});
    _lineMgr?.deleteAll().catchError((_) {});
    _circleMgr = null;
    _lineMgr = null;
    super.dispose();
  }

  void _resetSession() {
    _sessionToken = 's_${DateTime.now().millisecondsSinceEpoch}';
  }

  void _onFocusChange() {
    final newActive = _fromFocus.hasFocus
        ? _ActiveField.from
        : (_toFocus.hasFocus ? _ActiveField.to : _active);
    if (newActive != _active) {
      setState(() {
        _active = newActive;
        _sbSuggestions.clear();
        _sbCache.clear();
        _emptyMsg = null;
      });
      _resetSession();
      _loadNearbyForActive();
    }
  }

  Future<void> _initFromAddress() async {
    final pos = widget.userLocation.coordinates;
    final place = await MapboxGeocodingService.instance.reverseGeocode(
      pos.lng.toDouble(),
      pos.lat.toDouble(),
    );
    if (!mounted) return;
    setState(() {
      _fromController.text = place?.placeName.isNotEmpty == true
          ? place!.placeName
          : 'Localização atual';
      _fromIsCurrent = true;
      _selectedFrom = null;
    });
  }

  Future<void> _loadNearbyForActive() async {
    final myGen = ++_nearbyGen;
    setState(() {
      _isLoadingNearby = true;
      _nearby.clear();
      _emptyMsg = null;
    });

    try {
      final base =
          _active == _ActiveField.from &&
              !_fromIsCurrent &&
              _selectedFrom != null
          ? mbx.Position(_selectedFrom!.longitude, _selectedFrom!.latitude)
          : widget.userLocation.coordinates;

      final iso = _countryIsoFor(base);

      final sb = await MapboxSearchBoxService.instance.nearbyMixedWithFallback(
        lon: base.lng.toDouble(),
        lat: base.lat.toDouble(),
        sessionToken: _sessionToken,
        countryIso2: iso,
        total: 12,
      );

      if (!mounted || myGen != _nearbyGen) return;
      setState(() {
        _nearby.addAll(sb);
        if (_nearby.isEmpty) _emptyMsg = 'Não encontrei POIs/ruas por perto 😕';
      });
    } catch (_) {
      if (!mounted || myGen != _nearbyGen) return;
      setState(
        () => _emptyMsg = 'Não foi possível carregar sugestões perto de ti.',
      );
    } finally {
      if (!mounted || myGen != _nearbyGen) return;
      setState(() => _isLoadingNearby = false);
    }
  }

  void _onChangedActive(String value) {
    _debounce?.cancel();
    setState(() => _emptyMsg = null);

    if (value.trim().length < 2) {
      setState(() {
        _sbSuggestions.clear();
        _sbCache.clear();
      });
      return;
    }

    final ctx = _effectiveContextForSearch();
    final oLon = ctx.lng.toDouble(), oLat = ctx.lat.toDouble();
    final iso = _countryIsoFor(ctx);

    _debounce = Timer(const Duration(milliseconds: 250), () async {
      setState(() {
        _isSearching = true;
        _sbSuggestions.clear();
      });

      final results = await MapboxSearchBoxService.instance.suggest(
        value,
        sessionToken: _sessionToken,
        proximityLon: oLon,
        proximityLat: oLat,
        originLon: oLon,
        originLat: oLat,
        limit: 10,
        countryIso2: iso,
        types: const ['poi', 'address', 'street', 'place'],
      );

      if (!mounted) return;

      if (results.isEmpty) {
        setState(() {
          _isSearching = false;
          _emptyMsg = 'Sem resultados por perto para “$value”.';
        });
        return;
      }

      setState(() {
        _isSearching = false;
        _sbSuggestions.addAll(results);
      });

      _enrichDistances(results, oLon, oLat);
    });
  }

  Future<void> _enrichDistances(
    List<SearchboxSuggestion> results,
    double oLon,
    double oLat,
  ) async {
    final byId = <String, SearchboxSuggestion>{
      for (final s in results) s.mapboxId: s,
    };

    final ids = results.map((s) => s.mapboxId).toList();
    final retrieved = await MapboxSearchBoxService.instance
        .retrieveManyParallel(
          mapboxIds: ids,
          sessionToken: _sessionToken,
          language: 'pt',
        );
    if (!mounted) return;
    setState(() {
      for (final e in retrieved.entries) {
        final r = e.value;
        final sug = byId[e.key];
        final fixedName = _badName(r.name) ? (sug?.name ?? r.name) : r.name;

        _sbCache[e.key] = SearchboxPlace(
          id: r.id,
          name: fixedName,
          placeName: r.placeName,
          longitude: r.longitude,
          latitude: r.latitude,
          featureType: r.featureType,
          category: r.category,
          distanceMeters: MapboxSearchBoxService.haversineMeters(
            oLat,
            oLon,
            r.latitude,
            r.longitude,
          ),
        );
      }
    });
  }

  mbx.Position _effectiveContextForSearch() {
    if (_active == _ActiveField.from) {
      if (_fromIsCurrent || _selectedFrom == null) {
        final p = widget.userLocation.coordinates;
        return mbx.Position(p.lng, p.lat);
      }
      return mbx.Position(_selectedFrom!.longitude, _selectedFrom!.latitude);
    } else {
      final p = widget.userLocation.coordinates;
      return mbx.Position(p.lng, p.lat);
    }
  }

  Future<void> _applySuggestion(SearchboxSuggestion s) async {
    var p = _sbCache[s.mapboxId];
    if (p == null) {
      final r = await MapboxSearchBoxService.instance.retrieve(
        mapboxId: s.mapboxId,
        sessionToken: _sessionToken,
        language: 'pt',
      );
      if (r == null) return;

      final fixedName = _badName(r.name) ? s.name : r.name;
      p = SearchboxPlace(
        id: r.id,
        name: fixedName,
        placeName: r.placeName,
        longitude: r.longitude,
        latitude: r.latitude,
        featureType: r.featureType,
        category: r.category,
        distanceMeters: r.distanceMeters,
      );
    }
    await _applySelection(p);
  }

  Future<void> _applySelection(SearchboxPlace place) async {
    _fromFocus.unfocus();
    _toFocus.unfocus();

    if (_active == _ActiveField.from) {
      setState(() {
        _fromController.text = place.name.isNotEmpty
            ? place.name
            : place.placeName;
        _fromIsCurrent = false;
        _selectedFrom = place;
        _sbSuggestions.clear();
      });
    } else {
      setState(() {
        _toController.text = _formatToField(place);
        _sbSuggestions.clear();
      });
      // Save to search history when destination is selected
      await SearchHistoryService.instance.addDestination(
        address: place.placeName,
        name: place.name.isNotEmpty ? place.name : place.placeName,
        latitude: place.latitude,
        longitude: place.longitude,
      );
      await _setDestination(place);
    }
  }

  Future<void> _setDestination(SearchboxPlace place) async {
    _selectedTo = place;
    final destPoint = mbx.Point(
      coordinates: mbx.Position(place.longitude, place.latitude),
    );

    _circleMgr ??= await widget.mapboxMap.annotations
        .createCircleAnnotationManager();
    if (_destCircle != null) await _circleMgr!.delete(_destCircle!);
    _destCircle = await _circleMgr!.create(
      mbx.CircleAnnotationOptions(
        geometry: destPoint,
        circleRadius: 10,
        circleColor: _destRed.value,
        circleStrokeColor: 0xFFFFFFFF,
        circleStrokeWidth: 2.5,
      ),
    );

    final fromPos = _effectiveFromPosition()!;
    final route = await MapboxDirectionsService.instance.getRoute(
      fromLon: fromPos.lng.toDouble(),
      fromLat: fromPos.lat.toDouble(),
      toLon: place.longitude,
      toLat: place.latitude,
      profile: _mode == 'scooter' ? 'cycling' : _mode,
    );
    if (route == null) return;

    _lineMgr ??= await widget.mapboxMap.annotations
        .createPolylineAnnotationManager();
    if (_routeLine != null) await _lineMgr!.delete(_routeLine!);
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

    setState(() {
      _distance = route.distance.toDouble();
      _duration = route.duration.toDouble();
    });

    await _fitFromTo(fromPos, mbx.Position(place.longitude, place.latitude));
  }

  Future<void> _fitFromTo(mbx.Position a, mbx.Position b) async {
    final center = mbx.Position((a.lng + b.lng) / 2, (a.lat + b.lat) / 2);

    double _haversineKm(num lat1n, num lon1n, num lat2n, num lon2n) {
      final lat1 = lat1n.toDouble();
      final lon1 = lon1n.toDouble();
      final lat2 = lat2n.toDouble();
      final lon2 = lon2n.toDouble();

      const r = 6371.0;
      final dLat = (lat2 - lat1) * (math.pi / 180.0);
      final dLon = (lon2 - lon1) * (math.pi / 180.0);
      final la1 = lat1 * (math.pi / 180.0);
      final la2 = lat2 * (math.pi / 180.0);
      final a_ =
          (math.sin(dLat / 2) * math.sin(dLat / 2)) +
          (math.sin(dLon / 2) * math.sin(dLon / 2)) *
              math.cos(la1) *
              math.cos(la2);
      final c = 2 * math.atan2(math.sqrt(a_), math.sqrt(1 - a_));
      return r * c;
    }

    final km = _haversineKm(a.lat, a.lng, b.lat, b.lng);

    double zoom;
    if (km < 0.5)
      zoom = 15.5;
    else if (km < 1)
      zoom = 15.0;
    else if (km < 2)
      zoom = 14.5;
    else if (km < 5)
      zoom = 13.5;
    else if (km < 10)
      zoom = 12.5;
    else if (km < 20)
      zoom = 11.5;
    else
      zoom = 10.5;

    await widget.mapboxMap.flyTo(
      mbx.CameraOptions(
        center: mbx.Point(coordinates: center),
        zoom: zoom,
      ),
      mbx.MapAnimationOptions(duration: 900),
    );
  }

  mbx.Position? _effectiveFromPosition() {
    if (_fromIsCurrent || _selectedFrom == null) {
      final p = widget.userLocation.coordinates;
      return mbx.Position(p.lng, p.lat);
    }
    return mbx.Position(_selectedFrom!.longitude, _selectedFrom!.latitude);
  }

  void _onConfirm() async {
    if (_selectedTo == null) return;

    try {
      if (_lineMgr != null && _routeLine != null) {
        await _lineMgr!.delete(_routeLine!);
        _routeLine = null;
      }
    } catch (_) {}

    final fromPos = _effectiveFromPosition()!;
    final fromPlace = _fromIsCurrent || _selectedFrom == null
        ? SearchboxPlace(
            id: 'current',
            name: 'Localização atual',
            placeName: _fromController.text.isNotEmpty
                ? _fromController.text
                : 'Localização atual',
            longitude: fromPos.lng.toDouble(),
            latitude: fromPos.lat.toDouble(),
            featureType: 'place',
            category: null,
            distanceMeters: 0,
          )
        : _selectedFrom!;

    widget.onConfirmOptions(
      RouteOptionsArgs(
        mapboxMap: widget.mapboxMap,
        from: fromPlace,
        to: _selectedTo!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final panelColor = isDark ? t.colorScheme.surface : _offWhiteSand;

    final media = MediaQuery.of(context);
    final bottomInset = media.padding.bottom;

    final showingResults = _sbSuggestions.isNotEmpty;

    // ⬇️ sem Transform/drag – o pai (bottom sheet route) decide a altura
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset + 12),
        child: Column(
          children: [
            SizedBox(height: 40),
            // inputs "De" / "Para"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? t.colorScheme.surfaceVariant.withOpacity(.4)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _LocationRow(
                      label: 'De',
                      controller: _fromController,
                      icon: Icons.my_location,
                      readOnly: false,
                      badgeText: _fromIsCurrent ? 'Atual' : null,
                      hintText: 'Origem',
                      focusNode: _fromFocus,
                      onChanged: _onChangedActive,
                      onTap: () => _fromFocus.requestFocus(),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    _LocationRow(
                      label: 'Para',
                      controller: _toController,
                      icon: Icons.place_outlined,
                      hintText: 'Para onde?',
                      readOnly: false,
                      focusNode: _toFocus,
                      onChanged: _onChangedActive,
                      onTap: () => _toFocus.requestFocus(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isSearching)
                      const LinearProgressIndicator(minHeight: 2)
                    else
                      Text(
                        showingResults
                            ? 'Resultados'
                            : (_isLoadingNearby
                                  ? 'A carregar sugestões...'
                                  : 'Sugestões perto de ti'),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: t.colorScheme.onBackground,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: showingResults
                          ? ListView.builder(
                              itemCount: _sbSuggestions.length,
                              itemBuilder: (context, i) {
                                final s = _sbSuggestions[i];

                                String featLabel;
                                switch ((s.featureType ?? '').toLowerCase()) {
                                  case 'poi':
                                    featLabel = 'POI';
                                    break;
                                  case 'street':
                                    featLabel = 'Rua';
                                    break;
                                  case 'address':
                                    featLabel = 'Morada';
                                    break;
                                  default:
                                    featLabel = (s.featureType ?? 'Lugar');
                                }
                                final subtitleBits = <String>[
                                  featLabel,
                                  if (s.category != null &&
                                      s.category!.trim().isNotEmpty)
                                    s.category!,
                                ];
                                final cached = _sbCache[s.mapboxId];
                                final trailing = cached?.distanceMeters != null
                                    ? _formatDistance(cached!.distanceMeters!)
                                    : null;

                                return _ResultTile(
                                  title: s.name,
                                  subtitle:
                                      '${s.placeName} • ${subtitleBits.join(' • ')}',
                                  trailing: trailing,
                                  onTap: () => _applySuggestion(s),
                                );
                              },
                            )
                          : (_isLoadingNearby
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : (_nearby.isEmpty
                                      ? Center(
                                          child: Text(
                                            _emptyMsg ??
                                                'Nada por perto encontrado.',
                                          ),
                                        )
                                      : ListView.builder(
                                          itemCount: _nearby.length,
                                          itemBuilder: (context, i) {
                                            final p = _nearby[i];
                                            return _ResultTile(
                                              title: p.name,
                                              subtitle: _formatSubtitleSB(p),
                                              trailing: _formatDistance(
                                                p.distanceMeters,
                                              ),
                                              onTap: () => _applySelection(p),
                                            );
                                          },
                                        ))),
                    ),
                    const SizedBox(height: 8),

                    if (_distance != null && _duration != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'Distância: ${(_distance! / 1000).toStringAsFixed(1)} km • '
                          'Duração: ${(_duration! / 60).round()} min',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: t.colorScheme.onBackground.withOpacity(.7),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _ecoMint,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            onPressed: widget.onClose,
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _ecoMint,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            onPressed: _selectedTo == null ? null : _onConfirm,
                            child: const Text(
                              'Confirmar',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSubtitleSB(SearchboxPlace p) {
    final bits = <String>[];
    switch ((p.featureType ?? '').toLowerCase()) {
      case 'poi':
        bits.add('POI');
        break;
      case 'street':
        bits.add('Rua');
        break;
      case 'address':
        bits.add('Morada');
        break;
      default:
        if ((p.featureType ?? '').isNotEmpty) bits.add(p.featureType!);
    }
    if (p.category != null && p.category!.isNotEmpty) bits.add(p.category!);
    final meta = bits.join(' • ');
    return meta.isEmpty ? p.placeName : '${p.placeName} • $meta';
  }

  String? _formatDistance(double? d) {
    if (d == null) return null;
    if (d < 1000) return '${d.round()} m';
    return '${(d / 1000).toStringAsFixed(1)} km';
  }
}

// AUX – iguais aos teus
class _LocationRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String? hintText;
  final String? badgeText;
  final bool readOnly;
  final FocusNode? focusNode;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

  const _LocationRow({
    required this.label,
    required this.controller,
    required this.icon,
    this.hintText,
    this.badgeText,
    this.readOnly = false,
    this.focusNode,
    this.onTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 22, color: t.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: t.colorScheme.onSurface.withOpacity(.6),
                ),
              ),
              TextField(
                controller: controller,
                focusNode: focusNode,
                readOnly: readOnly,
                onTap: onTap,
                onChanged: onChanged,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: hintText,
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    color: t.colorScheme.onSurface.withOpacity(.5),
                  ),
                ),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (badgeText != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Color(0xFF3CD4A0),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badgeText!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback onTap;

  const _ResultTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.place_outlined, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
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
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    trailing!,
                    style: TextStyle(
                      fontSize: 12,
                      color: t.colorScheme.onSurface.withOpacity(.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
