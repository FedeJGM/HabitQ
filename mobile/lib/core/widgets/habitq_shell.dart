import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../features/auth/auth_service.dart';
import 'habitq_bottom_nav.dart';
import 'habitq_header.dart';

/// Scaffold shared by the main tabs: header on top, bottom navigation below.
/// Switching tabs replaces the current route so tabs do not stack.
class HabitQShell extends StatelessWidget {
  const HabitQShell({
    super.key,
    required this.currentTab,
    required this.onLogout,
    required this.child,
  });

  final HabitQTab currentTab;
  final VoidCallback onLogout;
  final Widget child;

  static String routeFor(HabitQTab tab) {
    switch (tab) {
      case HabitQTab.home:
        return AppRoutes.home;
      case HabitQTab.activity:
        return AppRoutes.activity;
      case HabitQTab.chat:
        return AppRoutes.chat;
      case HabitQTab.profile:
        return AppRoutes.profile;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HabitQHeader(onLogout: onLogout),
      body: SafeArea(top: false, child: child),
      bottomNavigationBar: HabitQBottomNav(
        current: currentTab,
        onSelected: (tab) {
          if (tab == currentTab) return;
          Navigator.of(context).pushReplacementNamed(routeFor(tab));
        },
      ),
    );
  }
}

/// Default logout used by tabs: clears the session and returns to login.
Future<void> signOutAndGoToLogin(BuildContext context, [AuthService? authService]) async {
  await (authService ?? AuthService()).signOut();
  if (!context.mounted) return;
  Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
}
