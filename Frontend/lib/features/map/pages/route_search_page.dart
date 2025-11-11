import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;

import '../../../services/location_service.dart';
import '../../../services/mapbox_geocoding_service.dart';

class RouteSearchPage extends StatefulWidget {
  const RouteSearchPage({super.key});

  @override
  State<RouteSearchPage> createState() => _RouteSearchPageState();
}

class _RouteSearchPageState extends State<RouteSearchPage> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();

  static const _ecoMint = Color(0xFF3CD4A0);
  static const _offWhiteSand = Color(0xFFF8F7F4);
  static const _destRed = Color(0xFFE53935);

  mbx.MapboxMap? _mapboxMap;
  mbx.Point? _userLocation;

  // user indicator (igual à MapPage)
  mbx.CircleAnnotationManager? _userCircleManager;
  mbx.CircleAnnotation? _userCircle;
  mbx.CircleAnnotation? _userHalo;

  // destino
  mbx.CircleAnnotationManager? _destCircleManager;
  mbx.CircleAnnotation? _destCircle;

  final List<MapboxPlace> _searchResults = [];
  MapboxPlace? _selectedPlace;
  bool _isSearching = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _fromController.dispose();
    _toController.dispose();
    _userCircleManager?.deleteAll();
    _destCircleManager?.deleteAll();
    _mapboxMap?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // INIT: localização + rua atual
  // ---------------------------------------------------------------------------

  Future<void> _init() async {
    final ok = await LocationService.instance.checkPermissions();
    if (!mounted) return;
    if (!ok) {
      _fromController.text = 'Localização atual';
      return;
    }

    final pos = await LocationService.instance.getCurrentLocation();
    if (!mounted || pos == null) {
      _fromController.text = 'Localização atual';
      return;
    }

    final pt = mbx.Point(
      coordinates: mbx.Position(pos.longitude, pos.latitude),
    );

    setState(() {
      _userLocation = pt;
    });

    // rua atual (reverse geocode)
    final place = await MapboxGeocodingService.instance
        .reverseGeocode(pos.longitude, pos.latitude);

    if (!mounted) return;

    _fromController.text =
        place?.placeName ?? place?.name ?? 'Localização atual';

    if (_mapboxMap != null) {
      await _mapboxMap!.setCamera(
        mbx.CameraOptions(center: _userLocation, zoom: 15),
      );
      await _ensureUserIndicator();
    }
  }

  // ---------------------------------------------------------------------------
  // MAPBOX MAP
  // ---------------------------------------------------------------------------

  Future<void> _onMapCreated(mbx.MapboxMap map) async {
    _mapboxMap = map;

    await _mapboxMap!.location
        .updateSettings(mbx.LocationComponentSettings(enabled: false));

    if (_userLocation != null) {
      await _mapboxMap!.setCamera(
        mbx.CameraOptions(center: _userLocation, zoom: 15),
      );
      await _ensureUserIndicator();
    } else {
      await _mapboxMap!.setCamera(
        mbx.CameraOptions(
          center: mbx.Point(
            coordinates: mbx.Position(-9.142685, 38.736946), // Lisboa fallback
          ),
          zoom: 12.5,
        ),
      );
    }
  }

  Future<void> _ensureUserIndicator() async {
    if (_mapboxMap == null || _userLocation == null) return;

    _userCircleManager ??=
        await _mapboxMap!.annotations.createCircleAnnotationManager();

    // evitar warning de withOpacity: usamos alpha manual
    final haloColor =
        _ecoMint.withAlpha((0.25 * 255).round()).value;

    _userHalo ??= await _userCircleManager!.create(
      mbx.CircleAnnotationOptions(
        geometry: _userLocation!,
        circleRadius: 22.0,
        circleColor: haloColor,
        circleStrokeWidth: 0,
        circleOpacity: 1.0,
      ),
    );

    _userCircle ??= await _userCircleManager!.create(
      mbx.CircleAnnotationOptions(
        geometry: _userLocation!,
        circleRadius: 8.0,
        circleColor: _ecoMint.value,
        circleStrokeColor: 0xFFFFFFFF,
        circleStrokeWidth: 2.5,
        circleOpacity: 1.0,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SEARCH AS YOU TYPE (destino)
  // ---------------------------------------------------------------------------

  void _onToChanged(String value) {
    _selectedPlace = null;
    _debounce?.cancel();

    if (value.trim().length < 3) {
      setState(() {
        _searchResults.clear();
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _isSearching = true);

      final results = await MapboxGeocodingService.instance.searchPlaces(
        value,
        proximityLon: _userLocation != null
            ? _userLocation!.coordinates.lng.toDouble()
            : null,
        proximityLat: _userLocation != null
            ? _userLocation!.coordinates.lat.toDouble()
            : null,
      );

      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _searchResults
          ..clear()
          ..addAll(results);
      });
    });
  }

  Future<void> _setDestination(MapboxPlace place) async {
    _selectedPlace = place;
    _toController.text = place.name;

    if (_mapboxMap == null) return;

    final pt = mbx.Point(
      coordinates: mbx.Position(place.longitude, place.latitude),
    );

    _destCircleManager ??=
        await _mapboxMap!.annotations.createCircleAnnotationManager();

    _destCircle ??= await _destCircleManager!.create(
      mbx.CircleAnnotationOptions(
        geometry: pt,
        circleRadius: 11,
        circleColor: _destRed.value,
        circleStrokeColor: 0xFFFFFFFF,
        circleStrokeWidth: 2.5,
        circleOpacity: 1.0,
      ),
    );

    _destCircle!.geometry = pt;
    await _destCircleManager!.update(_destCircle!);

    await _mapboxMap!.flyTo(
      mbx.CameraOptions(center: pt, zoom: 16, pitch: 0, bearing: 0),
      mbx.MapAnimationOptions(duration: 1200),
    );
  }

  void _onConfirm() {
    // Mais tarde -> Navigator.pop(context, _selectedPlace);
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final panelColor = isDark ? t.colorScheme.surface : _offWhiteSand;

    return Scaffold(
      backgroundColor: t.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // MAPA -------------------------------------------------------------
          Positioned.fill(
            child: mbx.MapWidget(
              onMapCreated: _onMapCreated,
            ),
          ),

          // TOP BAR ----------------------------------------------------------
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 10, right: 16),
              child: Row(
                children: [
                  _RoundedIconButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Planear trajeto',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: t.colorScheme.onBackground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Define a origem e o destino',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: t.colorScheme.onBackground.withOpacity(.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // PAINEL EM BAIXO --------------------------------------------------
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(
                minHeight: 260,
                maxHeight: 480,
              ),
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 24,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.colorScheme.onSurface.withOpacity(.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // CARD ORIGEM/DESTINO --------------------------------------
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
                            readOnly: true,
                            badgeText: 'Atual',
                          ),
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          _LocationRow(
                            label: 'Para',
                            controller: _toController,
                            icon: Icons.place_outlined,
                            hintText: 'Para onde?',
                            autoFocus: true,
                            onChanged: _onToChanged,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // RESULTADOS + BOTÃO ---------------------------------------
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isSearching)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'A procurar lugares...',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      color: t.colorScheme.onBackground
                                          .withOpacity(.7),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Text(
                              _searchResults.isEmpty
                                  ? 'Sugestões'
                                  : 'Resultados',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: t.colorScheme.onBackground,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _searchResults.isEmpty
                                ? ListView(
                                    children: const [
                                      ListTile(
                                        leading: Icon(Icons.place_outlined),
                                        title: Text(
                                          'Começa a escrever uma rua',
                                        ),
                                        subtitle: Text(
                                          'Vamos mostrar-te sugestões em tempo real',
                                        ),
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    itemCount: _searchResults.length,
                                    itemBuilder: (context, index) {
                                      final place =
                                          _searchResults[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 8.0),
                                        child: _ResultTile(
                                          title: place.name,
                                          subtitle: place.placeName,
                                          onTap: () =>
                                              _setDestination(place),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _ecoMint,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                elevation: 3,
                              ),
                              onPressed:
                                  _selectedPlace == null ? null : _onConfirm,
                              child: const Text(
                                'Confirmar trajeto',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WIDGETS DE APOIO
// ---------------------------------------------------------------------------

class _RoundedIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundedIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: t.cardColor.withOpacity(.96),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: t.colorScheme.onSurface),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String? hintText;
  final String? badgeText;
  final bool autoFocus;
  final bool readOnly;
  final ValueChanged<String>? onChanged;

  const _LocationRow({
    required this.label,
    required this.controller,
    required this.icon,
    this.hintText,
    this.badgeText,
    this.autoFocus = false,
    this.readOnly = false,
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
                autofocus: autoFocus,
                readOnly: readOnly,
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
        if (badgeText != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: t.colorScheme.primary.withOpacity(.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badgeText!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: t.colorScheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ResultTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Material(
      color: t.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                ),
                child:
                    Icon(Icons.place_outlined, color: t.colorScheme.onSurface),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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
