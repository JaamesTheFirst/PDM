import 'package:flutter/material.dart';

import '../widgets/route_options_overlay.dart';

/// Ecrã “casca” que mostra o [RouteOptionsOverlay] em full-screen.
///
/// Útil quando queremos apresentar as opções de rota como uma página
/// completa em vez de overlay dentro do [MapPage].
class RouteOptionsScreen extends StatelessWidget {
  final RouteOptionsArgs args;

  const RouteOptionsScreen({
    super.key,
    required this.args,
  });

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
            filters: args.filters,
          ),
        ),
      ),
    );
  }
}
