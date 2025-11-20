import 'package:flutter/material.dart';
import '../widgets/route_options_overlay.dart';

class RouteOptionsScreen extends StatelessWidget {
  final RouteOptionsArgs args;
  const RouteOptionsScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        bottom: false,
        child: SizedBox.expand(
          child: RouteOptionsOverlay(
            mapboxMap: args.mapboxMap,
            from: args.from,
            to: args.to,
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}
