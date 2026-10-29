import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/widgets/fade_slide_in.dart';

void main() {
  Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(body: child),
        ),
      );

  double opacity(WidgetTester tester) {
    final fade = find.descendant(of: find.byType(FadeSlideIn), matching: find.byType(FadeTransition));
    return tester.widget<FadeTransition>(fade).opacity.value;
  }

  testWidgets('starts hidden, fades in and settles', (tester) async {
    await tester.pumpWidget(host(const FadeSlideIn(child: Text('Hola'))));

    expect(find.text('Hola'), findsOneWidget);
    expect(opacity(tester), 0);

    await tester.pump(const Duration(milliseconds: 150));
    expect(opacity(tester), inExclusiveRange(0, 1));

    await tester.pumpAndSettle();
    expect(opacity(tester), 1);
  });

  testWidgets('waits for its delay before appearing (staggered lists)', (tester) async {
    await tester.pumpWidget(
      host(const FadeSlideIn(delay: Duration(milliseconds: 200), child: Text('Hola'))),
    );

    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(tester), 0);

    await tester.pumpAndSettle();
    expect(opacity(tester), 1);
  });

  testWidgets('shows the child at once when the system reduces animations', (tester) async {
    await tester.pumpWidget(host(const FadeSlideIn(child: Text('Hola')), reduceMotion: true));

    expect(
        find.descendant(of: find.byType(FadeSlideIn), matching: find.byType(FadeTransition)), findsNothing);
    expect(find.text('Hola'), findsOneWidget);
  });

  testWidgets('animate: false shows the child at once', (tester) async {
    await tester.pumpWidget(host(const FadeSlideIn(animate: false, child: Text('Hola'))));

    expect(
        find.descendant(of: find.byType(FadeSlideIn), matching: find.byType(FadeTransition)), findsNothing);
    expect(find.text('Hola'), findsOneWidget);
  });
}
