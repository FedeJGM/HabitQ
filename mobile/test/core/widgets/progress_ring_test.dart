import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/widgets/progress_ring.dart';

void main() {
  Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(body: Center(child: child)),
        ),
      );

  testWidgets('shows its center and describes the progress for screen readers', (tester) async {
    await tester.pumpWidget(
      host(const ProgressRing(value: 0.5, semanticLabel: '2 de 4 tareas', child: Text('2/4'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('2/4'), findsOneWidget);
    expect(find.bySemanticsLabel('2 de 4 tareas'), findsOneWidget);
  });

  testWidgets('animates from empty to its value and then settles', (tester) async {
    await tester.pumpWidget(host(const ProgressRing(value: 0.75, child: SizedBox())));

    double current() => tester.widget<CustomPaint>(find.byKey(const ValueKey('progress-ring-paint'))).painter
        is RingPainter
        ? (tester.widget<CustomPaint>(find.byKey(const ValueKey('progress-ring-paint'))).painter as RingPainter)
            .value
        : -1;

    expect(current(), 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(current(), inExclusiveRange(0, 0.75));
    await tester.pumpAndSettle();
    expect(current(), 0.75);
  });

  testWidgets('with reduced motion it shows the final value right away', (tester) async {
    await tester.pumpWidget(host(const ProgressRing(value: 0.75, child: SizedBox()), reduceMotion: true));

    final painter = tester.widget<CustomPaint>(find.byKey(const ValueKey('progress-ring-paint'))).painter
        as RingPainter;
    expect(painter.value, 0.75);
  });

  testWidgets('clamps values outside 0..1', (tester) async {
    await tester.pumpWidget(host(const ProgressRing(value: 3, child: SizedBox()), reduceMotion: true));

    final painter = tester.widget<CustomPaint>(find.byKey(const ValueKey('progress-ring-paint'))).painter
        as RingPainter;
    expect(painter.value, 1);
  });
}
