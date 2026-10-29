import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_service.dart';

void main() {
  runApp(const HabitQApp());
}

class HabitQApp extends StatefulWidget {
  const HabitQApp({super.key, AuthService? authService}) : _authService = authService;

  final AuthService? _authService;

  @override
  State<HabitQApp> createState() => _HabitQAppState();
}

class _HabitQAppState extends State<HabitQApp> with WidgetsBindingObserver {
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = widget._authService ?? AuthService();
    WidgetsBinding.instance.addObserver(this);
    // Cold start: usually a no-op (a fresh login just issued a fresh token),
    // but covers the case where the process wasn't fully killed.
    _authService.refreshTokenIfNeeded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The real gap: the app was backgrounded with a session already active,
    // the JWT expired while backgrounded, and resuming needs a fresh one
    // before the next API call fails. Fire-and-forget — this must not block
    // resuming the UI.
    if (state == AppLifecycleState.resumed) {
      _authService.refreshTokenIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HabitQ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: const AppScrollBehavior(),
      initialRoute: AppRoutes.login,
      routes: AppRoutes.table,
    );
  }
}
