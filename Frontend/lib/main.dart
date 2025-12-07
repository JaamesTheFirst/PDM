import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'features/auth/state/auth_controller.dart';
import 'app/state/theme_controller.dart';
import 'app/app_shell.dart';
import 'app/app_router.dart';
import 'mapbox_config.dart';
import 'features/map/state/otp_routes_controller.dart';
import 'features/map/state/navigation_controller.dart';
import 'services/routes_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    MapboxOptions.setAccessToken(kMapboxAccessToken); // MapBox token
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(
          create: (_) => OtpRoutesController(RoutesService()),
        ),
        ChangeNotifierProvider(
          create: (_) => NavigationController(RoutesService()),
        ),
      ],
      child: const EcoApp(),
    ),
  );
}

class EcoApp extends StatelessWidget {
  const EcoApp({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    return MaterialApp(
      title: 'EcoMove',
      theme: theme.lightTheme,
      darkTheme: theme.darkTheme,
      themeMode: theme.themeMode, // DARK por defeito
      debugShowCheckedModeBanner: false,
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: '/',
    );
  }
}
