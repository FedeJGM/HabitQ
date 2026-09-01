import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app_routes.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/features/onboarding/onboarding_screen.dart';
import 'package:mobile/features/profile/profile_service.dart';

class _FakeProfileService implements ProfileService {
  _FakeProfileService({this.error});

  ApiException? error;
  String? capturedAgeRange;
  String? capturedMainGoal;

  @override
  Future<UserProfile> saveProfile({required String ageRange, required String mainGoal}) async {
    capturedAgeRange = ageRange;
    capturedMainGoal = mainGoal;
    if (error != null) throw error!;
    return UserProfile(id: 'p1', userId: 'u1', ageRange: ageRange, mainGoal: mainGoal);
  }
}

void main() {
  Widget buildApp(ProfileService profileService) {
    return MaterialApp(
      routes: {
        AppRoutes.onboardingHabits: (_) => const Scaffold(body: Text('Habits')),
      },
      home: OnboardingScreen(profileService: profileService),
    );
  }

  testWidgets('shows a validation message when nothing is selected', (tester) async {
    final fakeService = _FakeProfileService();
    await tester.pumpWidget(buildApp(fakeService));

    await tester.tap(find.text('Continuar'));
    await tester.pump();

    expect(find.text('Selecciona tu rango de edad y tu objetivo principal.'), findsOneWidget);
    expect(fakeService.capturedAgeRange, isNull);
  });

  testWidgets('saves the profile and navigates to the habit questions step on success', (tester) async {
    final fakeService = _FakeProfileService();
    await tester.pumpWidget(buildApp(fakeService));

    await tester.tap(find.text('25-34'));
    await tester.pump();
    await tester.tap(find.text('Dormir mejor'));
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(fakeService.capturedAgeRange, '25-34');
    expect(fakeService.capturedMainGoal, 'sleep_better');
    expect(find.text('Habits'), findsOneWidget);
  });

  testWidgets('shows the backend error message on failure', (tester) async {
    final fakeService = _FakeProfileService(error: ApiException('Ocurrió un error inesperado.'));
    await tester.pumpWidget(buildApp(fakeService));

    await tester.tap(find.text('18-24'));
    await tester.pump();
    await tester.tap(find.text('Reducir el uso de pantallas'));
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Ocurrió un error inesperado.'), findsOneWidget);
  });
}
