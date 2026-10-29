import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/habits/domain_burst.dart';

void main() {
  Widget host(Widget burst, {bool reduceMotion = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: const Size(400, 800), disableAnimations: reduceMotion),
          child: Scaffold(body: SizedBox.expand(child: burst)),
        ),
      );

  final paint = find.byKey(const ValueKey('domain-burst-paint'));

  testWidgets('plays once from the given point and reports when it ends', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      host(DomainBurst(domain: 'sleep', origin: const Offset(200, 400), onFinished: () => finished++)),
    );

    await tester.pump(const Duration(milliseconds: 300));
    expect(paint, findsOneWidget);
    expect(finished, 0);

    await tester.pumpAndSettle();
    expect(finished, 1);
  });

  testWidgets('never blocks touches', (tester) async {
    await tester.pumpWidget(host(DomainBurst(domain: 'hydration', origin: Offset.zero, onFinished: () {})));

    expect(find.descendant(of: find.byType(DomainBurst), matching: find.byType(IgnorePointer)), findsWidgets);
    await tester.pumpAndSettle();
  });

  testWidgets('works for every domain, including an unknown one', (tester) async {
    for (final domain in ['sleep', 'nutrition', 'physical_activity', 'hydration', 'screen_time', 'stress', 'x']) {
      await tester.pumpWidget(host(DomainBurst(domain: domain, origin: const Offset(100, 100), onFinished: () {})));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: domain);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('with reduced motion it paints nothing and finishes at once', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      host(DomainBurst(domain: 'sleep', origin: Offset.zero, onFinished: () => finished++), reduceMotion: true),
    );
    await tester.pumpAndSettle();

    expect(paint, findsNothing);
    expect(finished, 1);
  });

  testWidgets('is the same layout for the same seed (deterministic particles)', (tester) async {
    var instance = 0;
    Future<List<Offset>> sample(int seed) async {
      // A fresh key each time, so every call builds a brand-new burst.
      await tester.pumpWidget(
        host(
          DomainBurst(
            key: ValueKey('burst-${instance++}'),
            domain: 'nutrition',
            origin: const Offset(200, 400),
            seed: seed,
            onFinished: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final painter = tester.widget<CustomPaint>(paint).painter as BurstPainter;
      final points = painter.debugPositions(0.4);
      await tester.pumpAndSettle();
      return points;
    }

    final a = await sample(1);
    final b = await sample(1);
    final c = await sample(2);

    expect(a, b);
    expect(a, isNot(c));
  });
}
