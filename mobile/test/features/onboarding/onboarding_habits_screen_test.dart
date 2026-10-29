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

  /// Answers every question, one step at a time (each pick advances by itself).
  Future<void> answerAll(WidgetTester tester) async {
    for (final entry in answersByQuestion.entries) {
      await tester.tap(find.byKey(ValueKey('${entry.key}:${entry.value}')));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('asks one question at a time, starting with sleep', (tester) async {
    await tester.pumpWidget(buildApp(_FakeHabitsService(), _FakeOnboardingService()));
    await tester.pumpAndSettle();

    expect(find.text('Tus hábitos'), findsOneWidget);
    expect(find.text('Pregunta 1 de 9'), findsOneWidget);
    expect(find.text('¿Cuántas horas duermes normalmente?'), findsOneWidget);
    expect(find.text('¿Con qué frecuencia consumes frutas o verduras?'), findsNothing);
  });

  testWidgets('cannot move forward without answering the question', (tester) async {
    await tester.pumpWidget(buildApp(_FakeHabitsService(), _FakeOnboardingService()));
    await tester.pumpAndSettle();

    final next = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Siguiente'));
    expect(next.onPressed, isNull);
  });

  testWidgets('nothing is saved until the end', (tester) async {
    final fakeHabits = _FakeHabitsService();
    final fakeOnboarding = _FakeOnboardingService();
    await tester.pumpWidget(buildApp(fakeHabits, fakeOnboarding));

    await tester.tap(find.byKey(const ValueKey('hours:less_5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('screen_before_bed:never')));
    await tester.pumpAndSettle();

    expect(fakeHabits.capturedAnswers, isNull);
    expect(fakeOnboarding.completeCalled, isFalse);
  });

  testWidgets('submits answers, completes onboarding, and navigates to home', (tester) async {
    final fakeHabits = _FakeHabitsService();
    final fakeOnboarding = _FakeOnboardingService();
    await tester.pumpWidget(buildApp(fakeHabits, fakeOnboarding));

    await answerAll(tester);
    expect(find.text('¡Listo!'), findsOneWidget);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(fakeHabits.capturedAnswers, hasLength(9));
    final sleepAnswer = fakeHabits.capturedAnswers!.firstWhere((a) => a.key == 'hours');
    expect(sleepAnswer.domain, 'sleep');
    expect(sleepAnswer.value, 'less_5');
    expect(fakeOnboarding.completeCalled, isTrue);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('going back and changing an answer submits the new one', (tester) async {
    final fakeHabits = _FakeHabitsService();
    final fakeOnboarding = _FakeOnboardingService();
    await tester.pumpWidget(buildApp(fakeHabits, fakeOnboarding));
    await answerAll(tester);

    for (var i = 0; i < 9; i++) {
      await tester.tap(find.text('Atrás'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Pregunta 1 de 9'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hours:more_8')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
    }
    expect(find.text('¡Listo!'), findsOneWidget);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(fakeHabits.capturedAnswers!.firstWhere((a) => a.key == 'hours').value, 'more_8');
  });

  testWidgets('shows the backend error message when submitting habits fails', (tester) async {
    final fakeHabits = _FakeHabitsService(error: ApiException('Ocurrió un error inesperado.'));
    final fakeOnboarding = _FakeOnboardingService();
    await tester.pumpWidget(buildApp(fakeHabits, fakeOnboarding));

    await answerAll(tester);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(find.text('Ocurrió un error inesperado.'), findsOneWidget);
    expect(fakeOnboarding.completeCalled, isFalse);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('shows the backend error message when completing onboarding fails', (tester) async {
    final fakeHabits = _FakeHabitsService();
    final fakeOnboarding =
        _FakeOnboardingService(error: ApiException('No se pudo completar el onboarding.'));
    await tester.pumpWidget(buildApp(fakeHabits, fakeOnboarding));

    await answerAll(tester);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo completar el onboarding.'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('after a failure the user can try Finalizar again', (tester) async {
    final fakeHabits = _FakeHabitsService(error: ApiException('Ocurrió un error inesperado.'));
    final fakeOnboarding = _FakeOnboardingService();
    await tester.pumpWidget(buildApp(fakeHabits, fakeOnboarding));
    await answerAll(tester);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    fakeHabits.error = null;
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Ocurrió un error inesperado.'), findsNothing);
  });
}
