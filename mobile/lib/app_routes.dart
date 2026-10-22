import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/activity/activity_screen.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/chat/conversation_history_screen.dart';
import 'features/consent/consent_screen.dart';
import 'features/habits/habits_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_habits_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/stats/stats_screen.dart';

/// Central route table. Add new named routes here as each feature screen
/// lands, instead of scattering Navigator.push calls with inline builders.
class AppRoutes {
  static const login = '/login';
  static const consent = '/consent';
  static const onboarding = '/onboarding';
  static const onboardingHabits = '/onboarding/habits';
  static const home = '/home';
  static const activity = '/activity';
  static const stats = '/stats';
  static const habits = '/habits';
  static const profile = '/profile';
  static const chat = '/chat';
  static const chatHistory = '/chat/history';

  static Map<String, WidgetBuilder> get table => {
        login: (_) => const LoginScreen(),
        // Consent keeps its pre-redesign look: scope it to the legacy theme.
        consent: (_) => Theme(data: AppTheme.legacy, child: const ConsentScreen()),
        onboarding: (_) => const OnboardingScreen(),
        onboardingHabits: (_) => const OnboardingHabitsScreen(),
        home: (_) => const HomeScreen(),
        activity: (_) => const ActivityScreen(),
        stats: (_) => const StatsScreen(),
        habits: (_) => const HabitsScreen(),
        profile: (_) => ProfileScreen(authService: AuthService()),
        chat: (_) => const ChatScreen(),
        chatHistory: (_) => const ConversationHistoryScreen(),
      };
}
