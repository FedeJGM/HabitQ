import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app_routes.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/core/widgets/error_notice.dart';
import 'package:mobile/core/widgets/skeleton.dart';
import 'package:mobile/features/activity/tasks_service.dart';
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

class _FakeTasksService extends TasksService {
  _FakeTasksService({this.tasks = const [], this.fetchError});

  List<DayTask> tasks;
  ApiException? fetchError;
  final List<String> fetchedDays = [];
  int fetches = 0;

  @override
  Future<List<DayTask>> fetchTasks(DateTime day) async {
    fetches++;
    fetchedDays.add(TasksService.dayKey(day));
    if (fetchError != null) throw fetchError!;
    return List.of(tasks);
  }
}

DayTask _task(String id, String label, {int target = 1, int progress = 0, bool archived = false}) => DayTask(
      id: id,
      taskKey: 'k$id',
      label: label,
      target: target,
      unit: '',
      step: 1,
      progress: progress,
      archived: archived,
    );

ConversationSummary _conversation(String id, {String? title}) => ConversationSummary(
      id: id,
      title: title,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  Object? chatArguments;

  Widget buildApp(
    AuthService authService, {
    DateTime? now,
    ChatService? chatService,
    TasksService? tasksService,
  }) {
    final fixedNow = now ?? DateTime(2026, 1, 1, 10);
    chatArguments = 'not opened';
    return MaterialApp(
      routes: {
        AppRoutes.login: (_) => const Scaffold(body: Text('Login')),
        AppRoutes.habits: (_) => const Scaffold(body: Text('Habits')),
        AppRoutes.activity: (_) => const Scaffold(body: Text('Activity page')),
        AppRoutes.profile: (_) => const Scaffold(body: Text('Profile')),
        AppRoutes.chat: (context) {
          chatArguments = ModalRoute.of(context)?.settings.arguments;
          return const Scaffold(body: Text('Chat'));
        },
      },
      home: HomeScreen(
        authService: authService,
        chatService: chatService ?? _FakeChatService(),
        tasksService: tasksService ?? _FakeTasksService(),
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
      expect(find.byIcon(Symbols.nights_stay_rounded), findsNothing);
      expect(sun, findsOneWidget);
    }

    void expectNight(WidgetTester tester) {
      expect(find.text('¡Hola, Alice!'), findsOneWidget);
      expect(find.text('Es una gran noche.'), findsOneWidget);
      expect(find.text('Es un nuevo día.'), findsNothing);
      expect(find.byIcon(Symbols.nights_stay_rounded), findsOneWidget);
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

  group('today tasks card', () {
    Future<void> pump(WidgetTester tester, TasksService tasks) async {
      await tester.pumpWidget(buildApp(_FakeAuthService(userToReturn: alice), tasksService: tasks));
      await tester.pumpAndSettle();
    }

    testWidgets('asks for the tasks of the current day using the injected clock', (tester) async {
      final service = _FakeTasksService();
      await pump(tester, service);

      expect(service.fetchedDays, ['2026-01-01']);
    });

    testWidgets('shows the progress and the pending tasks first', (tester) async {
      await pump(
        tester,
        _FakeTasksService(tasks: [
          _task('1', 'Desayunar', progress: 1),
          _task('2', 'Tomar agua', target: 8, progress: 2),
          _task('3', 'Caminar', target: 30),
        ]),
      );

      expect(find.text('Tus tareas de hoy'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('1 de 3 completadas'), findsOneWidget);
      expect(find.text('Tomar agua'), findsOneWidget);
      expect(find.text('Caminar'), findsOneWidget);
      expect(find.text('Desayunar'), findsOneWidget);

      final order = [for (final label in ['Tomar agua', 'Caminar', 'Desayunar']) tester.getTopLeft(find.text(label)).dy];
      expect(order, [...order]..sort());
    });

    testWidgets('lists at most three tasks and counts the rest', (tester) async {
      await pump(
        tester,
        _FakeTasksService(tasks: [for (var i = 1; i <= 5; i++) _task('$i', 'Tarea $i')]),
      );

      expect(find.text('Tarea 1'), findsOneWidget);
      expect(find.text('Tarea 3'), findsOneWidget);
      expect(find.text('Tarea 4'), findsNothing);
      expect(find.text('+2 más'), findsOneWidget);
    });

    testWidgets('removed tasks are not counted', (tester) async {
      await pump(
        tester,
        _FakeTasksService(tasks: [_task('1', 'Activa'), _task('2', 'Quitada', progress: 1, archived: true)]),
      );

      expect(find.text('0/1'), findsOneWidget);
      expect(find.text('Quitada'), findsNothing);
    });

    testWidgets('tapping the card opens the Actividad tab', (tester) async {
      await pump(tester, _FakeTasksService(tasks: [_task('1', 'Desayunar')]));

      await tester.tap(find.text('Tus tareas de hoy'));
      await tester.pumpAndSettle();

      expect(find.text('Activity page'), findsOneWidget);
    });

    testWidgets('tapping a task also opens the Actividad tab', (tester) async {
      await pump(tester, _FakeTasksService(tasks: [_task('1', 'Desayunar')]));

      await tester.tap(find.text('Desayunar'));
      await tester.pumpAndSettle();

      expect(find.text('Activity page'), findsOneWidget);
    });

    testWidgets('without tasks it invites the user to choose some in Actividad', (tester) async {
      await pump(tester, _FakeTasksService());

      expect(find.text('Aún no tienes tareas'), findsOneWidget);
      await tester.tap(find.text('Elegir tareas'));
      await tester.pumpAndSettle();

      expect(find.text('Activity page'), findsOneWidget);
    });

    testWidgets('shows a skeleton while loading', (tester) async {
      await tester.pumpWidget(
        buildApp(_FakeAuthService(userToReturn: alice), tasksService: _FakeTasksService()),
      );

      expect(find.byKey(const ValueKey('today-tasks-skeleton')), findsOneWidget);
      expect(find.byType(SkeletonBox), findsWidgets);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('today-tasks-skeleton')), findsNothing);
    });

    testWidgets('a failure shows an error notice that retries', (tester) async {
      final service = _FakeTasksService(fetchError: ApiException('No se pudieron cargar tus tareas.'));
      await pump(tester, service);

      expect(find.byType(ErrorNotice), findsOneWidget);
      expect(find.text('No se pudieron cargar tus tareas.'), findsOneWidget);

      service
        ..fetchError = null
        ..tasks = [_task('1', 'Desayunar')];
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(service.fetches, 2);
      expect(find.byType(ErrorNotice), findsNothing);
      expect(find.text('Desayunar'), findsOneWidget);
    });

    testWidgets('a task failure does not hide the greeting or the chat cards', (tester) async {
      await pump(tester, _FakeTasksService(fetchError: ApiException('boom')));

      expect(find.text('¡Hola, Alice!'), findsOneWidget);
      expect(find.text('Chat con HabitQ'), findsOneWidget);
    });
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
