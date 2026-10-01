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
        AppRoutes.profile: (_) => const Scaffold(body: Text('Profile')),
        AppRoutes.chat: (_) => const Scaffold(body: Text('Chat')),
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
    expect(find.text('Es un nuevo día.'), findsOneWidget);
  });

  testWidgets('does not show a task list (no daily tasks in the backend)', (tester) async {
    final fakeService = _FakeAuthService(userToReturn: alice);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    expect(find.text('Create a new task'), findsNothing);
    expect(find.text('Tomar agua'), findsNothing);
  });

  testWidgets('shows the bottom navigation with Inicio, Chat and Perfil', (tester) async {
    final fakeService = _FakeAuthService(userToReturn: alice);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
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

  testWidgets('navigates to Chat con HabitQ when its card is tapped', (tester) async {
    final fakeService = _FakeAuthService(userToReturn: alice);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chat con HabitQ'));
    await tester.pumpAndSettle();

    expect(find.text('Chat'), findsOneWidget);
  });

  testWidgets('navigates to Mis hábitos when its card is tapped', (tester) async {
    final fakeService = _FakeAuthService(userToReturn: alice);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mis hábitos'));
    await tester.pumpAndSettle();

    expect(find.text('Habits'), findsOneWidget);
  });

  testWidgets('navigates to Perfil when its card is tapped', (tester) async {
    final fakeService = _FakeAuthService(userToReturn: alice);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
  });
}
