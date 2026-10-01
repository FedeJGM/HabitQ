import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/consent/consent_screen.dart';
import 'package:mobile/features/consent/consent_storage.dart';

class _FakeConsentStorage implements ConsentStorage {
  bool accepted = false;

  @override
  Future<bool> hasAccepted() async => accepted;

  @override
  Future<void> accept() async {
    accepted = true;
  }
}

void main() {
  Widget buildApp(ConsentStorage consentStorage) {
    return MaterialApp(
      routes: {
        'next': (_) => const Scaffold(body: Text('Next screen')),
      },
      home: ConsentScreen(nextRoute: 'next', consentStorage: consentStorage),
    );
  }

  testWidgets('shows the consent disclaimer text', (tester) async {
    final fakeStorage = _FakeConsentStorage();
    await tester.pumpWidget(buildApp(fakeStorage));

    expect(find.textContaining('no diagnostica'), findsOneWidget);
    expect(find.text('Acepto y continúo'), findsOneWidget);
  });

  testWidgets('accepting records consent and navigates to nextRoute', (tester) async {
    final fakeStorage = _FakeConsentStorage();
    await tester.pumpWidget(buildApp(fakeStorage));

    await tester.ensureVisible(find.text('Acepto y continúo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acepto y continúo'));
    await tester.pumpAndSettle();

    expect(fakeStorage.accepted, isTrue);
    expect(find.text('Next screen'), findsOneWidget);
  });
}
