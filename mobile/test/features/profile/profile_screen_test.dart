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
  String? lastGender;
  int? lastHeightCm;
  double? lastWeightKg;

  @override
  Future<UserProfile> getProfile() async {
    if (fetchError != null) throw fetchError!;
    return profile!;
  }

  @override
  Future<UserProfile> saveProfile({
    required String ageRange,
    required String mainGoal,
    String? gender,
    int? heightCm,
    double? weightKg,
  }) async {
    lastAgeRange = ageRange;
    lastMainGoal = mainGoal;
    lastGender = gender;
    lastHeightCm = heightCm;
    lastWeightKg = weightKg;
    if (saveError != null) throw saveError!;
    profile = UserProfile(
      id: 'p1',
      userId: 'u1',
      ageRange: ageRange,
      mainGoal: mainGoal,
      gender: gender,
      heightCm: heightCm,
      weightKg: weightKg,
    );
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
    gender: 'female',
    heightCm: 165,
    weightKg: 60.5,
  );

  const legacyProfile = UserProfile(
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

  testWidgets('shows the current gender, height and weight once loaded', (tester) async {
    final fakeService = _FakeProfileService(profile: initialProfile);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    expect(find.text('Femenino'), findsWidgets);
    expect(find.text('165 cm'), findsOneWidget);
    expect(find.text('60.5 kg'), findsOneWidget);
    final genderChip = tester.widget<ChoiceChip>(find.byKey(const ValueKey('gender:female')));
    expect(genderChip.selected, isTrue);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('profile-field:height'))).controller!.text, '165');
    expect(tester.widget<TextField>(find.byKey(const ValueKey('profile-field:weight'))).controller!.text, '60.5');
  });

  testWidgets('a profile created before the physical data existed shows empty fields', (tester) async {
    final fakeService = _FakeProfileService(profile: legacyProfile);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    for (final value in ['female', 'male', 'other', 'prefer_not_to_say']) {
      final chip = tester.widget<ChoiceChip>(find.byKey(ValueKey('gender:$value')));
      expect(chip.selected, isFalse);
    }
    expect(tester.widget<TextField>(find.byKey(const ValueKey('profile-field:height'))).controller!.text, isEmpty);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('profile-field:weight'))).controller!.text, isEmpty);
  });

  testWidgets('tapping a gender saves it together with the rest of the profile', (tester) async {
    final fakeService = _FakeProfileService(profile: initialProfile);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('gender:other')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gender:other')));
    await tester.pumpAndSettle();

    expect(fakeService.lastGender, 'other');
    expect(fakeService.lastAgeRange, '25-34');
    expect(fakeService.lastMainGoal, 'sleep_better');
    expect(fakeService.lastHeightCm, 165);
    expect(fakeService.lastWeightKg, 60.5);
  });

  testWidgets('changing the age range keeps the physical data', (tester) async {
    final fakeService = _FakeProfileService(profile: initialProfile);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('age:35-44')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('age:35-44')));
    await tester.pumpAndSettle();

    expect(fakeService.lastGender, 'female');
    expect(fakeService.lastHeightCm, 165);
    expect(fakeService.lastWeightKg, 60.5);
  });

  testWidgets('editing height and weight saves them with Guardar medidas', (tester) async {
    final fakeService = _FakeProfileService(profile: legacyProfile);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('profile-field:height')));
    await tester.enterText(find.byKey(const ValueKey('profile-field:height')), '172');
    await tester.enterText(find.byKey(const ValueKey('profile-field:weight')), '68,4');
    await tester.pump();
    await tester.ensureVisible(find.text('Guardar medidas'));
    await tester.tap(find.text('Guardar medidas'));
    await tester.pumpAndSettle();

    expect(fakeService.lastHeightCm, 172);
    expect(fakeService.lastWeightKg, 68.4);
    expect(find.text('172 cm'), findsOneWidget);
  });

  testWidgets('Guardar medidas stays disabled while a value is out of range', (tester) async {
    final fakeService = _FakeProfileService(profile: initialProfile);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('profile-field:height')));
    await tester.enterText(find.byKey(const ValueKey('profile-field:height')), '50');
    await tester.pump();

    expect(find.text('Ingresa una altura entre 100 y 250 cm.'), findsOneWidget);
    final save = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar medidas'));
    expect(save.onPressed, isNull);
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

    await tester.ensureVisible(find.byKey(const ValueKey('age:35-44')));
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

    await tester.ensureVisible(find.byKey(const ValueKey('age:35-44')));
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
