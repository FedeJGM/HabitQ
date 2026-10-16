import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/widgets/habitq_bottom_nav.dart';

void main() {
  Widget buildNav(HabitQTab current, ValueChanged<HabitQTab> onSelected) {
    return MaterialApp(
      home: Scaffold(
        bottomNavigationBar: HabitQBottomNav(current: current, onSelected: onSelected),
      ),
    );
  }

  testWidgets('shows the Inicio, Actividad, Chat and Perfil destinations', (tester) async {
    await tester.pumpWidget(buildNav(HabitQTab.home, (_) {}));

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Actividad'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });

  testWidgets('keeps the order Inicio, Actividad, Chat, Perfil', (tester) async {
    expect(HabitQTab.values, [
      HabitQTab.home,
      HabitQTab.activity,
      HabitQTab.chat,
      HabitQTab.profile,
    ]);
  });

  testWidgets('marks Actividad as selected when it is the current tab', (tester) async {
    await tester.pumpWidget(buildNav(HabitQTab.activity, (_) {}));

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 1);
  });

  testWidgets('reports the Actividad tab when tapped', (tester) async {
    HabitQTab? tapped;
    await tester.pumpWidget(buildNav(HabitQTab.home, (tab) => tapped = tab));

    await tester.tap(find.text('Actividad'));
    await tester.pump();

    expect(tapped, HabitQTab.activity);
  });

  testWidgets('marks the current tab as selected', (tester) async {
    await tester.pumpWidget(buildNav(HabitQTab.chat, (_) {}));

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, HabitQTab.chat.index);
  });

  testWidgets('reports the tapped tab', (tester) async {
    HabitQTab? tapped;
    await tester.pumpWidget(buildNav(HabitQTab.home, (tab) => tapped = tab));

    await tester.tap(find.text('Perfil'));
    await tester.pump();

    expect(tapped, HabitQTab.profile);
  });
}
