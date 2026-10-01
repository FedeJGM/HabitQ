import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/features/habits/habits_screen.dart';
import 'package:mobile/features/habits/habits_service.dart';

class _FakeHabitsService implements HabitsService {
  _FakeHabitsService({this.records = const [], this.fetchError});

  List<HabitRecord> records;
  ApiException? fetchError;
  ApiException? updateError;
  String? lastUpdatedId;
  String? lastUpdatedValue;

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
  }) async {
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
  Widget buildApp(HabitsService habitsService) {
    return MaterialApp(home: HabitsScreen(habitsService: habitsService));
  }

  const sleepHoursRecord = HabitRecord(id: 'h1', domain: 'sleep', key: 'hours', value: '7_8');
  const hydrationRecord =
      HabitRecord(id: 'h2', domain: 'hydration', key: 'daily_intake', value: 'low');

  testWidgets('shows the current value for each answered question', (tester) async {
    final fakeService = _FakeHabitsService(records: const [sleepHoursRecord, hydrationRecord]);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    final selectedChip = tester.widget<ChoiceChip>(find.byKey(const ValueKey('hours:7_8')));
    expect(selectedChip.selected, isTrue);
  });

  testWidgets('shows an error message when the initial fetch fails', (tester) async {
    final fakeService = _FakeHabitsService(fetchError: ApiException('No se pudieron cargar tus hábitos.'));
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    expect(find.text('No se pudieron cargar tus hábitos.'), findsOneWidget);
  });

  testWidgets('marks a question without an existing record as unanswered', (tester) async {
    final fakeService = _FakeHabitsService(records: const [sleepHoursRecord]);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('¿Cómo describirías tu consumo diario de agua?'));
    await tester.pumpAndSettle();

    // 8 of the 9 plan questions have no seeded record here (only "hours" does).
    expect(find.text('Sin responder'), findsNWidgets(8));
    expect(find.byKey(const ValueKey('daily_intake:low')), findsNothing);
  });

  testWidgets('tapping a different option updates the habit and reflects the new value',
      (tester) async {
    final fakeService = _FakeHabitsService(records: const [sleepHoursRecord]);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('hours:5_6')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hours:5_6')));
    await tester.pumpAndSettle();

    expect(fakeService.lastUpdatedId, 'h1');
    expect(fakeService.lastUpdatedValue, '5_6');
    final updatedChip = tester.widget<ChoiceChip>(find.byKey(const ValueKey('hours:5_6')));
    expect(updatedChip.selected, isTrue);
    final previousChip = tester.widget<ChoiceChip>(find.byKey(const ValueKey('hours:7_8')));
    expect(previousChip.selected, isFalse);
  });

  testWidgets('shows an error and keeps the old value when updating fails', (tester) async {
    final fakeService = _FakeHabitsService(records: const [sleepHoursRecord])
      ..updateError = ApiException('No se pudo guardar el cambio.');
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('hours:5_6')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hours:5_6')));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo guardar el cambio.'), findsOneWidget);
    final previousChip = tester.widget<ChoiceChip>(find.byKey(const ValueKey('hours:7_8')));
    expect(previousChip.selected, isTrue);
  });
}
