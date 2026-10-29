import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/widgets/habitq_card.dart';

void main() {
  Widget host(Widget card) => MaterialApp(home: Scaffold(body: Center(child: card)));

  double scaleOf(WidgetTester tester) =>
      tester.widget<AnimatedScale>(find.descendant(of: find.byType(HabitQCard), matching: find.byType(AnimatedScale))).scale;

  testWidgets('a tappable card shrinks a little while pressed and recovers', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(HabitQCard(onTap: () => taps++, child: const Text('Tarjeta'))));
    expect(scaleOf(tester), 1);

    final gesture = await tester.startGesture(tester.getCenter(find.text('Tarjeta')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(scaleOf(tester), lessThan(1));
    expect(scaleOf(tester), greaterThan(0.9));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(scaleOf(tester), 1);
    expect(taps, 1);
  });

  testWidgets('a card without onTap never scales', (tester) async {
    await tester.pumpWidget(host(const HabitQCard(child: Text('Tarjeta'))));

    final gesture = await tester.startGesture(tester.getCenter(find.text('Tarjeta')));
    await tester.pump(const Duration(milliseconds: 120));

    expect(scaleOf(tester), 1);
    await gesture.up();
  });

  testWidgets('is isolated for repainting so lists scroll smoothly', (tester) async {
    await tester.pumpWidget(host(const HabitQCard(child: Text('Tarjeta'))));

    expect(
      find.descendant(of: find.byType(HabitQCard), matching: find.byType(RepaintBoundary)),
      findsWidgets,
    );
  });
}
