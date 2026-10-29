import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/widgets/skeleton.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('SkeletonBox reserves its exact space', (tester) async {
    await tester.pumpWidget(host(const Center(child: SkeletonBox(width: 120, height: 16))));

    expect(tester.getSize(find.byType(SkeletonBox)), const Size(120, 16));
  });

  testWidgets('SkeletonCard stands in for a card and is hidden from screen readers', (tester) async {
    await tester.pumpWidget(host(const SkeletonCard()));

    expect(find.byKey(const ValueKey('skeleton-card')), findsOneWidget);
    expect(find.byType(ExcludeSemantics), findsWidgets);
  });

  testWidgets('does not keep animating: the screen can settle', (tester) async {
    await tester.pumpWidget(host(const SkeletonCard()));

    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('SkeletonList shows the requested number of cards', (tester) async {
    await tester.pumpWidget(host(const SingleChildScrollView(child: SkeletonList(count: 3))));

    expect(find.byKey(const ValueKey('skeleton-card')), findsNWidgets(3));
  });
}
