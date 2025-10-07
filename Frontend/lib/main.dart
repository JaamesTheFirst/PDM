import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/auth_controller.dart';
import 'routes/app_router.dart';

void main() {
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
