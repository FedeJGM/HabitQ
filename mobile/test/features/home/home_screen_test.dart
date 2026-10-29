import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app_routes.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/features/auth/auth_service.dart';
import 'package:mobile/features/auth/user.dart';
import 'package:mobile/features/chat/chat_service.dart';
import 'package:mobile/features/home/home_screen.dart';
import 'package:material_symbols_icons/symbols.dart';

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

class _FakeChatService extends ChatService {
  _FakeChatService({this.conversations = const [], this.fetchError});

  List<ConversationSummary> conversations;
  ApiException? fetchError;

  @override
  Future<List<ConversationSummary>> fetchConversations() async {
    if (fetchError != null) throw fetchError!;
    return conversations;
  }
}

ConversationSummary _conversation(String id, {String? title}) => ConversationSummary(
      id: id,
      title: title,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  Object? chatArguments;

  Widget buildApp(AuthService authService, {DateTime? now, ChatService? chatService}) {
    final fixedNow = now ?? DateTime(2026, 1, 1, 10);
    chatArguments = 'not opened';
    return MaterialApp(
      routes: {
        AppRoutes.login: (_) => const Scaffold(body: Text('Login')),
        AppRoutes.habits: (_) => const Scaffold(body: Text('Habits')),
        AppRoutes.profile: (_) => const Scaffold(body: Text('Profile')),
        AppRoutes.chat: (context) {
          chatArguments = ModalRoute.of(context)?.settings.arguments;
          return const Scaffold(body: Text('Chat'));
        },
      },
      home: HomeScreen(
        authService: authService,
        chatService: chatService ?? _FakeChatService(),
        now: () => fixedNow,
      ),
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

  group('time-of-day greeting', () {
    Future<void> pumpAt(WidgetTester tester, int hour, [int minute = 0]) async {
      final fakeService = _FakeAuthService(userToReturn: alice);
      await tester.pumpWidget(buildApp(fakeService, now: DateTime(2026, 1, 1, hour, minute)));
      await tester.pumpAndSettle();
    }

    final sun = find.byWidgetPredicate((w) =>
        w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/images/sun.png');

    void expectDay(WidgetTester tester) {
      expect(find.text('¡Hola, Alice!'), findsOneWidget);
      expect(find.text('Es un nuevo día.'), findsOneWidget);
      expect(find.text('Es una gran noche.'), findsNothing);
      expect(find.byIcon(Icons.nights_stay), findsNothing);
      expect(sun, findsOneWidget);
    }

    void expectNight(WidgetTester tester) {
      expect(find.text('¡Hola, Alice!'), findsOneWidget);
      expect(find.text('Es una gran noche.'), findsOneWidget);
      expect(find.text('Es un nuevo día.'), findsNothing);
      expect(find.byIcon(Icons.nights_stay), findsOneWidget);
      expect(sun, findsNothing);
    }

    testWidgets('morning keeps the new-day message and the sun', (tester) async {
      await pumpAt(tester, 9);
      expectDay(tester);
    });

    testWidgets('afternoon keeps the new-day message and the sun', (tester) async {
      await pumpAt(tester, 15);
      expectDay(tester);
    });

    testWidgets('evening shows the great-night message with the cloud and moon', (tester) async {
      await pumpAt(tester, 21);
      expectNight(tester);
    });

    testWidgets('late night shows the great-night message', (tester) async {
      await pumpAt(tester, 3);
      expectNight(tester);
    });

    testWidgets('05:00 is the first daytime minute', (tester) async {
      await pumpAt(tester, 5);
      expectDay(tester);
    });

    testWidgets('05:59 is already daytime', (tester) async {
      await pumpAt(tester, 5, 59);
      expectDay(tester);
    });

    testWidgets('04:59 is still night', (tester) async {
      await pumpAt(tester, 4, 59);
      expectNight(tester);
    });

    testWidgets('18:59 is still daytime', (tester) async {
      await pumpAt(tester, 18, 59);
      expectDay(tester);
    });

    testWidgets('19:00 is the first night minute', (tester) async {
      await pumpAt(tester, 19);
      expectNight(tester);
    });
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

    await tester.tap(find.byIcon(Symbols.logout_rounded));
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

  group('chat entry points', () {
    Future<void> pump(WidgetTester tester, ChatService chatService) async {
      await tester.pumpWidget(buildApp(_FakeAuthService(userToReturn: alice), chatService: chatService));
      await tester.pumpAndSettle();
    }

    testWidgets('first conversation: shows only the single Chat con HabitQ card', (tester) async {
      await pump(tester, _FakeChatService());

      expect(find.text('Chat con HabitQ'), findsOneWidget);
      expect(find.text('Nuevo chat con HabitQ'), findsNothing);
      expect(find.text('Continuar conversación'), findsNothing);
    });

    testWidgets('with past conversations: shows Continuar and Nuevo chat instead', (tester) async {
      await pump(tester, _FakeChatService(conversations: [_conversation('c2'), _conversation('c1')]));

      expect(find.text('Continuar conversación'), findsOneWidget);
      expect(find.text('Nuevo chat con HabitQ'), findsOneWidget);
      expect(find.text('Chat con HabitQ'), findsNothing);
    });

    testWidgets('Continuar subtitle shows the latest conversation title', (tester) async {
      await pump(
        tester,
        _FakeChatService(conversations: [_conversation('c2', title: 'Mi sueño'), _conversation('c1')]),
      );

      expect(find.text('Mi sueño'), findsOneWidget);
    });

    testWidgets('Continuar subtitle falls back when the conversation has no title', (tester) async {
      await pump(tester, _FakeChatService(conversations: [_conversation('c2')]));

      expect(find.text('Retoma donde lo dejaste'), findsOneWidget);
    });

    testWidgets('Continuar opens the most recent conversation', (tester) async {
      await pump(tester, _FakeChatService(conversations: [_conversation('c2'), _conversation('c1')]));

      await tester.tap(find.text('Continuar conversación'));
      await tester.pumpAndSettle();

      expect(find.text('Chat'), findsOneWidget);
      expect(chatArguments, 'c2');
    });

    testWidgets('Nuevo chat opens an empty chat', (tester) async {
      await pump(tester, _FakeChatService(conversations: [_conversation('c2')]));

      await tester.tap(find.text('Nuevo chat con HabitQ'));
      await tester.pumpAndSettle();

      expect(find.text('Chat'), findsOneWidget);
      expect(chatArguments, isNull);
    });

    testWidgets('falls back to the single card when conversations cannot be loaded', (tester) async {
      await pump(tester, _FakeChatService(fetchError: ApiException('boom')));

      expect(find.text('Chat con HabitQ'), findsOneWidget);
      expect(find.text('Continuar conversación'), findsNothing);
    });

    testWidgets('after a first chat, coming back to Inicio shows both buttons', (tester) async {
      final chatService = _FakeChatService();
      await pump(tester, chatService);
      expect(find.text('Chat con HabitQ'), findsOneWidget);

      await tester.tap(find.text('Chat con HabitQ'));
      await tester.pumpAndSettle();
      chatService.conversations = [_conversation('c1')];
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      expect(find.text('Continuar conversación'), findsOneWidget);
      expect(find.text('Nuevo chat con HabitQ'), findsOneWidget);
    });
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
