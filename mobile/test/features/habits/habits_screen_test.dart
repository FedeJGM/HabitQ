import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/core/widgets/error_notice.dart';
import 'package:mobile/core/widgets/skeleton.dart';
import 'package:mobile/features/habits/habit_wizard.dart';
import 'package:mobile/features/habits/habits_screen.dart';
import 'package:mobile/features/habits/habits_service.dart';

class _FakeHabitsService implements HabitsService {
  _FakeHabitsService({this.records = const [], this.fetchError});

  List<HabitRecord> records;
  ApiException? fetchError;
  ApiException? updateError;
  int fetches = 0;
  int updates = 0;
  String? lastUpdatedId;
  String? lastUpdatedValue;

  @override
  Future<List<HabitRecord>> fetchHabits() async {
    fetches++;
    if (fetchError != null) throw fetchError!;
    return records;
  }

  @override
  Future<HabitRecord> updateHabit({
    required String id,
    required String domain,
    required String key,
    required String value,
  }) async {
    updates++;
    lastUpdatedId = id;
    lastUpdatedValue = value;
    if (updateError != null) throw updateError!;
    final updated = HabitRecord(id: id, domain: domain, key: key, value: value);
    records = [
      for (final record in records) if (record.id == id) updated else record,
    ];
    return updated;
  }

  @override
  Future<void> submitAnswers(List<HabitAnswer> answers) {
    throw UnimplementedError();
  }
}

void main() {
  Widget buildApp(HabitsService habitsService, {int initialStep = 0}) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HabitsScreen(habitsService: habitsService, initialStep: initialStep),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester, HabitsService service, {int initialStep = 0}) async {
    await tester.pumpWidget(buildApp(service, initialStep: initialStep));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  const sleepHoursRecord = HabitRecord(id: 'h1', domain: 'sleep', key: 'hours', value: '7_8');
  const sleepScreenRecord =
      HabitRecord(id: 'h2', domain: 'sleep', key: 'screen_before_bed', value: 'never');

  HabitOptionTile tile(WidgetTester tester, String key, String value) =>
      tester.widget<HabitOptionTile>(find.byKey(ValueKey('$key:$value')));

  testWidgets('shows the saved answer of the first question already marked', (tester) async {
    await open(tester, _FakeHabitsService(records: const [sleepHoursRecord]));

    expect(find.text('Mis hábitos'), findsOneWidget);
    expect(find.text('Pregunta 1 de 9'), findsOneWidget);
    expect(tile(tester, 'hours', '7_8').selected, isTrue);
    expect(tile(tester, 'hours', 'less_5').selected, isFalse);
  });

  testWidgets('a failed first load shows an error notice that retries', (tester) async {
    final service = _FakeHabitsService(fetchError: ApiException('No se pudieron cargar tus hábitos.'));
    await open(tester, service);

    expect(find.byType(ErrorNotice), findsOneWidget);
    expect(find.text('No se pudieron cargar tus hábitos.'), findsOneWidget);

    service
      ..fetchError = null
      ..records = const [sleepHoursRecord];
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(service.fetches, 2);
    expect(find.byType(ErrorNotice), findsNothing);
    expect(tile(tester, 'hours', '7_8').selected, isTrue);
  });

  testWidgets('loading uses skeleton cards instead of a spinner', (tester) async {
    final service = _FakeHabitsService(records: const [sleepHoursRecord]);
    await tester.pumpWidget(MaterialApp(home: HabitsScreen(habitsService: service)));

    expect(find.byType(SkeletonCard), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('a question without a saved record is shown as unanswered and can be skipped', (tester) async {
    await open(tester, _FakeHabitsService(records: const [sleepHoursRecord]));

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('Pregunta 2 de 9'), findsOneWidget);
    expect(find.text('Sin responder'), findsOneWidget);
    expect(find.byKey(const ValueKey('screen_before_bed:never')), findsNothing);
    final next = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Siguiente'));
    expect(next.onPressed, isNotNull);
  });

  testWidgets('tapping a different option updates the habit, marks it and moves on', (tester) async {
    final service = _FakeHabitsService(records: const [sleepHoursRecord, sleepScreenRecord]);
    await open(tester, service);

    await tester.tap(find.byKey(const ValueKey('hours:5_6')));
    await tester.pumpAndSettle();

    expect(service.lastUpdatedId, 'h1');
    expect(service.lastUpdatedValue, '5_6');
    expect(find.text('Pregunta 2 de 9'), findsOneWidget);

    await tester.tap(find.text('Atrás'));
    await tester.pumpAndSettle();
    expect(tile(tester, 'hours', '5_6').selected, isTrue);
    expect(tile(tester, 'hours', '7_8').selected, isFalse);
  });

  testWidgets('picking the answer already saved moves on without saving again', (tester) async {
    final service = _FakeHabitsService(records: const [sleepHoursRecord, sleepScreenRecord]);
    await open(tester, service);

    await tester.tap(find.byKey(const ValueKey('hours:7_8')));
    await tester.pumpAndSettle();

    expect(service.updates, 0);
    expect(find.text('Pregunta 2 de 9'), findsOneWidget);
  });

  testWidgets('shows an error and keeps the old value when updating fails', (tester) async {
    final service = _FakeHabitsService(records: const [sleepHoursRecord])
      ..updateError = ApiException('No se pudo guardar el cambio.');
    await open(tester, service);

    await tester.tap(find.byKey(const ValueKey('hours:5_6')));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo guardar el cambio.'), findsOneWidget);
    expect(find.text('Pregunta 1 de 9'), findsOneWidget);
    expect(tile(tester, 'hours', '7_8').selected, isTrue);
    expect(tile(tester, 'hours', '5_6').selected, isFalse);
  });

  testWidgets('a later successful change clears the previous error', (tester) async {
    final service = _FakeHabitsService(records: const [sleepHoursRecord, sleepScreenRecord])
      ..updateError = ApiException('No se pudo guardar el cambio.');
    await open(tester, service);
    await tester.tap(find.byKey(const ValueKey('hours:5_6')));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo guardar el cambio.'), findsOneWidget);

    service.updateError = null;
    await tester.tap(find.byKey(const ValueKey('hours:5_6')));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo guardar el cambio.'), findsNothing);
  });

  testWidgets('the last step has a Volver button that closes the screen', (tester) async {
    final service = _FakeHabitsService(records: const [sleepHoursRecord]);
    await open(tester, service, initialStep: 8);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('¡Listo!'), findsOneWidget);

    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('Abrir'), findsOneWidget);
    expect(find.text('Mis hábitos'), findsNothing);
  });
}
