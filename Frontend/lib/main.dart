import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'state/auth_controller.dart';
import 'routes/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Mapbox with your token (only for mobile platforms)
  if (kIsWeb == false) {
    MapboxOptions.setAccessToken("aqui tem de meter a api key que vos vou dar no whatsapp");
  }
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthController(),
      child: const EcoApp(),
    ),
  );
}

class EcoApp extends StatelessWidget {
  const EcoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoMove',
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: '/', // AuthGate
      debugShowCheckedModeBanner: false,
    );
  }
}
