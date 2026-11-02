import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app_routes.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/features/onboarding/onboarding_screen.dart';
import 'package:mobile/features/profile/profile_service.dart';

class _FakeProfileService implements ProfileService {
  _FakeProfileService({this.error});

  ApiException? error;
  int saveCalls = 0;
  String? capturedAgeRange;
  String? capturedMainGoal;
  String? capturedGender;
  int? capturedHeightCm;
  double? capturedWeightKg;

  @override
  Future<UserProfile> saveProfile({
    required String ageRange,
    required String mainGoal,
    String? gender,
    int? heightCm,
    double? weightKg,
  }) async {
    saveCalls++;
    capturedAgeRange = ageRange;
    capturedMainGoal = mainGoal;
    capturedGender = gender;
    capturedHeightCm = heightCm;
    capturedWeightKg = weightKg;
    if (error != null) throw error!;
    return UserProfile(
      id: 'p1',
      userId: 'u1',
      ageRange: ageRange,
      mainGoal: mainGoal,
      gender: gender,
      heightCm: heightCm,
      weightKg: weightKg,
    );
  }

  @override
  Future<UserProfile> getProfile() {
    throw UnimplementedError();
  }
}

void main() {
  Widget buildApp(ProfileService profileService, {bool reduceMotion = false}) {
    return MaterialApp(
      routes: {
        AppRoutes.onboardingHabits: (_) => const Scaffold(body: Text('Habits')),
      },
      home: MediaQuery(
        data: MediaQueryData(size: const Size(400, 800), disableAnimations: reduceMotion),
        child: OnboardingScreen(profileService: profileService),
      ),
    );
  }

  Finder tile(String value) => find.byKey(ValueKey('profile:$value'));
  Finder field(String name) => find.byKey(ValueKey('profile-field:$name'));

  Future<void> pick(WidgetTester tester, String value) async {
    await tester.tap(tile(value));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String name, String text) async {
    await tester.enterText(field(name), text);
    await tester.pump();
  }

  FilledButton button(WidgetTester tester, String label) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

  Future<void> answerUntilGoal(WidgetTester tester) async {
    await pick(tester, 'female');
    await pick(tester, '25-34');
    await enter(tester, 'height', '165');
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    await enter(tester, 'weight', '60,5');
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows which step of the onboarding this is and asks gender first', (tester) async {
    await tester.pumpWidget(buildApp(_FakeProfileService()));
    await tester.pumpAndSettle();

    expect(find.text('Paso 1 de 2'), findsOneWidget);
    expect(find.text('Pregunta 1 de 5'), findsOneWidget);
    expect(find.text('¿Cuál es tu género?'), findsOneWidget);
    expect(tile('female'), findsOneWidget);
    expect(tile('prefer_not_to_say'), findsOneWidget);
    expect(find.text('¿Cuál es tu rango de edad?'), findsNothing);
  });

  testWidgets('cannot go forward or back before answering the first question', (tester) async {
    await tester.pumpWidget(buildApp(_FakeProfileService()));
    await tester.pumpAndSettle();

    expect(button(tester, 'Siguiente').onPressed, isNull);
    final back = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Atrás'));
    expect(back.onPressed, isNull);
  });

  testWidgets('picking an option advances to the next question in order', (tester) async {
    await tester.pumpWidget(buildApp(_FakeProfileService()));
    await tester.pumpAndSettle();

    await pick(tester, 'male');
    expect(find.text('Pregunta 2 de 5'), findsOneWidget);
    expect(find.text('¿Cuál es tu rango de edad?'), findsOneWidget);

    await pick(tester, '35-44');
    expect(find.text('Pregunta 3 de 5'), findsOneWidget);
    expect(find.text('¿Cuánto mides?'), findsOneWidget);
    expect(field('height'), findsOneWidget);
  });

  testWidgets('height must be a whole number between 100 and 250 cm', (tester) async {
    await tester.pumpWidget(buildApp(_FakeProfileService()));
    await tester.pumpAndSettle();
    await pick(tester, 'female');
    await pick(tester, '25-34');

    await enter(tester, 'height', '90');
    expect(button(tester, 'Siguiente').onPressed, isNull);
    expect(find.text('Ingresa una altura entre 100 y 250 cm.'), findsOneWidget);

    await enter(tester, 'height', '170');
    expect(button(tester, 'Siguiente').onPressed, isNotNull);
    expect(find.text('Ingresa una altura entre 100 y 250 cm.'), findsNothing);
  });

  testWidgets('weight must be between 20 and 300 kg', (tester) async {
    await tester.pumpWidget(buildApp(_FakeProfileService()));
    await tester.pumpAndSettle();
    await pick(tester, 'female');
    await pick(tester, '25-34');
    await enter(tester, 'height', '170');
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('¿Cuánto pesas?'), findsOneWidget);
    await enter(tester, 'weight', '10');
    expect(button(tester, 'Siguiente').onPressed, isNull);
    expect(find.text('Ingresa un peso entre 20 y 300 kg.'), findsOneWidget);

    await enter(tester, 'weight', '70');
    expect(button(tester, 'Siguiente').onPressed, isNotNull);
  });

  testWidgets('Atrás returns to the previous question and keeps what was typed', (tester) async {
    await tester.pumpWidget(buildApp(_FakeProfileService()));
    await tester.pumpAndSettle();
    await pick(tester, 'female');
    await pick(tester, '25-34');
    await enter(tester, 'height', '170');
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Atrás'));
    await tester.pumpAndSettle();

    expect(find.text('Pregunta 3 de 5'), findsOneWidget);
    expect(tester.widget<TextField>(field('height')).controller!.text, '170');
  });

  testWidgets('the last question offers Continuar and nothing is saved before it', (tester) async {
    final fakeService = _FakeProfileService();
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    await answerUntilGoal(tester);

    expect(find.text('Pregunta 5 de 5'), findsOneWidget);
    expect(find.text('¿Cuál es tu objetivo principal?'), findsOneWidget);
    expect(find.text('Siguiente'), findsNothing);
    expect(button(tester, 'Continuar').onPressed, isNull);
    expect(fakeService.saveCalls, 0);
  });

  testWidgets('saves the whole profile and navigates to the habit questions on success',
      (tester) async {
    final fakeService = _FakeProfileService();
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();
    await answerUntilGoal(tester);

    await tester.tap(tile('sleep_better'));
    await tester.pumpAndSettle();
    expect(button(tester, 'Continuar').onPressed, isNotNull);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(fakeService.capturedGender, 'female');
    expect(fakeService.capturedAgeRange, '25-34');
    expect(fakeService.capturedHeightCm, 165);
    expect(fakeService.capturedWeightKg, 60.5);
    expect(fakeService.capturedMainGoal, 'sleep_better');
    expect(find.text('Habits'), findsOneWidget);
  });

  testWidgets('shows the backend error message on failure and allows retrying', (tester) async {
    final fakeService = _FakeProfileService(error: ApiException('Ocurrió un error inesperado.'));
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();
    await answerUntilGoal(tester);

    await tester.ensureVisible(tile('manage_stress'));
    await tester.pumpAndSettle();
    await tester.tap(tile('manage_stress'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Ocurrió un error inesperado.'), findsOneWidget);
    expect(find.text('Habits'), findsNothing);

    fakeService.error = null;
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Habits'), findsOneWidget);
  });

  testWidgets('with reduced motion it still advances', (tester) async {
    await tester.pumpWidget(buildApp(_FakeProfileService(), reduceMotion: true));
    await tester.pumpAndSettle();

    await pick(tester, 'other');

    expect(find.text('Pregunta 2 de 5'), findsOneWidget);
  });

  testWidgets('fits a 360 x 640 phone with large text without overflowing', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(360, 640), textScaler: TextScaler.linear(1.4)),
        child: OnboardingScreen(profileService: _FakeProfileService()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tile('prefer_not_to_say'), findsOneWidget);
  });
}
