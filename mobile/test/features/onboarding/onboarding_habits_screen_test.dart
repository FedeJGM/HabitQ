import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app_routes.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/features/habits/habits_service.dart';
import 'package:mobile/features/onboarding/onboarding_habits_screen.dart';
import 'package:mobile/features/onboarding/onboarding_service.dart';

class _FakeHabitsService implements HabitsService {
  _FakeHabitsService({this.error});

  ApiException? error;
  List<HabitAnswer>? capturedAnswers;

  @override
  Future<void> submitAnswers(List<HabitAnswer> answers) async {
    capturedAnswers = answers;
    if (error != null) throw error!;
  }

  @override
  Future<List<HabitRecord>> fetchHabits() {
    throw UnimplementedError();
  }

  @override
  Future<HabitRecord> updateHabit({
    required String id,
    required String domain,
    required String key,
    required String value,
  }) {
    throw UnimplementedError();
  }
}

class _FakeOnboardingService implements OnboardingService {
  _FakeOnboardingService({this.error});

  ApiException? error;
  bool completeCalled = false;

  @override
  Future<void> completeOnboarding() async {
    completeCalled = true;
    if (error != null) throw error!;
  }
}

void main() {
  Widget buildApp(HabitsService habitsService, OnboardingService onboardingService) {
    return MaterialApp(
      routes: {
        AppRoutes.home: (_) => const Scaffold(body: Text('Home')),
      },
      home: OnboardingHabitsScreen(
        habitsService: habitsService,
        onboardingService: onboardingService,
      ),
    );
  }

  const answersByQuestion = {
    'hours': 'less_5',
    'screen_before_bed': 'never',
    'fruits_vegetables': 'rarely',
    'fast_food': 'rarely',
    'days_per_week': '0',
    'sedentary_hours': 'yes',
    'daily_intake': 'low',
    'recreational_hours': 'less_2h',
    'frequency': 'rarely',
  };

  // The questionnaire is taller than the test viewport, so each target must
  // be scrolled into view before tapping it.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> answerAll(WidgetTester tester) async {
    for (final entry in answersByQuestion.entries) {
      await tapVisible(tester, find.byKey(ValueKey('${entry.key}:${entry.value}')));
    }
  }

  testWidgets('shows a validation message when not all questions are answered', (tester) async {
    final fakeHabits = _FakeHabitsService();
    final fakeOnboarding = _FakeOnboardingService();
    await tester.pumpWidget(buildApp(fakeHabits, fakeOnboarding));

    await tapVisible(tester, find.text('Finalizar'));

    expect(find.text('Responde todas las preguntas para continuar.'), findsOneWidget);
    expect(fakeHabits.capturedAnswers, isNull);
    expect(fakeOnboarding.completeCalled, isFalse);
  });

  testWidgets('submits answers, completes onboarding, and navigates to home', (tester) async {
    final fakeHabits = _FakeHabitsService();
    final fakeOnboarding = _FakeOnboardingService();
    await tester.pumpWidget(buildApp(fakeHabits, fakeOnboarding));

    await answerAll(tester);
    await tapVisible(tester, find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(fakeHabits.capturedAnswers, hasLength(9));
    final sleepAnswer =
        fakeHabits.capturedAnswers!.firstWhere((a) => a.key == 'hours');
    expect(sleepAnswer.domain, 'sleep');
    expect(sleepAnswer.value, 'less_5');
    expect(fakeOnboarding.completeCalled, isTrue);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('shows the backend error message when submitting habits fails', (tester) async {
    final fakeHabits = _FakeHabitsService(error: ApiException('Ocurrió un error inesperado.'));
    final fakeOnboarding = _FakeOnboardingService();
    await tester.pumpWidget(buildApp(fakeHabits, fakeOnboarding));

    await answerAll(tester);
    await tapVisible(tester, find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(find.text('Ocurrió un error inesperado.'), findsOneWidget);
    expect(fakeOnboarding.completeCalled, isFalse);
  });

  testWidgets('shows the backend error message when completing onboarding fails', (tester) async {
    final fakeHabits = _FakeHabitsService();
    final fakeOnboarding =
        _FakeOnboardingService(error: ApiException('No se pudo completar el onboarding.'));
    await tester.pumpWidget(buildApp(fakeHabits, fakeOnboarding));

    await answerAll(tester);
    await tapVisible(tester, find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo completar el onboarding.'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });
}
