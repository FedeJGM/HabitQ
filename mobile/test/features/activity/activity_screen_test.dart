import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app_routes.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/features/activity/activity_screen.dart';
import 'package:mobile/features/activity/reminder_service.dart';
import 'package:mobile/features/activity/tasks_service.dart';
import 'package:mobile/features/auth/auth_service.dart';

import 'fake_notification_gateway.dart';

DayTask _task(
  String id,
  String key,
  String label, {
  int target = 1,
  String unit = '',
  int step = 1,
  int progress = 0,
  String? reminder,
}) =>
    DayTask(
      id: id,
      taskKey: key,
      label: label,
      target: target,
      unit: unit,
      step: step,
      progress: progress,
      reminderTime: reminder,
    );

class _FakeTasksService extends TasksService {
  _FakeTasksService({Map<String, List<DayTask>>? byDay, List<CatalogTask>? catalog, this.fetchError})
      : byDay = byDay ?? {},
        catalog = catalog ?? [];

  final Map<String, List<DayTask>> byDay;
  final List<CatalogTask> catalog;
  ApiException? fetchError;
  ApiException? progressError;

  final List<String> fetchedDays = [];
  final List<String> progressCalls = [];
  final List<String> activated = [];
  final List<String> archived = [];
  final List<String?> reminders = [];

  List<DayTask> _day(DateTime day) => byDay.putIfAbsent(TasksService.dayKey(day), () => []);

  @override
  Future<List<DayTask>> fetchTasks(DateTime day) async {
    fetchedDays.add(TasksService.dayKey(day));
    if (fetchError != null) throw fetchError!;
    return List.of(_day(day));
  }

  @override
  Future<List<CatalogTask>> fetchCatalog() async => catalog;

  @override
  Future<DayTask> setProgress(String id, DateTime day, int progress) async {
    progressCalls.add('$id:${TasksService.dayKey(day)}:$progress');
    if (progressError != null) throw progressError!;
    final list = _day(day);
    final index = list.indexWhere((t) => t.id == id);
    list[index] = list[index].copyWith(progress: progress);
    return list[index];
  }

  @override
  Future<DayTask> activate(String taskKey, {String? reminderTime}) async {
    activated.add(taskKey);
    final item = catalog.firstWhere((c) => c.key == taskKey);
    final task = _task('new-$taskKey', taskKey, item.label, target: item.target, unit: item.unit, step: item.step);
    byDay.values.first.add(task);
    return task;
  }

  @override
  Future<void> archive(String id) async {
    archived.add(id);
    for (final list in byDay.values) {
      list.removeWhere((t) => t.id == id);
    }
  }

  @override
  Future<void> setReminder(String id, String? reminderTime) async {
    reminders.add(reminderTime);
    for (final list in byDay.values) {
      final index = list.indexWhere((t) => t.id == id);
      if (index != -1) {
        list[index] = reminderTime == null
            ? list[index].copyWith(clearReminder: true)
            : list[index].copyWith(reminderTime: reminderTime);
      }
    }
  }
}

class _FakeAuthService extends AuthService {
  @override
  Future<void> signOut() async {}
}

void main() {
  // Thursday 2026-10-15: its Sunday-first week runs from Sun 11 to Sat 17.
  var now = DateTime(2026, 10, 15, 10);
  late FakeNotificationGateway gateway;

  setUp(() {
    now = DateTime(2026, 10, 15, 10);
    gateway = FakeNotificationGateway();
  });

  Future<void> pumpScreen(WidgetTester tester, _FakeTasksService service) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        routes: {AppRoutes.login: (_) => const Scaffold(body: Text('Login'))},
        home: ActivityScreen(
          tasksService: service,
          authService: _FakeAuthService(),
          reminderService: ReminderService(gateway: gateway),
          now: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder card(String id) => find.byKey(ValueKey('task-$id'));
  Finder inCard(String id, Finder matching) => find.descendant(of: card(id), matching: matching);

  const dayKey = '2026-10-15';

  testWidgets('shows the month, the week strip and selects today', (tester) async {
    await pumpScreen(tester, _FakeTasksService());

    expect(find.text('OCTUBRE 2026'), findsOneWidget);
    for (final label in ['DOM', 'L', 'M', 'X', 'J', 'V', 'S']) {
      expect(find.text(label), findsOneWidget);
    }
    for (var day = 11; day <= 17; day++) {
      expect(find.byKey(ValueKey('day-2026-10-$day')), findsOneWidget);
    }
  });

  testWidgets('loads today\'s tasks when it opens', (tester) async {
    final service = _FakeTasksService(byDay: {
      dayKey: [_task('t1', 'hydrate_water', 'Tomar agua', target: 8, unit: 'vasos', progress: 2)],
    });

    await pumpScreen(tester, service);

    expect(service.fetchedDays, [dayKey]);
    expect(find.text('Tomar agua'), findsOneWidget);
    expect(find.text('2/8 vasos'), findsOneWidget);
  });

  testWidgets('shows a checkbox for single tasks, checked when done', (tester) async {
    final service = _FakeTasksService(byDay: {
      dayKey: [
        _task('t1', 'eat_breakfast', 'Desayunar', progress: 1),
        _task('t2', 'move_stairs', 'Usar las escaleras'),
      ],
    });

    await pumpScreen(tester, service);

    expect(tester.widget<Checkbox>(inCard('t1', find.byType(Checkbox))).value, isTrue);
    expect(tester.widget<Checkbox>(inCard('t2', find.byType(Checkbox))).value, isFalse);
  });

  testWidgets('shows an invitation when there are no tasks yet', (tester) async {
    await pumpScreen(tester, _FakeTasksService());

    expect(find.textContaining('Aún no tienes tareas'), findsOneWidget);
  });

  testWidgets('shows the error message when tasks cannot be loaded', (tester) async {
    await pumpScreen(tester, _FakeTasksService(fetchError: ApiException('Sin conexión')));

    expect(find.text('Sin conexión'), findsOneWidget);
  });

  testWidgets('is the selected Actividad tab', (tester) async {
    await pumpScreen(tester, _FakeTasksService());

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 1);
  });

  group('progress', () {
    testWidgets('plus adds one step and shows the new count', (tester) async {
      final service = _FakeTasksService(byDay: {
        dayKey: [_task('t1', 'hydrate_water', 'Tomar agua', target: 8, unit: 'vasos', progress: 2)],
      });
      await pumpScreen(tester, service);

      await tester.tap(inCard('t1', find.byTooltip('Sumar')));
      await tester.pumpAndSettle();

      expect(service.progressCalls, ['t1:$dayKey:3']);
      expect(find.text('3/8 vasos'), findsOneWidget);
    });

    testWidgets('uses the task step for the counter', (tester) async {
      final service = _FakeTasksService(byDay: {
        dayKey: [_task('t1', 'move_walk', 'Caminar', target: 30, unit: 'min', step: 5)],
      });
      await pumpScreen(tester, service);

      await tester.tap(inCard('t1', find.byTooltip('Sumar')));
      await tester.pumpAndSettle();

      expect(service.progressCalls, ['t1:$dayKey:5']);
    });

    testWidgets('minus removes one step', (tester) async {
      final service = _FakeTasksService(byDay: {
        dayKey: [_task('t1', 'hydrate_water', 'Tomar agua', target: 8, unit: 'vasos', progress: 2)],
      });
      await pumpScreen(tester, service);

      await tester.tap(inCard('t1', find.byTooltip('Restar')));
      await tester.pumpAndSettle();

      expect(service.progressCalls, ['t1:$dayKey:1']);
    });

    testWidgets('never goes below zero or above the target', (tester) async {
      final service = _FakeTasksService(byDay: {
        dayKey: [
          _task('t1', 'hydrate_water', 'Tomar agua', target: 8, unit: 'vasos'),
          _task('t2', 'stress_breathing', 'Respiración', target: 3, unit: 'veces', progress: 3),
        ],
      });
      await pumpScreen(tester, service);

      Finder button(String id, String tooltip) => find.descendant(
            of: card(id),
            matching: find.byWidgetPredicate((w) => w is IconButton && w.tooltip == tooltip),
          );

      expect(tester.widget<IconButton>(button('t1', 'Restar')).onPressed, isNull);
      expect(tester.widget<IconButton>(button('t2', 'Sumar')).onPressed, isNull);
      expect(tester.widget<IconButton>(button('t1', 'Sumar')).onPressed, isNotNull);
      expect(tester.widget<IconButton>(button('t2', 'Restar')).onPressed, isNotNull);
    });

    testWidgets('ticking a checkbox sets the target and unticking sets zero', (tester) async {
      final service = _FakeTasksService(byDay: {
        dayKey: [_task('t1', 'eat_breakfast', 'Desayunar')],
      });
      await pumpScreen(tester, service);

      await tester.tap(inCard('t1', find.byType(Checkbox)));
      await tester.pumpAndSettle();
      await tester.tap(inCard('t1', find.byType(Checkbox)));
      await tester.pumpAndSettle();

      expect(service.progressCalls, ['t1:$dayKey:1', 't1:$dayKey:0']);
    });

    testWidgets('keeps the old count and shows the error when saving fails', (tester) async {
      final service = _FakeTasksService(byDay: {
        dayKey: [_task('t1', 'hydrate_water', 'Tomar agua', target: 8, unit: 'vasos', progress: 2)],
      })
        ..progressError = ApiException('No se pudo guardar');
      await pumpScreen(tester, service);

      await tester.tap(inCard('t1', find.byTooltip('Sumar')));
      await tester.pumpAndSettle();

      expect(find.text('2/8 vasos'), findsOneWidget);
      expect(find.text('No se pudo guardar'), findsOneWidget);
    });
  });

  group('week strip', () {
    testWidgets('tapping a past day loads it as read-only', (tester) async {
      final service = _FakeTasksService(byDay: {
        dayKey: [_task('t1', 'hydrate_water', 'Tomar agua', target: 8, unit: 'vasos', progress: 2)],
        '2026-10-14': [_task('t1', 'hydrate_water', 'Tomar agua', target: 8, unit: 'vasos', progress: 8)],
      });
      await pumpScreen(tester, service);

      await tester.tap(find.byKey(const ValueKey('day-2026-10-14')));
      await tester.pumpAndSettle();

      expect(service.fetchedDays, [dayKey, '2026-10-14']);
      expect(find.text('8/8 vasos'), findsOneWidget);
      expect(find.text('Solo lectura'), findsOneWidget);
      expect(find.byTooltip('Sumar'), findsNothing);
      expect(find.byTooltip('Restar'), findsNothing);
      expect(find.byTooltip('Elegir tareas'), findsNothing);
    });

    testWidgets('a past day cannot change single-task checkboxes', (tester) async {
      final service = _FakeTasksService(byDay: {
        dayKey: [_task('t1', 'eat_breakfast', 'Desayunar')],
        '2026-10-14': [_task('t1', 'eat_breakfast', 'Desayunar', progress: 1)],
      });
      await pumpScreen(tester, service);

      await tester.tap(find.byKey(const ValueKey('day-2026-10-14')));
      await tester.pumpAndSettle();
      await tester.tap(inCard('t1', find.byType(Checkbox)));
      await tester.pumpAndSettle();

      expect(service.progressCalls, isEmpty);
    });

    testWidgets('a past day with no records says so', (tester) async {
      final service = _FakeTasksService(byDay: {
        dayKey: [_task('t1', 'eat_breakfast', 'Desayunar')],
      });
      await pumpScreen(tester, service);

      await tester.tap(find.byKey(const ValueKey('day-2026-10-13')));
      await tester.pumpAndSettle();

      expect(find.text('No hay tareas registradas este día.'), findsOneWidget);
    });

    testWidgets('future days cannot be opened', (tester) async {
      final service = _FakeTasksService();
      await pumpScreen(tester, service);

      await tester.tap(find.byKey(const ValueKey('day-2026-10-16')));
      await tester.pumpAndSettle();

      expect(service.fetchedDays, [dayKey]);
    });

    testWidgets('going back to today makes it editable again', (tester) async {
      final service = _FakeTasksService(byDay: {
        dayKey: [_task('t1', 'hydrate_water', 'Tomar agua', target: 8, unit: 'vasos')],
      });
      await pumpScreen(tester, service);

      await tester.tap(find.byKey(const ValueKey('day-2026-10-14')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('day-2026-10-15')));
      await tester.pumpAndSettle();

      expect(find.text('Solo lectura'), findsNothing);
      expect(find.byTooltip('Sumar'), findsOneWidget);
    });
  });

  group('choosing tasks', () {
    final catalog = [
      const CatalogTask(key: 'hydrate_water', label: 'Tomar agua', target: 8, unit: 'vasos', step: 1),
      const CatalogTask(key: 'hydrate_morning', label: 'Vaso al despertar', target: 1, unit: '', step: 1),
    ];

    testWidgets('the edit button lists the catalog with the active tasks switched on', (tester) async {
      final service = _FakeTasksService(
        catalog: catalog,
        byDay: {
          dayKey: [_task('t1', 'hydrate_water', 'Tomar agua', target: 8, unit: 'vasos')],
        },
      );
      await pumpScreen(tester, service);

      await tester.tap(find.byTooltip('Elegir tareas'));
      await tester.pumpAndSettle();

      final active = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Tomar agua'));
      final inactive =
          tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Vaso al despertar'));
      expect(active.value, isTrue);
      expect(inactive.value, isFalse);
    });

    testWidgets('switching a task on activates it and it shows up in the list', (tester) async {
      final service = _FakeTasksService(catalog: catalog, byDay: {dayKey: []});
      await pumpScreen(tester, service);

      await tester.tap(find.byTooltip('Elegir tareas'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Vaso al despertar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();

      expect(service.activated, ['hydrate_morning']);
      expect(find.text('Vaso al despertar'), findsOneWidget);
    });

    testWidgets('switching a task off archives it and it leaves the list', (tester) async {
      final service = _FakeTasksService(
        catalog: catalog,
        byDay: {
          dayKey: [_task('t1', 'hydrate_water', 'Tomar agua', target: 8, unit: 'vasos')],
        },
      );
      await pumpScreen(tester, service);

      await tester.tap(find.byTooltip('Elegir tareas'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Tomar agua'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();

      expect(service.archived, ['t1']);
      expect(find.text('Tomar agua'), findsNothing);
    });
  });

  group('reminders', () {
    testWidgets('picking a time saves it and shows it on the card', (tester) async {
      final service = _FakeTasksService(byDay: {
        dayKey: [_task('t1', 'eat_breakfast', 'Desayunar')],
      });
      await pumpScreen(tester, service);

      await tester.tap(inCard('t1', find.byTooltip('Recordatorio')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(service.reminders, ['08:00']);
      expect(inCard('t1', find.text('08:00')), findsOneWidget);
    });

    testWidgets('a task with a reminder shows its time and lets you remove it', (tester) async {
      final service = _FakeTasksService(byDay: {
        dayKey: [_task('t1', 'eat_breakfast', 'Desayunar', reminder: '07:30')],
      });
      await pumpScreen(tester, service);

      expect(inCard('t1', find.text('07:30')), findsOneWidget);

      await tester.tap(inCard('t1', find.byTooltip('Quitar recordatorio')));
      await tester.pumpAndSettle();

      expect(service.reminders, [null]);
      expect(inCard('t1', find.text('07:30')), findsNothing);
    });

    testWidgets('reminders cannot be edited on a past day', (tester) async {
      final service = _FakeTasksService(byDay: {
        dayKey: [_task('t1', 'eat_breakfast', 'Desayunar')],
        '2026-10-14': [_task('t1', 'eat_breakfast', 'Desayunar')],
      });
      await pumpScreen(tester, service);

      await tester.tap(find.byKey(const ValueKey('day-2026-10-14')));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Recordatorio'), findsNothing);
    });
  });

  group('reminder notifications', () {
    testWidgets('opening today schedules the reminders the tasks already have', (tester) async {
      final service = _FakeTasksService(byDay: {
        dayKey: [
          _task('t1', 'eat_breakfast', 'Desayunar', reminder: '07:30'),
          _task('t2', 'move_stairs', 'Usar las escaleras'),
        ],
      });

      await pumpScreen(tester, service);

      expect(gateway.order, ['cancel', 'schedule']);
      expect(gateway.scheduled.single.body, 'Recordatorio: Desayunar');
      expect((gateway.scheduled.single.hour, gateway.scheduled.single.minute), (7, 30));
    });

    testWidgets('looking at a past day does not touch the schedule', (tester) async {
      final service = _FakeTasksService(byDay: {
        dayKey: [_task('t1', 'eat_breakfast', 'Desayunar', reminder: '07:30')],
        '2026-10-14': [_task('t1', 'eat_breakfast', 'Desayunar')],
      });
      await pumpScreen(tester, service);
      final before = List.of(gateway.order);

      await tester.tap(find.byKey(const ValueKey('day-2026-10-14')));
      await tester.pumpAndSettle();

      expect(gateway.order, before);
    });

    testWidgets('picking a time asks for permission and schedules it', (tester) async {
      final service = _FakeTasksService(byDay: {
        dayKey: [_task('t1', 'eat_breakfast', 'Desayunar')],
      });
      await pumpScreen(tester, service);

      await tester.tap(inCard('t1', find.byTooltip('Recordatorio')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(gateway.permissionRequests, 1);
      expect(gateway.scheduled.last.body, 'Recordatorio: Desayunar');
      expect((gateway.scheduled.last.hour, gateway.scheduled.last.minute), (8, 0));
    });

    testWidgets('without permission the reminder is saved and the user is told', (tester) async {
      gateway.permissionGranted = false;
      final service = _FakeTasksService(byDay: {
        dayKey: [_task('t1', 'eat_breakfast', 'Desayunar')],
      });
      await pumpScreen(tester, service);

      await tester.tap(inCard('t1', find.byTooltip('Recordatorio')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(service.reminders, ['08:00']);
      expect(find.textContaining('notificaciones'), findsOneWidget);
    });

    testWidgets('removing a reminder clears the schedule', (tester) async {
      final service = _FakeTasksService(byDay: {
        dayKey: [_task('t1', 'eat_breakfast', 'Desayunar', reminder: '07:30')],
      });
      await pumpScreen(tester, service);
      gateway.scheduled.clear();
      gateway.order.clear();

      await tester.tap(inCard('t1', find.byTooltip('Quitar recordatorio')));
      await tester.pumpAndSettle();

      expect(gateway.order, ['cancel']);
      expect(gateway.scheduled, isEmpty);
    });

    testWidgets('signing out clears every reminder', (tester) async {
      final service = _FakeTasksService(byDay: {
        dayKey: [_task('t1', 'eat_breakfast', 'Desayunar', reminder: '07:30')],
      });
      await pumpScreen(tester, service);
      gateway.cancelAllCalls = 0;

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      expect(gateway.cancelAllCalls, 1);
      expect(find.text('Login'), findsOneWidget);
    });
  });

  testWidgets('starts a new day when the app is resumed after midnight', (tester) async {
    now = DateTime(2026, 10, 15, 23, 50);
    final service = _FakeTasksService(byDay: {
      dayKey: [_task('t1', 'hydrate_water', 'Tomar agua', target: 8, unit: 'vasos', progress: 8)],
      '2026-10-16': [_task('t1', 'hydrate_water', 'Tomar agua', target: 8, unit: 'vasos')],
    });
    await pumpScreen(tester, service);
    expect(find.text('8/8 vasos'), findsOneWidget);

    now = DateTime(2026, 10, 16, 0, 5);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(service.fetchedDays.last, '2026-10-16');
    expect(find.text('0/8 vasos'), findsOneWidget);
  });

  testWidgets('does not reload on resume when the date is the same', (tester) async {
    final service = _FakeTasksService(byDay: {
      dayKey: [_task('t1', 'hydrate_water', 'Tomar agua', target: 8, unit: 'vasos')],
    });
    await pumpScreen(tester, service);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(service.fetchedDays, [dayKey]);
  });
}
