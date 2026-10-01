import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('App starts on the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const HabitQApp());

    expect(find.text('Continúa con Google'), findsOneWidget);
  });

  testWidgets('login shows the welcome copy and no sign-up link', (WidgetTester tester) async {
    await tester.pumpWidget(const HabitQApp());

    expect(find.textContaining('Bienvenido de vuelta', findRichText: true), findsOneWidget);
    expect(find.textContaining('Regístrate', findRichText: true), findsNothing);
    expect(find.textContaining('Registrate', findRichText: true), findsNothing);
  });
}
