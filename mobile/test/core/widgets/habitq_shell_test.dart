import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app_routes.dart';
import 'package:mobile/core/widgets/habitq_bottom_nav.dart';
import 'package:mobile/core/widgets/habitq_shell.dart';

void main() {
  Widget buildApp({VoidCallback? onLogout}) {
    return MaterialApp(
      routes: {
        AppRoutes.home: (_) => const Scaffold(body: Text('Home page')),
        AppRoutes.activity: (_) => const Scaffold(body: Text('Activity page')),
        AppRoutes.stats: (_) => const Scaffold(body: Text('Stats page')),
        AppRoutes.chat: (_) => const Scaffold(body: Text('Chat page')),
        AppRoutes.profile: (_) => const Scaffold(body: Text('Profile page')),
      },
      home: HabitQShell(
        currentTab: HabitQTab.home,
        onLogout: onLogout ?? () {},
        child: const Text('Body content'),
      ),
    );
  }

  testWidgets('renders the header, body and bottom nav', (tester) async {
    await tester.pumpWidget(buildApp());

    expect(find.text('HabitQ'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);
    expect(find.text('Body content'), findsOneWidget);
    expect(find.byType(HabitQBottomNav), findsOneWidget);
  });

  testWidgets('calls onLogout when the header logout icon is tapped', (tester) async {
    var logoutCalls = 0;
    await tester.pumpWidget(buildApp(onLogout: () => logoutCalls++));

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pump();

    expect(logoutCalls, 1);
  });

  testWidgets('navigates to the tapped tab route', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(find.text('Chat page'), findsOneWidget);
  });

  testWidgets('navigates to the Actividad route', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.text('Actividad'));
    await tester.pumpAndSettle();

    expect(find.text('Activity page'), findsOneWidget);
  });

  testWidgets('navigates to the Estadísticas route', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.text('Estadísticas'));
    await tester.pumpAndSettle();

    expect(find.text('Stats page'), findsOneWidget);
  });

  testWidgets('tapping the current tab does not navigate', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();

    expect(find.text('Body content'), findsOneWidget);
  });
}
