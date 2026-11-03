import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/widgets/decor/background_shapes.dart';

void main() {
  testWidgets('paints static shapes that never intercept touches', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(child: BackgroundShapes()),
              Center(child: TextButton(onPressed: () => taps++, child: const Text('Tocar'))),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('background-shapes')), findsOneWidget);
    expect(find.descendant(of: find.byType(BackgroundShapes), matching: find.byType(IgnorePointer)),
        findsWidgets);

    await tester.tap(find.text('Tocar'));
    expect(taps, 1);

    // Static: no ticker keeps scheduling frames.
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('fits any size without overflowing, including tiny ones', (tester) async {
    for (final size in const [Size(360, 640), Size(800, 1800), Size(10, 10)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: BackgroundShapes())));
      expect(tester.takeException(), isNull);
    }
  });
}
