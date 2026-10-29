import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/habits/domain_burst.dart';
import 'package:mobile/features/habits/habit_questions.dart';
import 'package:mobile/features/habits/habit_wizard.dart';

void main() {
  late List<String> selected;
  late int finished;
  Map<String, String> answers = {};
  bool accept = true;

  setUp(() {
    selected = [];
    finished = 0;
    answers = {};
    accept = true;
  });

  Widget host({
    Set<String> lockedKeys = const {},
    int initialStep = 0,
    String? errorMessage,
    bool reduceMotion = false,
    double textScale = 1,
    Size size = const Size(400, 800),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => HabitWizard(
              answers: answers,
              lockedKeys: lockedKeys,
              initialStep: initialStep,
              errorMessage: errorMessage,
              finishLabel: 'Finalizar',
              onSelect: (question, value) async {
                selected.add('${question.key}:$value');
                if (!accept) return false;
                setState(() => answers = {...answers, question.key: value});
                return true;
              },
              onFinish: () => finished++,
            ),
          ),
        ),
      ),
    );
  }

  Finder option(String key, String value) => find.byKey(ValueKey('$key:$value'));
  final burst = find.byKey(const ValueKey('domain-burst-paint'));

  HabitOptionTile tile(WidgetTester tester, String key, String value) =>
      tester.widget<HabitOptionTile>(option(key, value));

  testWidgets('shows one question at a time with its progress', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Pregunta 1 de 9'), findsOneWidget);
    expect(find.text('Sueño'), findsOneWidget);
    expect(find.text('¿Cuántas horas duermes normalmente?'), findsOneWidget);
    expect(option('hours', 'less_5'), findsOneWidget);
    expect(find.text('¿Usas pantallas durante la última hora antes de dormir?'), findsNothing);
    expect(option('screen_before_bed', 'never'), findsNothing);
  });

  testWidgets('the progress bar grows with the step', (tester) async {
    await tester.pumpWidget(host(initialStep: 3));
    await tester.pumpAndSettle();

    final bar = tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey('wizard-progress')));
    expect(bar.value, closeTo(4 / 9, 0.001));
  });

  testWidgets('picking an answer saves it, throws the domain animation and moves on', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(option('hours', 'less_5'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(selected, ['hours:less_5']);
    expect(tile(tester, 'hours', 'less_5').selected, isTrue);
    expect(burst, findsOneWidget);
    expect(find.text('Pregunta 1 de 9'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Pregunta 2 de 9'), findsOneWidget);
    expect(find.text('¿Usas pantallas durante la última hora antes de dormir?'), findsOneWidget);
    expect(burst, findsNothing);
  });

  testWidgets('the animation follows the category of the question', (tester) async {
    await tester.pumpWidget(host(initialStep: 3));
    await tester.pumpAndSettle();

    await tester.tap(option('fast_food', 'rarely'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.widget<DomainBurst>(find.byType(DomainBurst)).domain, 'nutrition');
    await tester.pumpAndSettle();
  });

  testWidgets('Atrás returns to the previous question and keeps its answer', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(option('hours', 'less_5'));
    await tester.pumpAndSettle();
    expect(find.text('Pregunta 2 de 9'), findsOneWidget);

    await tester.tap(find.text('Atrás'));
    await tester.pumpAndSettle();

    expect(find.text('Pregunta 1 de 9'), findsOneWidget);
    expect(tile(tester, 'hours', 'less_5').selected, isTrue);
  });

  testWidgets('Atrás is disabled on the first question', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final back = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Atrás'));
    expect(back.onPressed, isNull);
  });

  testWidgets('Siguiente waits for an answer, and works afterwards', (tester) async {
    answers = {'hours': '7_8'};
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    var next = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Siguiente'));
    expect(next.onPressed, isNotNull);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Pregunta 2 de 9'), findsOneWidget);

    next = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Siguiente'));
    expect(next.onPressed, isNull);
  });

  testWidgets('changing an answer already given moves on again', (tester) async {
    answers = {'hours': '7_8'};
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(option('hours', 'less_5'));
    await tester.pumpAndSettle();

    expect(selected, ['hours:less_5']);
    expect(find.text('Pregunta 2 de 9'), findsOneWidget);
  });

  testWidgets('a rejected answer neither animates nor advances', (tester) async {
    accept = false;
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(option('hours', 'less_5'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(burst, findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Pregunta 1 de 9'), findsOneWidget);
    expect(tile(tester, 'hours', 'less_5').selected, isFalse);
  });

  testWidgets('shows the error message under the options', (tester) async {
    await tester.pumpWidget(host(errorMessage: 'No se pudo guardar el cambio.'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo guardar el cambio.'), findsOneWidget);
  });

  testWidgets('a question that cannot be answered here says so and can be skipped', (tester) async {
    await tester.pumpWidget(host(lockedKeys: {'hours'}));
    await tester.pumpAndSettle();

    expect(find.text('Sin responder'), findsOneWidget);
    expect(option('hours', 'less_5'), findsNothing);
    final next = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Siguiente'));
    expect(next.onPressed, isNotNull);
  });

  testWidgets('with reduced motion there is no animation but it still advances', (tester) async {
    await tester.pumpWidget(host(reduceMotion: true));
    await tester.pumpAndSettle();

    await tester.tap(option('hours', 'less_5'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(burst, findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Pregunta 2 de 9'), findsOneWidget);
  });

  testWidgets('the last step celebrates and finishes', (tester) async {
    answers = {for (final s in habitDomainSections) for (final q in s.questions) q.key: q.options.first.value};
    await tester.pumpWidget(host(initialStep: 8));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('¡Listo!'), findsOneWidget);
    expect(find.text('Respondiste las 9 preguntas.'), findsOneWidget);
    await tester.tap(find.text('Finalizar'));
    expect(finished, 1);
  });

  testWidgets('the summary counts only the answered questions', (tester) async {
    answers = {'hours': '7_8', 'frequency': 'rarely'};
    await tester.pumpWidget(host(initialStep: 8));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('Respondiste 2 de 9 preguntas.'), findsOneWidget);
  });

  testWidgets('options are at least 48 dp tall', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(tester.getSize(option('hours', 'less_5')).height, greaterThanOrEqualTo(48));
  });

  testWidgets('an option tells screen readers whether it is selected', (tester) async {
    final handle = tester.ensureSemantics();
    answers = {'hours': '7_8'};
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final selectedNode = tester.getSemantics(option('hours', '7_8'));
    final otherNode = tester.getSemantics(option('hours', 'less_5'));
    expect(selectedNode.flagsCollection.isSelected.toBoolOrNull(), isTrue);
    expect(otherNode.flagsCollection.isSelected.toBoolOrNull(), isFalse);
    handle.dispose();
  });

  testWidgets('fits a 360 x 640 phone with large text without overflowing', (tester) async {
    await tester.pumpWidget(host(size: const Size(360, 640), textScale: 1.4, initialStep: 4));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(option('days_per_week', '5_plus'), findsOneWidget);
  });
}
