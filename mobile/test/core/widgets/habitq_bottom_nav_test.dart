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

  testWidgets('shows the Inicio, Chat and Perfil destinations', (tester) async {
    await tester.pumpWidget(buildNav(HabitQTab.home, (_) {}));

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
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
