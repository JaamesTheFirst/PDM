import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;

import '../widgets/route_search_overlay.dart';
import '../widgets/route_options_overlay.dart'; // RouteOptionsArgs

class RouteSearchScreenArgs {
  final mbx.MapboxMap mapboxMap;
  final mbx.Point userLocation;
  RouteSearchScreenArgs({required this.mapboxMap, required this.userLocation});
}

class RouteSearchScreen extends StatelessWidget {
  final RouteSearchScreenArgs args;
  const RouteSearchScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        bottom: false,
        child: SizedBox.expand(
          child: RouteSearchOverlay(
            mapboxMap: args.mapboxMap,
            userLocation: args.userLocation,
            onClose: () => Navigator.of(context).pop(),
            onConfirmOptions: (opts) => Navigator.of(context).pop(opts),
          ),
        ),
      ),
    );
  }
}
