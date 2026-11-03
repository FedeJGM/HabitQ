import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_motion.dart';

void main() {
  test('durations grow from fast to slow and stay snappy', () {
    expect(AppMotion.fast < AppMotion.medium, isTrue);
    expect(AppMotion.medium < AppMotion.slow, isTrue);
    expect(AppMotion.slow <= const Duration(milliseconds: 400), isTrue);
  });

  testWidgets('reduce is false by default and follows the system setting', (tester) async {
    late bool normal;
    late bool reduced;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(builder: (context) {
          normal = AppMotion.reduce(context);
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Builder(builder: (inner) {
              reduced = AppMotion.reduce(inner);
              return const SizedBox();
            }),
          );
        }),
      ),
    );

    expect(normal, isFalse);
    expect(reduced, isTrue);
  });
}
