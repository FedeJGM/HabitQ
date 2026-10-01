import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app_routes.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/consent/consent_screen.dart';

void main() {
  testWidgets('the consent route keeps the previous look (legacy theme)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(builder: (context) => AppRoutes.table[AppRoutes.consent]!(context)),
      ),
    );
    await tester.pump();

    final theme = Theme.of(tester.element(find.byType(ConsentScreen)));
    expect(theme.textTheme.bodyMedium?.fontFamily, isNot(AppTheme.fontFamily));
    expect(theme.colorScheme.primary, AppColors.legacyPrimary);
  });

  testWidgets('the global theme uses Lexend and the new brand green', (tester) async {
    expect(AppTheme.light.textTheme.bodyMedium?.fontFamily, AppTheme.fontFamily);
    expect(AppTheme.light.colorScheme.primary, AppColors.primary);
  });
}
