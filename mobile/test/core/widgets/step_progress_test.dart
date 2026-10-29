import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/widgets/step_progress.dart';

void main() {
  Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(body: child),
        ),
      );

  testWidgets('says which step the user is on', (tester) async {
    await tester.pumpWidget(host(const StepProgress(current: 1, total: 2)));
    await tester.pumpAndSettle();

    expect(find.text('Paso 1 de 2'), findsOneWidget);
  });

  testWidgets('the bar fills in proportion to the step', (tester) async {
    await tester.pumpWidget(host(const StepProgress(current: 1, total: 2)));
    await tester.pumpAndSettle();

    final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.value, 0.5);
  });

  testWidgets('grows smoothly when the step changes, then settles', (tester) async {
    await tester.pumpWidget(host(const StepProgress(current: 1, total: 4)));
    await tester.pumpAndSettle();

    await tester.pumpWidget(host(const StepProgress(current: 3, total: 4)));
    await tester.pump(const Duration(milliseconds: 60));
    final mid = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value!;
    expect(mid, inExclusiveRange(0.25, 0.75));

    await tester.pumpAndSettle();
    expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 0.75);
  });

  testWidgets('with reduced motion it jumps to the final value', (tester) async {
    await tester.pumpWidget(host(const StepProgress(current: 2, total: 2), reduceMotion: true));

    expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 1);
  });

  testWidgets('announces the step to screen readers once', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const StepProgress(current: 1, total: 2)));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Paso 1 de 2'), findsOneWidget);
    handle.dispose();
  });
}
