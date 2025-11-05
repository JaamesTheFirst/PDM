import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import '../../../services/location_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  mbx.MapboxMap? mapboxMap;
  mbx.Point? _currentLocation;
  bool _isLoading = true;

  mbx.CircleAnnotationManager? _userCircleManager;
  mbx.CircleAnnotation? _userCircle;
  mbx.CircleAnnotation? _userHalo;
  StreamSubscription<Position>? _posSub;

  static const _ecoMint = Color(0xFF3CD4A0);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ok = await LocationService.instance.checkPermissions();
    if (!mounted) return;
    if (!ok) {
      setState(() { _currentLocation = null; _isLoading = false; });
      return;
    }
    final p = await LocationService.instance.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _currentLocation = (p != null) ? mbx.Point(coordinates: mbx.Position(p.longitude, p.latitude)) : null;
      _isLoading = false;
    });
  }

  Future<void> _onMapCreated(mbx.MapboxMap map) async {
    mapboxMap = map;
    await mapboxMap!.location.updateSettings(mbx.LocationComponentSettings(enabled: false));
    await _ensureUserIndicator();

    if (_currentLocation != null) {
      await mapboxMap!.setCamera(mbx.CameraOptions(center: _currentLocation!, zoom: 15));
    }

    _posSub ??= LocationService.instance.getLocationUpdates().listen((pos) async {
      final pt = mbx.Point(coordinates: mbx.Position(pos.longitude, pos.latitude));
      _currentLocation = pt;
      await _updateUserIndicator(pt);
    });
  }

  Future<void> _ensureUserIndicator() async {
    if (mapboxMap == null || _currentLocation == null) return;
    _userCircleManager ??= await mapboxMap!.annotations.createCircleAnnotationManager();

    _userHalo ??= await _userCircleManager!.create(
      mbx.CircleAnnotationOptions(
        geometry: _currentLocation!,
        circleRadius: 22.0,
        circleColor: _ecoMint.withOpacity(0.25).value,
        circleStrokeWidth: 0,
        circleOpacity: 1.0,
      ),
    );

    _userCircle ??= await _userCircleManager!.create(
      mbx.CircleAnnotationOptions(
        geometry: _currentLocation!,
        circleRadius: 8.0,
        circleColor: _ecoMint.value,
        circleStrokeColor: 0xFFFFFFFF,
        circleStrokeWidth: 2.5,
        circleOpacity: 1.0,
      ),
    );
  }

  Future<void> _updateUserIndicator(mbx.Point pt) async {
    if (_userCircleManager == null) return;
    if (_userHalo == null || _userCircle == null) { await _ensureUserIndicator(); return; }
    _userHalo!.geometry = pt;
    _userCircle!.geometry = pt;
    await _userCircleManager!.update(_userHalo!);
    await _userCircleManager!.update(_userCircle!);
  }

  Future<void> _goToUser() async {
    final ok = await LocationService.instance.checkPermissions();
    if (!ok) return;
    final pos = await LocationService.instance.getCurrentLocation();
    if (pos == null || mapboxMap == null) return;

    final target = mbx.Point(coordinates: mbx.Position(pos.longitude, pos.latitude));
    _currentLocation = target;
    await _ensureUserIndicator();

    await mapboxMap!.easeTo(
      mbx.CameraOptions(center: target, zoom: 15, bearing: 0, pitch: 0),
      mbx.MapAnimationOptions(duration: 900),
    );
  }

  void _openPlannerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _PlannerSheetPlaceholder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final double safeBottom = MediaQuery.of(context).padding.bottom;

    final pillBg = t.cardColor.withOpacity(.92);                  // card dark no dark
    final pillIcon = t.colorScheme.onSurface;                     // branco no dark
    final fabBg = t.cardColor;                                    // botão circular fundo card
    final fabFg = _ecoMint;

    return Scaffold(
      backgroundColor: t.scaffoldBackgroundColor,                 // preto no dark
      body: _currentLocation == null
          ? Center(child: Text('Localização não disponível', style: TextStyle(color: t.colorScheme.onSurface)))
          : Stack(
              children: [
                Positioned.fill(
                  child: mbx.MapWidget(
                    onMapCreated: _onMapCreated,
                    cameraOptions: mbx.CameraOptions(
                      center: _currentLocation!,
                      zoom: 14.0,
                      bearing: 0,
                      pitch: 0,
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 10,
                  child: GestureDetector(
                    onTap: _openPlannerSheet,
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 14, offset: Offset(0, 6))],
                        border: Border.all(color: isDark ? Colors.white10 : const Color(0x143CD4A0)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: pillIcon),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Para onde?', style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: pillIcon)),
                          ),
                          Icon(Icons.tune, color: pillIcon),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 88,
                  bottom: 16 + safeBottom,
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _ecoMint,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        elevation: 3,
                      ),
                      onPressed: _openPlannerSheet,
                      icon: const Icon(Icons.add_road, size: 22),
                      label: const Text('Planear trajeto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 16 + safeBottom,
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: FloatingActionButton(
                      heroTag: 'my-location',
                      onPressed: _goToUser,
                      backgroundColor: fabBg,
                      foregroundColor: fabFg,
                      elevation: 3,
                      child: const Icon(Icons.my_location),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _userCircleManager?.deleteAll();
    mapboxMap?.dispose();
    super.dispose();
  }
}

class _PlannerSheetPlaceholder extends StatelessWidget {
  const _PlannerSheetPlaceholder();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 12,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: t.colorScheme.onSurface.withOpacity(.25), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Planear trajeto', style: t.textTheme.titleLarge?.copyWith(fontSize: 18, color: t.colorScheme.onSurface)),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.my_location), labelText: 'De'),
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.place_outlined), labelText: 'Para'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.route),
              label: const Text('Ver rotas'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
