import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/widgets/habitq_bottom_nav.dart';

void main() {
  Widget buildNav(HabitQTab current, ValueChanged<HabitQTab> onSelected) {
    return MaterialApp(
      home: Scaffold(
        bottomNavigationBar: HabitQBottomNav(current: current, onSelected: onSelected),
      ),
    );
  }

  testWidgets('shows the Inicio, Actividad, Estadísticas, Chat and Perfil destinations', (tester) async {
    await tester.pumpWidget(buildNav(HabitQTab.home, (_) {}));

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Actividad'), findsOneWidget);
    expect(find.text('Estadísticas'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });

  testWidgets('keeps the order Inicio, Actividad, Estadísticas, Chat, Perfil', (tester) async {
    expect(HabitQTab.values, [
      HabitQTab.home,
      HabitQTab.activity,
      HabitQTab.stats,
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

  testWidgets('marks Estadísticas as selected when it is the current tab', (tester) async {
    await tester.pumpWidget(buildNav(HabitQTab.stats, (_) {}));

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 2);
  });

  testWidgets('reports the Estadísticas tab when tapped', (tester) async {
    HabitQTab? tapped;
    await tester.pumpWidget(buildNav(HabitQTab.home, (tab) => tapped = tab));

    await tester.tap(find.text('Estadísticas'));
    await tester.pump();

    expect(tapped, HabitQTab.stats);
  });

  testWidgets('renders the five tabs on a 360 dp wide phone without errors', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildNav(HabitQTab.stats, (_) {}));

    expect(tester.takeException(), isNull);
  });

  test('the label size lets Estadísticas fit its slot on a 360 dp phone', () {
    // Measured with Lexend Medium: "Estadísticas" is 76 dp at 12 sp (more than
    // the 72 dp each of five tabs gets, so it would wrap mid-word) and 67 dp
    // at 11 sp. Tests render with a placeholder font, so this guards the size.
    final style = AppTheme.light.navigationBarTheme.labelTextStyle!.resolve(<WidgetState>{});

    expect(style!.fontSize, lessThanOrEqualTo(11));
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
