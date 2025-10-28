// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sustainable_transport_app/main.dart';

void main() {
  testWidgets('App arranca e mostra a LoginScreen', (WidgetTester tester) async {
    // Se no teu main o widget raiz se chamar EcoApp, troca App -> EcoApp.
    await tester.pumpWidget(const EcoApp());

    // Deixa concluir animações/navegação inicial (AuthGate -> Login)
    await tester.pumpAndSettle();

    // Deve existir o botão "Entrar" e o campo "Email" do nosso login.
    expect(find.byType(ElevatedButton), findsWidgets);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
  });
}
