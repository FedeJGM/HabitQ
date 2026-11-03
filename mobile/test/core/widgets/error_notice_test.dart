import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mobile/core/widgets/error_notice.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows the message and a Reintentar button that calls back', (tester) async {
    var retries = 0;
    await tester.pumpWidget(host(ErrorNotice(message: 'Algo salió mal', onRetry: () => retries++)));
    await tester.pumpAndSettle();

    expect(find.text('Algo salió mal'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    expect(retries, 1);
  });

  testWidgets('a connection problem suggests checking the network', (tester) async {
    await tester.pumpWidget(
      host(ErrorNotice(message: 'No se pudo conectar', isConnection: true, onRetry: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Symbols.cloud_off_rounded), findsOneWidget);
    expect(find.textContaining('Revisa tu conexión'), findsOneWidget);
  });

  testWidgets('another kind of error does not blame the connection', (tester) async {
    await tester.pumpWidget(host(ErrorNotice(message: 'Dato inválido', onRetry: () {})));
    await tester.pumpAndSettle();

    expect(find.byIcon(Symbols.cloud_off_rounded), findsNothing);
    expect(find.byIcon(Symbols.error_rounded), findsOneWidget);
    expect(find.textContaining('Revisa tu conexión'), findsNothing);
  });

  testWidgets('is announced to screen readers as a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(ErrorNotice(message: 'Algo salió mal', onRetry: () {})));
    await tester.pumpAndSettle();

    final node = tester.getSemantics(find.byKey(const ValueKey('error-notice')));
    expect(node.flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });

  testWidgets('the retry button is at least 48 dp tall', (tester) async {
    await tester.pumpWidget(host(ErrorNotice(message: 'x', onRetry: () {})));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(48));
  });

  testWidgets('without onRetry there is no button', (tester) async {
    await tester.pumpWidget(host(const ErrorNotice(message: 'Solo aviso')));
    await tester.pumpAndSettle();

    expect(find.text('Reintentar'), findsNothing);
  });
}
