import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/habits/habit_domain_visuals.dart';
import 'package:mobile/features/habits/habit_questions.dart';

void main() {
  test('every domain of the questionnaire has its own visual identity', () {
    for (final section in habitDomainSections) {
      for (final question in section.questions) {
        final visual = DomainVisual.of(question.domain);
        expect(visual.isFallback, isFalse, reason: question.domain);
        expect(visual.particles, isNotEmpty, reason: question.domain);
      }
    }
  });

  test('sleep answers throw floating zzz letters', () {
    final sleep = DomainVisual.of('sleep');

    expect(sleep.motion, BurstMotion.floatUp);
    final letters = sleep.particles.whereType<LetterParticle>().map((p) => p.letter).toSet();
    expect(letters, containsAll(['z', 'Z']));
  });

  test('the six domains do not all move the same way', () {
    final motions = {
      for (final domain in ['sleep', 'nutrition', 'physical_activity', 'hydration', 'screen_time', 'stress'])
        DomainVisual.of(domain).motion,
    };

    expect(motions.length, greaterThanOrEqualTo(3));
  });

  test('hydration falls like drops and physical activity bursts outward', () {
    expect(DomainVisual.of('hydration').motion, BurstMotion.fall);
    expect(DomainVisual.of('physical_activity').motion, BurstMotion.radial);
  });

  test('an unknown domain gets a gentle fallback instead of crashing', () {
    final visual = DomainVisual.of('something_new');

    expect(visual.isFallback, isTrue);
    expect(visual.particles, isNotEmpty);
  });

  test('each domain has a badge icon for the questionnaire header', () {
    final icons = {
      for (final domain in ['sleep', 'nutrition', 'physical_activity', 'hydration', 'screen_time', 'stress'])
        DomainVisual.of(domain).badge,
    };

    expect(icons.length, 6);
  });
}
