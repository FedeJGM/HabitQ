import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_scroll_behavior.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('scrolls with a bounce on every platform, even short lists', (tester) async {
    late ScrollPhysics physics;
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const AppScrollBehavior(),
        home: Builder(builder: (context) {
          physics = ScrollConfiguration.of(context).getScrollPhysics(context);
          return const SizedBox();
        }),
      ),
    );

    expect(physics, isA<BouncingScrollPhysics>());
    expect(physics.parent, isA<AlwaysScrollableScrollPhysics>());
  });

  testWidgets('the app installs the shared scroll behavior', (tester) async {
    await tester.pumpWidget(const HabitQApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.scrollBehavior, isA<AppScrollBehavior>());
  });
}
