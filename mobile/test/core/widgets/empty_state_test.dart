import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mobile/core/widgets/empty_state.dart';

void main() {
  Widget host(Widget child, {double width = 400}) => MaterialApp(
        home: Scaffold(body: Center(child: SizedBox(width: width, child: child))),
      );

  testWidgets('shows the title, the message and its icon', (tester) async {
    await tester.pumpWidget(
      host(const EmptyState(icon: Symbols.checklist_rounded, title: 'Aún no hay nada', message: 'Empieza ahora.')),
    );

    expect(find.text('Aún no hay nada'), findsOneWidget);
    expect(find.text('Empieza ahora.'), findsOneWidget);
    expect(find.byIcon(Symbols.checklist_rounded), findsOneWidget);
  });

  testWidgets('an action button appears only when both label and callback are given', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(EmptyState(
        icon: Symbols.checklist_rounded,
        title: 'Vacío',
        actionLabel: 'Ir a Actividad',
        onAction: () => taps++,
      )),
    );

    await tester.tap(find.text('Ir a Actividad'));
    expect(taps, 1);

    await tester.pumpWidget(host(const EmptyState(icon: Symbols.checklist_rounded, title: 'Vacío')));
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('the action is at least 48 dp tall', (tester) async {
    await tester.pumpWidget(
      host(EmptyState(icon: Symbols.checklist_rounded, title: 'Vacío', actionLabel: 'Ir', onAction: () {})),
    );

    expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(48));
  });

  testWidgets('the decorative illustration is hidden from screen readers', (tester) async {
    await tester.pumpWidget(host(const EmptyState(icon: Symbols.checklist_rounded, title: 'Vacío')));

    expect(
      find.descendant(of: find.byKey(const ValueKey('empty-state-art')), matching: find.byType(ExcludeSemantics)),
      findsWidgets,
    );
  });

  testWidgets('is static: nothing keeps animating', (tester) async {
    await tester.pumpWidget(host(const EmptyState(icon: Symbols.checklist_rounded, title: 'Vacío')));

    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('fits a narrow screen with large text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(320, 640), textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: EmptyState(
                icon: Symbols.checklist_rounded,
                title: 'Aún no tienes tareas',
                message: 'Toca el lápiz para elegir las de tu objetivo.',
                actionLabel: 'Elegir tareas',
                onAction: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
