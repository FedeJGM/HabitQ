import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/widgets/animated_count.dart';

void main() {
  Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(body: child),
        ),
      );

  Widget count(int value) => AnimatedCount(value: value, builder: (context, n) => Text('Hoy: $n'));

  testWidgets('counts up from zero to its value and settles', (tester) async {
    await tester.pumpWidget(host(count(8)));

    expect(find.text('Hoy: 0'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    final mid = int.parse(RegExp(r'\d+').firstMatch(
      tester.widget<Text>(find.textContaining('Hoy:')).data!,
    )!.group(0)!);
    expect(mid, inExclusiveRange(0, 8));

    await tester.pumpAndSettle();
    expect(find.text('Hoy: 8'), findsOneWidget);
  });

  testWidgets('when the value changes it continues from where it was', (tester) async {
    await tester.pumpWidget(host(count(4)));
    await tester.pumpAndSettle();

    await tester.pumpWidget(host(count(6)));
    await tester.pumpAndSettle();

    expect(find.text('Hoy: 6'), findsOneWidget);
  });

  testWidgets('with reduced motion it shows the final value at once', (tester) async {
    await tester.pumpWidget(host(count(8), reduceMotion: true));

    expect(find.text('Hoy: 8'), findsOneWidget);
  });

  testWidgets('a zero value stays zero without animating', (tester) async {
    await tester.pumpWidget(host(count(0)));

    expect(find.text('Hoy: 0'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Hoy: 0'), findsOneWidget);
  });
}
