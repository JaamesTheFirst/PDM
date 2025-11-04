import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../services/location_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MapboxMap? mapboxMap;
  Point? _currentLocation;
  bool _isLoading = true;

  static const _offWhiteSand = Color(0xFFF8F7F4);

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    final position = await LocationService.instance.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _currentLocation = (position != null)
          ? Point(coordinates: Position(position.longitude, position.latitude))
          : null;
      _isLoading = false;
    });
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: _offWhiteSand,
      body: _currentLocation == null
          ? const Center(child: Text('Localização não disponível'))
          : MapWidget(
              onMapCreated: _onMapCreated,
              cameraOptions: CameraOptions(
                center: _currentLocation!,
                zoom: 14.0,
                bearing: 0,
                pitch: 0,
              ),
            ),
    );
  }

  @override
  void dispose() {
    mapboxMap?.dispose();
    super.dispose();
  }
}
