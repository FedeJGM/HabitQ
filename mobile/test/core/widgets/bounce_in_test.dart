import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/widgets/bounce_in.dart';

void main() {
  Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(body: Center(child: child)),
        ),
      );

  double scale(WidgetTester tester) =>
      tester.widget<ScaleTransition>(find.descendant(of: find.byType(BounceIn), matching: find.byType(ScaleTransition))).scale.value;

  testWidgets('starts smaller, overshoots a little and settles at full size', (tester) async {
    await tester.pumpWidget(host(const BounceIn(child: Icon(Icons.home))));

    expect(scale(tester), lessThan(1));

    var biggest = 0.0;
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      biggest = scale(tester) > biggest ? scale(tester) : biggest;
    }
    expect(biggest, greaterThan(1));

    await tester.pumpAndSettle();
    expect(scale(tester), 1);
  });

  testWidgets('shows the child at full size at once with reduced motion', (tester) async {
    await tester.pumpWidget(host(const BounceIn(child: Icon(Icons.home)), reduceMotion: true));

    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(
      find.descendant(of: find.byType(BounceIn), matching: find.byType(ScaleTransition)),
      findsNothing,
    );
  });

  testWidgets('settles: the frame loop ends', (tester) async {
    await tester.pumpWidget(host(const BounceIn(child: Icon(Icons.home))));

    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
