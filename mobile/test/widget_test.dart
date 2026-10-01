import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('App starts on the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const HabitQApp());

    expect(find.text('Continúa con Google'), findsOneWidget);
  });
}
