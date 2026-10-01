import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/features/auth/auth_service.dart';
import 'package:mobile/features/auth/user.dart';
import 'package:mobile/features/profile/profile_screen.dart';
import 'package:mobile/features/profile/profile_service.dart';

class _FakeProfileService implements ProfileService {
  _FakeProfileService({this.profile, this.fetchError});

  UserProfile? profile;
  ApiException? fetchError;
  ApiException? saveError;
  String? lastAgeRange;
  String? lastMainGoal;

  @override
  Future<UserProfile> getProfile() async {
    if (fetchError != null) throw fetchError!;
    return profile!;
  }

  @override
  Future<UserProfile> saveProfile({required String ageRange, required String mainGoal}) async {
    lastAgeRange = ageRange;
    lastMainGoal = mainGoal;
    if (saveError != null) throw saveError!;
    profile = UserProfile(id: 'p1', userId: 'u1', ageRange: ageRange, mainGoal: mainGoal);
    return profile!;
  }
}

class _FakeAuthService extends AuthService {
  bool signOutCalled = false;

  @override
  Future<HabitQUser> fetchCurrentUser() async => const HabitQUser(
        id: 'u1',
        email: 'diego@habitq.co',
        name: 'Diego Alejandro',
        onboardingCompleted: true,
      );

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

void main() {
  Widget buildApp(ProfileService profileService) {
    return MaterialApp(home: ProfileScreen(profileService: profileService));
  }

  const initialProfile = UserProfile(
    id: 'p1',
    userId: 'u1',
    ageRange: '25-34',
    mainGoal: 'sleep_better',
  );

  testWidgets('shows the current age range and main goal once loaded', (tester) async {
    final fakeService = _FakeProfileService(profile: initialProfile);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    final ageChip = tester.widget<ChoiceChip>(find.byKey(const ValueKey('age:25-34')));
    expect(ageChip.selected, isTrue);
    final goalChip = tester.widget<ChoiceChip>(find.byKey(const ValueKey('goal:sleep_better')));
    expect(goalChip.selected, isTrue);
  });

  testWidgets('shows an error message when the initial fetch fails', (tester) async {
    final fakeService =
        _FakeProfileService(fetchError: ApiException('No se pudo cargar tu perfil.'));
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar tu perfil.'), findsOneWidget);
  });

  testWidgets('tapping a different age range saves it together with the current goal',
      (tester) async {
    final fakeService = _FakeProfileService(profile: initialProfile);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('age:35-44')));
    await tester.pumpAndSettle();

    expect(fakeService.lastAgeRange, '35-44');
    expect(fakeService.lastMainGoal, 'sleep_better');
    final newAgeChip = tester.widget<ChoiceChip>(find.byKey(const ValueKey('age:35-44')));
    expect(newAgeChip.selected, isTrue);
    final oldAgeChip = tester.widget<ChoiceChip>(find.byKey(const ValueKey('age:25-34')));
    expect(oldAgeChip.selected, isFalse);
  });

  testWidgets('tapping a different goal saves it together with the current age range',
      (tester) async {
    final fakeService = _FakeProfileService(profile: initialProfile);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('goal:move_more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal:move_more')));
    await tester.pumpAndSettle();

    expect(fakeService.lastAgeRange, '25-34');
    expect(fakeService.lastMainGoal, 'move_more');
  });

  testWidgets('shows an error and keeps the old selection when saving fails', (tester) async {
    final fakeService = _FakeProfileService(profile: initialProfile)
      ..saveError = ApiException('No se pudo guardar el cambio.');
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('age:35-44')));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo guardar el cambio.'), findsOneWidget);
    final oldAgeChip = tester.widget<ChoiceChip>(find.byKey(const ValueKey('age:25-34')));
    expect(oldAgeChip.selected, isTrue);
  });

  testWidgets('shows the Mi perfil title, user identity and bottom navigation', (tester) async {
    final fakeService = _FakeProfileService(profile: initialProfile);
    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(profileService: fakeService, authService: _FakeAuthService()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Mi perfil'), findsOneWidget);
    expect(find.text('Diego Alejandro'), findsOneWidget);
    expect(find.text('diego@habitq.co'), findsOneWidget);
    expect(find.text('DA'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('Cerrar sesión button signs out', (tester) async {
    final fakeService = _FakeProfileService(profile: initialProfile);
    final fakeAuth = _FakeAuthService();
    await tester.pumpWidget(MaterialApp(
      routes: {'/login': (_) => const Scaffold(body: Text('Login'))},
      home: ProfileScreen(profileService: fakeService, authService: fakeAuth),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(fakeAuth.signOutCalled, isTrue);
    expect(find.text('Login'), findsOneWidget);
  });
}
