import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../services/location_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? mapboxMap;
  Point? _currentLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    final position = await LocationService.instance.getCurrentLocation();
    if (position != null) {
      setState(() {
        _currentLocation = Point(coordinates: Position(position.longitude, position.latitude));
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4), // Eco theme
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F7F4),
        elevation: 0,
        title: const Text(
          'Mapa EcoMove',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Color(0xFF1C1C1C),
          ),
        ),
      ),
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