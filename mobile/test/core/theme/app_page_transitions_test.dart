import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_motion.dart';
import 'package:mobile/core/theme/app_page_transitions.dart';
import 'package:mobile/core/theme/app_theme.dart';

void main() {
  const builder = FadeSlideTransitionsBuilder();
  final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());

  Widget host({bool reduceMotion = false, double progress = 0.5}) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Builder(
          builder: (context) => builder.buildTransitions<void>(
            route,
            context,
            AlwaysStoppedAnimation(progress),
            const AlwaysStoppedAnimation(0),
            const Text('hola'),
          ),
        ),
      ),
    );
  }

  testWidgets('fades and slides the incoming page a short distance', (tester) async {
    await tester.pumpWidget(host());

    expect(find.byType(FadeTransition), findsOneWidget);
    final fade = tester.widget<FadeTransition>(find.byType(FadeTransition));
    expect(fade.opacity.value, greaterThan(0));
    expect(fade.opacity.value, lessThan(1));

    final slide = tester.widget<SlideTransition>(find.byType(SlideTransition));
    expect(slide.position.value.dx, 0);
    expect(slide.position.value.dy, inExclusiveRange(0, 0.05));
  });

  testWidgets('shows the page untouched when the system reduces animations', (tester) async {
    await tester.pumpWidget(host(reduceMotion: true));

    expect(find.byType(FadeTransition), findsNothing);
    expect(find.byType(SlideTransition), findsNothing);
    expect(find.text('hola'), findsOneWidget);
  });

  test('is short and snappy', () {
    expect(builder.transitionDuration, AppMotion.medium);
    expect(builder.reverseTransitionDuration, AppMotion.medium);
  });

  test('the theme uses it on Android', () {
    final builders = AppTheme.light.pageTransitionsTheme.builders;
    expect(builders[TargetPlatform.android], isA<FadeSlideTransitionsBuilder>());
  });
}
