import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app_routes.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/features/auth/auth_service.dart';
import 'package:mobile/features/auth/user.dart';
import 'package:mobile/features/home/home_screen.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService({this.userToReturn, this.fetchError});

  HabitQUser? userToReturn;
  ApiException? fetchError;
  bool signOutCalled = false;

  @override
  Future<HabitQUser> fetchCurrentUser() async {
    if (fetchError != null) throw fetchError!;
    return userToReturn!;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

void main() {
  Widget buildApp(AuthService authService) {
    return MaterialApp(
      routes: {
        AppRoutes.login: (_) => const Scaffold(body: Text('Login')),
        AppRoutes.habits: (_) => const Scaffold(body: Text('Habits')),
      },
      home: HomeScreen(authService: authService),
    );
  }

  const alice = HabitQUser(
    id: 'u1',
    email: 'test@example.com',
    name: 'Alice',
    onboardingCompleted: true,
  );

  testWidgets('shows a greeting with the user name once loaded', (tester) async {
    final fakeService = _FakeAuthService(userToReturn: alice);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    expect(find.text('¡Hola, Alice!'), findsOneWidget);
  });

  testWidgets('shows an error message when fetching the user fails', (tester) async {
    final fakeService =
        _FakeAuthService(fetchError: ApiException('No se pudo cargar tu perfil.'));
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar tu perfil.'), findsOneWidget);
  });

  testWidgets('signs out and navigates to login when the logout button is tapped', (tester) async {
    final fakeService = _FakeAuthService(userToReturn: alice);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(fakeService.signOutCalled, isTrue);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('shows the still-unbuilt sections as not-yet-available', (tester) async {
    final fakeService = _FakeAuthService(userToReturn: alice);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    expect(find.text('Chat con HabitQ'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Próximamente'), findsNWidgets(2));
  });

  testWidgets('navigates to Mis hábitos when its card is tapped', (tester) async {
    final fakeService = _FakeAuthService(userToReturn: alice);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mis hábitos'));
    await tester.pumpAndSettle();

    expect(find.text('Habits'), findsOneWidget);
  });
}
