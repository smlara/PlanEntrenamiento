// Smoke test basico: la app arranca y muestra el titulo.
import 'package:flutter_test/flutter_test.dart';

import 'package:plan_entrenamiento/main.dart';

void main() {
  testWidgets('La app arranca', (WidgetTester tester) async {
    await tester.pumpWidget(const PlanEntrenamientoApp());
    await tester.pump();
    expect(find.text('Plan de Entrenamiento'), findsOneWidget);
  });
}
