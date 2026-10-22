import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app_routes.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/features/auth/auth_service.dart';
import 'package:mobile/features/habits/habits_service.dart';
import 'package:mobile/features/stats/stats_screen.dart';
import 'package:mobile/features/stats/stats_service.dart';

class _FakeStatsService extends StatsService {
  _FakeStatsService({TaskStats? stats, this.fetchError}) : stats = stats ?? _stats();

  TaskStats stats;
  ApiException? fetchError;
  final List<DateTime> requestedDays = [];

  @override
  Future<TaskStats> fetchStats(DateTime day) async {
    requestedDays.add(day);
    if (fetchError != null) throw fetchError!;
    return stats;
  }
}

class _FakeHabitsService implements HabitsService {
  _FakeHabitsService({this.records = const [], this.fetchError});

  List<HabitRecord> records;
  ApiException? fetchError;

  @override
  Future<List<HabitRecord>> fetchHabits() async {
    if (fetchError != null) throw fetchError!;
    return records;
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

  @override
  Future<void> submitAnswers(List<HabitAnswer> answers) {
    throw UnimplementedError();
  }
}

class _FakeAuthService extends AuthService {
  @override
  Future<void> signOut() async {}
}

// Window ending Thursday 2026-10-15.
TaskStats _stats({
  List<int> completed = const [0, 1, 3, 1, 0, 3, 1],
  int active = 3,
  List<CounterStat>? counters,
  DateTime? bestDay,
}) {
  final first = DateTime(2026, 10, 9);
  return TaskStats(
    days: [
      for (var i = 0; i < 7; i++)
        StatsDay(day: first.add(Duration(days: i)), active: active, completed: completed[i]),
    ],
    counters: counters ??
        const [
          CounterStat(
            taskKey: 'hydrate_water',
            label: 'Tomar agua',
            unit: 'vasos',
            target: 8,
            days: 4,
            average: 2.5,
          ),
          CounterStat(
            taskKey: 'eat_fruit_veg',
            label: 'Comer frutas o verduras',
            unit: 'porciones',
            target: 5,
            days: 7,
            average: 3,
          ),
        ],
    bestDay: bestDay ?? DateTime(2026, 10, 14),
  );
}

TaskStats _emptyStats() => TaskStats(
      days: [
        for (var i = 0; i < 7; i++)
          StatsDay(day: DateTime(2026, 10, 9).add(Duration(days: i)), active: 0, completed: 0),
      ],
      counters: const [],
      bestDay: null,
    );

HabitRecord _record(String id, String domain, String key, String value) =>
    HabitRecord(id: id, domain: domain, key: key, value: value);

void main() {
  final now = DateTime(2026, 10, 15, 10);

  Future<void> pumpScreen(
    WidgetTester tester, {
    required _FakeStatsService stats,
    _FakeHabitsService? habits,
    Size size = const Size(800, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.login: (_) => const Scaffold(body: Text('Login')),
          AppRoutes.activity: (_) => const Scaffold(body: Text('Activity page')),
          AppRoutes.habits: (_) => const Scaffold(body: Text('Habits page')),
        },
        home: StatsScreen(
          statsService: stats,
          habitsService: habits ?? _FakeHabitsService(),
          authService: _FakeAuthService(),
          now: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows a spinner while the statistics load', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: StatsScreen(
          statsService: _FakeStatsService(),
          habitsService: _FakeHabitsService(),
          authService: _FakeAuthService(),
          now: () => now,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    await tester.pumpAndSettle();
  });

  testWidgets('asks for the window ending on the local day of the user', (tester) async {
    final stats = _FakeStatsService();
    await pumpScreen(tester, stats: stats);

    expect(stats.requestedDays, [DateTime(2026, 10, 15)]);
  });

  testWidgets('shows the title, the period and the daily completion chart', (tester) async {
    await pumpScreen(tester, stats: _FakeStatsService());

    expect(find.text('Tus estadísticas'), findsOneWidget);
    expect(find.text('Últimos 7 días'), findsOneWidget);
    expect(find.text('Cumplimiento por día'), findsOneWidget);
    expect(find.byKey(const ValueKey('stats-chart')), findsOneWidget);
    expect(find.text('DOM'), findsOneWidget);
  });

  testWidgets('labels the vertical axis every 25 percent', (tester) async {
    await pumpScreen(tester, stats: _FakeStatsService());

    final chart = find.byKey(const ValueKey('stats-chart'));
    for (final label in ['0 %', '25 %', '50 %', '75 %', '100 %']) {
      expect(find.descendant(of: chart, matching: find.text(label)), findsOneWidget, reason: label);
    }
  });

  testWidgets('keeps each axis label on a single line, the percent sign included', (tester) async {
    await pumpScreen(tester, stats: _FakeStatsService());

    final chart = find.byKey(const ValueKey('stats-chart'));
    double heightOf(String label) =>
        tester.getSize(find.descendant(of: chart, matching: find.text(label))).height;

    for (final label in ['25 %', '50 %', '75 %', '100 %']) {
      expect(heightOf(label), heightOf('0 %'), reason: label);
    }
  });

  testWidgets('summarizes today in tasks', (tester) async {
    await pumpScreen(tester, stats: _FakeStatsService());

    expect(find.text('Hoy: 1 de 3 tareas'), findsOneWidget);
  });

  testWidgets('shows the best day with its weekday name', (tester) async {
    await pumpScreen(tester, stats: _FakeStatsService());

    expect(find.text('Mejor día: miércoles 14'), findsOneWidget);
  });

  testWidgets('hides the best day when there is none', (tester) async {
    final noBestDay = TaskStats(
      days: _stats(completed: const [0, 0, 0, 0, 0, 0, 0]).days,
      counters: const [],
      bestDay: null,
    );
    final stats = _FakeStatsService(stats: noBestDay);
    await pumpScreen(tester, stats: stats);

    expect(find.textContaining('Mejor día'), findsNothing);
  });

  testWidgets('lists the average of each counter against its target', (tester) async {
    await pumpScreen(tester, stats: _FakeStatsService());

    expect(find.text('Promedio de tus contadores'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const ValueKey('counter-hydrate_water')), matching: find.text('Tomar agua')),
      findsOneWidget,
    );
    expect(find.text('2,5 de 8 vasos'), findsOneWidget);
    expect(find.text('3 de 5 porciones'), findsOneWidget);
  });

  testWidgets('hides the counters card when there are no counters', (tester) async {
    await pumpScreen(tester, stats: _FakeStatsService(stats: _stats(counters: const [])));

    expect(find.text('Promedio de tus contadores'), findsNothing);
  });

  testWidgets('shows an empty state with a button to Actividad when no day had tasks', (tester) async {
    await pumpScreen(tester, stats: _FakeStatsService(stats: _emptyStats()));

    expect(find.text('Aún no hay datos para mostrar'), findsOneWidget);
    expect(find.byKey(const ValueKey('stats-chart')), findsNothing);

    await tester.tap(find.text('Ir a Actividad'));
    await tester.pumpAndSettle();

    expect(find.text('Activity page'), findsOneWidget);
  });

  testWidgets('shows the backend error message and no chart when the statistics fail', (tester) async {
    final stats = _FakeStatsService(fetchError: ApiException('Sin conexión con el servidor'));
    await pumpScreen(tester, stats: stats);

    expect(find.text('Sin conexión con el servidor'), findsOneWidget);
    expect(find.byKey(const ValueKey('stats-chart')), findsNothing);
  });

  group('habits summary', () {
    testWidgets('shows each answer with its label, grouped by domain', (tester) async {
      final habits = _FakeHabitsService(records: [
        _record('1', 'sleep', 'hours', '7_8'),
        _record('2', 'sleep', 'screen_before_bed', 'sometimes'),
        _record('3', 'hydration', 'daily_intake', 'adequate'),
      ]);
      await pumpScreen(tester, stats: _FakeStatsService(), habits: habits);

      expect(find.text('Resumen de tus hábitos'), findsOneWidget);
      expect(find.text('Sueño'), findsOneWidget);
      expect(find.text('Hidratación'), findsOneWidget);
      expect(find.text('¿Cuántas horas duermes normalmente?'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('habit-sleep-hours')), matching: find.text('7–8')), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('habit-sleep-screen_before_bed')), matching: find.text('A veces')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const ValueKey('habit-hydration-daily_intake')), matching: find.text('Adecuado')),
        findsOneWidget,
      );
    });

    testWidgets('marks unanswered questions', (tester) async {
      final habits = _FakeHabitsService(records: [_record('1', 'sleep', 'hours', '7_8')]);
      await pumpScreen(tester, stats: _FakeStatsService(), habits: habits);

      expect(
        find.descendant(of: find.byKey(const ValueKey('habit-stress-frequency')), matching: find.text('Sin responder')),
        findsOneWidget,
      );
    });

    testWidgets('matches by domain and key, not by key alone', (tester) async {
      // "rarely" is an option of several questions: only the recorded one is answered.
      final habits = _FakeHabitsService(records: [_record('1', 'stress', 'frequency', 'rarely')]);
      await pumpScreen(tester, stats: _FakeStatsService(), habits: habits);

      expect(
        find.descendant(of: find.byKey(const ValueKey('habit-stress-frequency')), matching: find.text('Rara vez')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const ValueKey('habit-nutrition-fast_food')), matching: find.text('Sin responder')),
        findsOneWidget,
      );
    });

    testWidgets('uses the latest record when a question was answered more than once', (tester) async {
      final habits = _FakeHabitsService(records: [
        _record('1', 'sleep', 'hours', 'less_5'),
        _record('2', 'sleep', 'hours', 'more_8'),
      ]);
      await pumpScreen(tester, stats: _FakeStatsService(), habits: habits);

      expect(
        find.descendant(of: find.byKey(const ValueKey('habit-sleep-hours')), matching: find.text('Más de 8')),
        findsOneWidget,
      );
    });

    testWidgets('shows a notice instead of the list when there are no answers', (tester) async {
      await pumpScreen(tester, stats: _FakeStatsService(), habits: _FakeHabitsService());

      expect(find.text('Aún no respondes el cuestionario de hábitos.'), findsOneWidget);
      expect(find.byKey(const ValueKey('habit-sleep-hours')), findsNothing);
    });

    testWidgets('is shown even when there are no tasks', (tester) async {
      final habits = _FakeHabitsService(records: [_record('1', 'sleep', 'hours', '7_8')]);
      await pumpScreen(tester, stats: _FakeStatsService(stats: _emptyStats()), habits: habits);

      expect(find.text('Aún no hay datos para mostrar'), findsOneWidget);
      expect(find.text('Resumen de tus hábitos'), findsOneWidget);
    });

    testWidgets('a failure loading habits does not hide the statistics', (tester) async {
      final habits = _FakeHabitsService(fetchError: ApiException('No se pudo leer tus hábitos'));
      await pumpScreen(tester, stats: _FakeStatsService(), habits: habits);

      expect(find.byKey(const ValueKey('stats-chart')), findsOneWidget);
      expect(find.text('No se pudo leer tus hábitos'), findsOneWidget);
    });

    testWidgets('Editar hábitos opens Mis hábitos', (tester) async {
      final habits = _FakeHabitsService(records: [_record('1', 'sleep', 'hours', '7_8')]);
      await pumpScreen(tester, stats: _FakeStatsService(), habits: habits);

      await tester.ensureVisible(find.text('Editar hábitos'));
      await tester.tap(find.text('Editar hábitos'));
      await tester.pumpAndSettle();

      expect(find.text('Habits page'), findsOneWidget);
    });
  });

  testWidgets('fits a 360 dp wide phone without overflow', (tester) async {
    final habits = _FakeHabitsService(records: [_record('1', 'sleep', 'hours', '7_8')]);
    await pumpScreen(tester, stats: _FakeStatsService(), habits: habits, size: const Size(360, 800));

    expect(tester.takeException(), isNull);
  });
}
