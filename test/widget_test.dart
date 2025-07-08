// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:medidor_app/main.dart'; // Asegúrate de que el nombre del paquete coincida

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    // Construimos nuestra app y verificamos que no falle.
    await tester.pumpWidget(const PresionArterialApp());

    // Verificamos que el título principal de la app esté presente en la pantalla de inicio.
    expect(find.text('Mi Cardio\nSoluciones'), findsOneWidget);
  });
}
