import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/widgets/celebration/celebration_overlay.dart';

void main() {
  Widget host(Widget overlay, {bool reduceMotion = false}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: Stack(children: [overlay])),
      ),
    );
  }

  final particles = find.byKey(const ValueKey('firework-particles'));

  testWidgets('paints fireworks and reports when it finishes', (tester) async {
    var finished = 0;
    await tester.pumpWidget(host(CelebrationOverlay(onFinished: () => finished++)));

    await tester.pump(const Duration(milliseconds: 500));
    expect(particles, findsOneWidget);
    expect(finished, 0);

    await tester.pumpAndSettle();
    expect(finished, 1);
  });

  testWidgets('never blocks touches on the screen below', (tester) async {
    await tester.pumpWidget(host(CelebrationOverlay(onFinished: () {})));

    final ignore = find.descendant(
      of: find.byType(CelebrationOverlay),
      matching: find.byType(IgnorePointer),
    );
    expect(ignore, findsWidgets);
    await tester.pumpAndSettle();
  });

  testWidgets('shows the day-complete banner only when the whole day is done', (tester) async {
    await tester.pumpWidget(host(CelebrationOverlay(onFinished: () {})));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('¡Día completo!'), findsNothing);
    await tester.pumpAndSettle();

    await tester.pumpWidget(host(CelebrationOverlay(dayComplete: true, onFinished: () {})));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('¡Día completo!'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('skips the particles when the system asks to reduce animations', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      host(CelebrationOverlay(dayComplete: true, onFinished: () => finished++), reduceMotion: true),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(particles, findsNothing);
    expect(find.text('¡Día completo!'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(finished, 1);
  });

  testWidgets('a single-task burst with reduced motion shows nothing and finishes at once', (tester) async {
    var finished = 0;
    await tester.pumpWidget(host(CelebrationOverlay(onFinished: () => finished++), reduceMotion: true));
    await tester.pumpAndSettle();

    expect(particles, findsNothing);
    expect(finished, 1);
  });
}
